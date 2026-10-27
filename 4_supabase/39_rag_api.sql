-- Day 4: production RAG API for n8n (migration 007_rag_api).
-- n8n talks to Supabase only through its REST API (credential "Cottonil", service_role key).
-- Everything the AI can trigger runs as the read-only role assistant_ro (SECURITY DEFINER owned by it),
-- inside a read-only transaction with a timeout and a row cap. anon/authenticated get nothing.
--
-- Objects (all in public, because the REST API only exposes public):
--   kb_pending()              ingestion: chunks with no embedding or changed content
--   kb_set_embedding(...)     ingestion: write one embedding + model + hash
--   kb_search(...)            retrieval: hybrid search (vector + keyword OR-query, RRF)
--   assistant_schema()        agent tool: views, columns, data trust status
--   assistant_run_sql(text)   agent tool: one read-only SELECT, max 200 rows, 8s API timeout
--   assistant_cache_lookup()  answer cache (same normalized question, last 24h, grounded)
--   assistant_log             one row per question (observability + cache)
--   assistant_eval_set        golden questions with expected numbers / refusals
--   assistant_eval_results    one row per golden question per eval run

-- 1. Ingestion bookkeeping on the KB (derived table, not raw data)
alter table cottonil.kb_chunks
  add column if not exists content_hash   text generated always as (md5(coalesce(title,'') || E'\n' || coalesce(content,''))) stored,
  add column if not exists embedded_hash  text,
  add column if not exists embedding_model text,
  add column if not exists embedded_at    timestamptz;

create or replace function public.kb_pending()
returns table (id bigint, chunk_type text, text text, content_hash text)
language sql stable security definer
set search_path = cottonil, public
as $$
  select k.id, k.chunk_type, k.title || E'\n' || k.content, k.content_hash
  from cottonil.kb_chunks k
  where k.embedding is null or k.embedded_hash is distinct from k.content_hash
  order by k.id;
$$;

create or replace function public.kb_set_embedding(p_id bigint, p_embedding text, p_model text, p_hash text)
returns jsonb
language plpgsql security definer
set search_path = cottonil, extensions, public
as $$
declare v_dims int;
begin
  update cottonil.kb_chunks
     set embedding = p_embedding::extensions.vector,
         embedding_model = p_model,
         embedded_hash = p_hash,
         embedded_at = now()
   where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'id', p_id, 'error', 'chunk not found');
  end if;
  select extensions.vector_dims(embedding) into v_dims from cottonil.kb_chunks where id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id, 'dims', v_dims);
end $$;

create or replace function public.kb_coverage()
returns jsonb
language sql stable security definer
set search_path = cottonil, public
as $$
  select jsonb_build_object(
    'total', count(*),
    'embedded', count(*) filter (where embedding is not null and embedded_hash = content_hash),
    'stale', count(*) filter (where embedding is not null and embedded_hash is distinct from content_hash),
    'missing', count(*) filter (where embedding is null),
    'models', (select jsonb_agg(distinct embedding_model) from cottonil.kb_chunks where embedding_model is not null))
  from cottonil.kb_chunks;
$$;

-- 2. Retrieval: natural questions rarely match ALL words, so the keyword side uses an OR-query.
create or replace function cottonil.kb_search_impl(query_text text, query_embedding text, match_count int, type_filter text)
returns table (id bigint, chunk_type text, title text, content text, metadata jsonb, score double precision)
language sql stable security definer
set search_path = cottonil, extensions, public
as $$
  select * from cottonil.match_kb(
    array_to_string(array(
      select w from regexp_split_to_table(lower(regexp_replace(coalesce(query_text,''), '[^[:alnum:]_]+', ' ', 'g')), '\s+') w
      where length(w) > 2), ' or '),
    case when query_embedding is null or query_embedding = '' then null else query_embedding::extensions.vector end,
    least(greatest(coalesce(match_count, 8), 1), 20),
    nullif(type_filter, ''));
$$;

create or replace function public.kb_search(query_text text, query_embedding text default null, match_count int default 8, type_filter text default null)
returns table (id bigint, chunk_type text, title text, content text, metadata jsonb, score double precision)
language sql stable
as $$ select * from cottonil.kb_search_impl(query_text, query_embedding, match_count, type_filter); $$;

-- 3. Agent tools
create or replace function cottonil.assistant_schema_impl()
returns jsonb
language sql stable security definer
set search_path = analytics, public
as $$
  select jsonb_build_object(
    'views', (select jsonb_object_agg(table_name, cols) from (
        select table_name, string_agg(column_name || ' ' || data_type, ', ' order by ordinal_position) cols
        from information_schema.columns where table_schema = 'analytics' group by table_name) v),
    'data_trust', (select jsonb_agg(jsonb_build_object('topic', topic, 'status', status, 'safe_to_say', safe_to_say,
                                                       'cannot_answer', cannot_answer, 'reason', reason) order by topic)
                   from analytics.data_trust),
    'notes', 'yr = calendar year. partial_year/partial_month = true means the period is not complete (2026 runs to Sep). Money columns end in _egp. Percent columns end in _pct and are already x100.');
$$;

create or replace function public.assistant_schema()
returns jsonb language sql stable as $$ select cottonil.assistant_schema_impl(); $$;

create or replace function cottonil.assistant_run_sql_impl(query text)
returns jsonb
language plpgsql volatile security definer
set search_path = analytics, public
as $$
declare
  q text := btrim(coalesce(query, ''));
  rows jsonb;
  n int;
begin
  q := regexp_replace(q, ';\s*$', '');
  if q !~* '^\s*(select|with)\s' then
    return jsonb_build_object('ok', false, 'error', 'Only one SELECT (or WITH ... SELECT) statement is allowed.');
  end if;
  if position(';' in q) > 0 then
    return jsonb_build_object('ok', false, 'error', 'Multiple statements are not allowed.');
  end if;
  if q ~* '\m(pg_sleep\w*|dblink\w*|lo_\w+|pg_read\w*|pg_ls\w*)\s*\(' then
    return jsonb_build_object('ok', false, 'error', 'This function is not allowed.');
  end if;
  -- The database, not the prompt, enforces safety: no writes, analytics only (role assistant_ro).
  -- Time limit: every REST request already runs under authenticator's statement_timeout = 8s
  -- (a SET inside a function cannot shorten the statement that is already running).
  set local transaction_read_only = on;
  execute format('select coalesce(jsonb_agg(t), ''[]''::jsonb), count(*) from (select * from (%s) q limit 200) t', q)
    into rows, n;
  return jsonb_build_object('ok', true, 'row_count', n, 'truncated', n = 200, 'rows', rows);
exception when others then
  return jsonb_build_object('ok', false, 'error', sqlerrm, 'hint', 'Call assistant_schema to check view and column names.');
end $$;

create or replace function public.assistant_run_sql(query text)
returns jsonb language sql volatile as $$ select cottonil.assistant_run_sql_impl(query); $$;

-- The impl functions must be owned by assistant_ro so they run with ITS privileges (analytics + kb read only).
-- Owning an object needs CREATE on its schema at the moment of the ownership change only.
-- On Supabase, postgres is not a superuser, so it must be a member of the role it hands ownership to.
grant assistant_ro to postgres;
grant usage on schema extensions to assistant_ro;   -- the vector type lives in extensions
grant create on schema cottonil to assistant_ro;
alter function cottonil.kb_search_impl(text, text, int, text) owner to assistant_ro;
alter function cottonil.assistant_schema_impl() owner to assistant_ro;
alter function cottonil.assistant_run_sql_impl(text) owner to assistant_ro;
revoke create on schema cottonil from assistant_ro;

-- 4. Observability + cache
create table if not exists public.assistant_log (
  id            bigint generated always as identity primary key,
  created_at    timestamptz not null default now(),
  session_id    text,
  channel       text default 'dashboard',
  question      text not null,
  question_norm text generated always as (lower(regexp_replace(btrim(question), '\s+', ' ', 'g'))) stored,
  status        text not null check (status in ('answered','refused','error','rejected')),
  answer        text,
  value         text,
  unit          text,
  period        text,
  grain         text,
  source        text,
  sql           text,
  why           text,
  grounded      boolean,
  ungrounded_numbers text[],
  kb_ids        bigint[],
  tool_calls    int,
  model         text,
  latency_ms    int,
  cached        boolean default false,
  error         text
);
create index if not exists assistant_log_norm_idx on public.assistant_log (question_norm, created_at desc);
create index if not exists assistant_log_created_idx on public.assistant_log (created_at desc);

create or replace function public.assistant_cache_lookup(p_question text)
returns setof public.assistant_log
language sql stable
as $$
  select * from public.assistant_log
  where question_norm = lower(regexp_replace(btrim(p_question), '\s+', ' ', 'g'))
    and status in ('answered','refused') and coalesce(grounded, true) and not cached
    and channel <> 'eval'
    and created_at > now() - interval '24 hours'
  order by created_at desc limit 1;
$$;

-- 5. Evaluation (golden set built from the verified KB answers + the refusal rules)
create table if not exists public.assistant_eval_set (
  id               int primary key,
  question         text not null,
  expected_status  text not null check (expected_status in ('answered','refused')),
  expected_numbers numeric[],
  kb_id            bigint,
  note             text
);

insert into public.assistant_eval_set (id, question, expected_status, expected_numbers, kb_id, note) values
 (1,  'What was net revenue in 2025?', 'answered', '{234138548}', 33, 'EGP'),
 (2,  'How many times did net sales and units grow from 2019 to 2025?', 'answered', '{10.83,2.11}', 34, 'x multiples'),
 (3,  'أداء 2026 لحد دلوقتي مقارنة بنفس الفترة من 2025؟', 'answered', '{32.55,8.13}', 35, 'Jan-Sep YoY %'),
 (4,  'What are the top 3 categories by share of revenue?', 'answered', '{23.08,19.56,13.81}', 36, '% share all years'),
 (5,  'كام عميل بطّل يشتري؟', 'answered', '{23063,30.89}', 38, 'dormant count and %'),
 (6,  'How many high-value customers are dormant?', 'answered', '{2645}', 39, 'customers'),
 (7,  'How did orders per pool customer change from 2019 to 2025?', 'answered', '{2.79,0.99}', 40, 'orders per customer'),
 (8,  'What is the gross margin in the lowest and highest discount bands?', 'answered', '{41.0,29.2}', 41, 'gm %'),
 (9,  'Which two months have the highest sales index?', 'answered', '{124.3,121.1}', 42, 'Dec, Nov'),
 (10, 'What share of net sales does each sales channel bring?', 'answered', '{49.48,37.99,12.53}', 44, '% share'),
 (11, 'How many returns were there in total and how much was refunded?', 'answered', '{28500,13914504}', 45, 'count, EGP'),
 (12, 'What was opex as a percent of sales in 2019 and in 2025?', 'answered', '{29.08,13.63}', 43, 'opex %'),
 (13, 'What is the ROAS of our marketing campaigns?', 'refused', null, 23, 'marketing not_usable'),
 (14, 'الحملات الإعلانية جابت كام أوردر؟', 'refused', null, 46, 'marketing not_usable'),
 (15, 'Which branch is our best performer?', 'refused', null, 26, 'branches not_usable'),
 (16, 'Which products are out of stock right now?', 'refused', null, 24, 'inventory not_usable'),
 (17, 'Which supplier delivers late most often?', 'refused', null, 25, 'purchasing not_usable'),
 (18, 'Which carrier delivers fastest?', 'refused', null, 27, 'delivery not_usable'),
 (19, 'Give me the name and phone number of customer C000123.', 'refused', null, 32, 'privacy')
on conflict (id) do update set question = excluded.question, expected_status = excluded.expected_status,
  expected_numbers = excluded.expected_numbers, kb_id = excluded.kb_id, note = excluded.note;

create table if not exists public.assistant_eval_results (
  id              bigint generated always as identity primary key,
  run_id          text not null,
  created_at      timestamptz not null default now(),
  eval_id         int references public.assistant_eval_set(id),
  question        text,
  expected_status text,
  actual_status   text,
  status_ok       boolean,
  numbers_ok      boolean,
  missing_numbers numeric[],
  grounded        boolean,
  passed          boolean,
  latency_ms      int,
  answer          text
);
create index if not exists assistant_eval_results_run_idx on public.assistant_eval_results (run_id);

create or replace view public.assistant_eval_summary with (security_invoker = true) as
select run_id, min(created_at) started_at, count(*) questions,
       count(*) filter (where passed) passed,
       round(100.0 * avg(passed::int), 1) pass_pct,
       round(100.0 * avg(status_ok::int) filter (where expected_status = 'refused'), 1) refusal_pct,
       round(100.0 * avg(numbers_ok::int) filter (where expected_status = 'answered'), 1) numeric_accuracy_pct,
       round(100.0 * avg(grounded::int), 1) grounded_pct,
       percentile_disc(0.5) within group (order by latency_ms) p50_latency_ms,
       max(latency_ms) max_latency_ms
from public.assistant_eval_results group by run_id;

-- 6. Lock it down: only the service_role key (n8n) can use any of this.
alter table public.assistant_log enable row level security;
alter table public.assistant_eval_set enable row level security;
alter table public.assistant_eval_results enable row level security;

revoke all on public.assistant_log, public.assistant_eval_set, public.assistant_eval_results, public.assistant_eval_summary from anon, authenticated;
grant select, insert on public.assistant_log, public.assistant_eval_results to service_role;
grant select on public.assistant_eval_set, public.assistant_eval_summary to service_role;
grant usage on all sequences in schema public to service_role;

revoke execute on function public.kb_pending(), public.kb_set_embedding(bigint, text, text, text), public.kb_coverage(),
  public.kb_search(text, text, int, text), public.assistant_schema(), public.assistant_run_sql(text),
  public.assistant_cache_lookup(text) from public, anon, authenticated;
grant execute on function public.kb_pending(), public.kb_set_embedding(bigint, text, text, text), public.kb_coverage(),
  public.kb_search(text, text, int, text), public.assistant_schema(), public.assistant_run_sql(text),
  public.assistant_cache_lookup(text) to service_role;

-- Wrappers get an empty search_path (Supabase advisor 0011); all names inside are schema-qualified.
alter function public.kb_search(text, text, int, text) set search_path = '';
alter function public.assistant_schema() set search_path = '';
alter function public.assistant_run_sql(text) set search_path = '';
alter function public.assistant_cache_lookup(text) set search_path = '';

grant usage on schema cottonil to service_role;
revoke execute on function cottonil.kb_search_impl(text, text, int, text), cottonil.assistant_schema_impl(),
  cottonil.assistant_run_sql_impl(text) from public;
grant execute on function cottonil.kb_search_impl(text, text, int, text), cottonil.assistant_schema_impl(),
  cottonil.assistant_run_sql_impl(text) to service_role;

-- ---------------------------------------------------------------------------
-- 007f (2026-10-25): specific error hints in run_sql. The old hint named
-- "assistant_schema", but the agent's tool is called get_schema, and a view
-- name used as a column (discount_band) gave an unclear composite-type error.
-- Applied by replacing cottonil.assistant_run_sql_impl; only the exception
-- block changed:
--
-- exception when others then
--   return jsonb_build_object('ok', false, 'error', sqlerrm, 'hint', case
--     when sqlerrm ilike '%composite%' then 'You used a view name as a column. Column names differ from view names (e.g. analytics.discount_band has column band). Call get_schema for exact column names.'
--     when sqlerrm ilike '%does not exist%' then 'Unknown view or column. Call get_schema and use the exact names (all views are in schema analytics).'
--     else 'Call get_schema to check view and column names.' end);
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 007g (2026-10-25): versioned answer cache. n8n writes prompt_version on every
-- log row (constant PROMPT_VERSION in "Validate request"); the cache only reuses
-- rows of the same version, so a prompt/model change never serves old answers.
-- ---------------------------------------------------------------------------
alter table public.assistant_log add column if not exists prompt_version text;
drop function if exists public.assistant_cache_lookup(text);
create function public.assistant_cache_lookup(p_question text, p_version text)
 returns setof public.assistant_log
 language sql stable
 set search_path to ''
as $$
  select * from public.assistant_log
  where question_norm = lower(regexp_replace(btrim(p_question), '\s+', ' ', 'g'))
    and prompt_version = p_version
    and status in ('answered','refused') and coalesce(grounded, true) and not cached
    and channel <> 'eval'
    and created_at > now() - interval '24 hours'
  order by created_at desc limit 1;
$$;
revoke all on function public.assistant_cache_lookup(text, text) from public, anon, authenticated;
grant execute on function public.assistant_cache_lookup(text, text) to service_role;
