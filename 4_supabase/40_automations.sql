-- Day 5: tables + functions behind the 3 business automations (migration 008_automations).
-- n8n calls these through the Supabase API (RPC); all logic and numbers live here, n8n only orchestrates.
-- Data clock: the dataset ends 2026-10-18, so "yesterday" / "last week" mean the last day in the data.
-- Privacy: only customer_id leaves the database; names and phones stay in cottonil.dim_customer.

-- ---------------------------------------------------------------- run log (one row per workflow run)
create table if not exists public.automation_runs (
  id          bigserial primary key,
  created_at  timestamptz not null default now(),
  workflow    text not null check (workflow in ('reactivation', 'guardrail', 'digest')),
  source      text,                       -- schedule | dashboard | manual | replay
  status      text not null check (status in ('ok', 'alert', 'pending_approval', 'approved', 'rejected', 'expired', 'nothing_to_do', 'error')),
  data_day    date,
  summary     text,
  payload     jsonb
);
create index if not exists automation_runs_wf_idx on public.automation_runs (workflow, created_at desc);
alter table public.automation_runs enable row level security;

-- reactivation members: treatment vs random holdout, so the lift can be measured later
create table if not exists public.reactivation_members (
  run_id        bigint not null references public.automation_runs (id) on delete cascade,
  customer_id   text not null,
  arm           text not null check (arm in ('treatment', 'holdout')),
  fav_category  text,
  recency_days  int,
  orders        bigint,
  net_egp       numeric,
  primary key (run_id, customer_id)
);
alter table public.reactivation_members enable row level security;

-- the guardrail reads one day at a time
create index if not exists fact_order_line_date_idx on cottonil.fact_order_line (order_date);

-- ---------------------------------------------------------------- 1) reactivation
-- Picks High-value dormant buyers (>365 days, m_score 5), skips anyone in an approved treatment group in the
-- last p_cooldown_days, and holds out p_holdout_pct at random (hash of customer + run, so it is reproducible).
create or replace function public.reactivation_pick(p_source text default 'manual', p_holdout_pct int default 10, p_cooldown_days int default 90)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_run bigint; v_day date; r jsonb;
begin
  select max(order_date) into v_day from cottonil.fact_order;
  insert into public.automation_runs (workflow, source, status, data_day)
  values ('reactivation', p_source, 'pending_approval', v_day) returning id into v_run;

  insert into public.reactivation_members (run_id, customer_id, arm, fav_category, recency_days, orders, net_egp)
  select v_run, c.customer_id,
         case when abs(hashtext(c.customer_id || ':' || v_run)) % 100 < p_holdout_pct then 'holdout' else 'treatment' end,
         c.fav_category, c.recency_days, c.orders, c.net_egp
  from cottonil.mv_customer_rfm c
  where c.value_tier = 'High' and c.dormant
    and not exists (
      select 1 from public.reactivation_members m join public.automation_runs a on a.id = m.run_id
      where m.customer_id = c.customer_id and m.arm = 'treatment' and a.status = 'approved'
        and a.created_at > now() - make_interval(days => p_cooldown_days));

  select jsonb_build_object(
    'run_id', v_run, 'data_day', v_day,
    'selected', count(*),
    'treatment', count(*) filter (where arm = 'treatment'),
    'holdout', count(*) filter (where arm = 'holdout'),
    'past_spend_egp', coalesce(round(sum(net_egp)), 0),
    'median_recency_days', percentile_cont(0.5) within group (order by recency_days),
    'groups', coalesce((
      select jsonb_agg(g order by g.customers desc) from (
        select fav_category category, count(*) customers, round(sum(net_egp)) past_spend_egp,
               round(avg(recency_days)) avg_recency_days
        from public.reactivation_members where run_id = v_run and arm = 'treatment' group by 1) g), '[]'::jsonb))
  into r from public.reactivation_members where run_id = v_run;

  update public.automation_runs
     set payload = r, status = case when (r->>'selected')::int = 0 then 'nothing_to_do' else status end
   where id = v_run;
  return r;
end $$;

-- Human in the loop: the CRM manager approves or rejects; messages are stored with the decision.
create or replace function public.reactivation_decide(p_run_id bigint, p_decision text, p_messages jsonb default null, p_summary text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if p_decision not in ('approved', 'rejected', 'expired') then
    return jsonb_build_object('ok', false, 'error', 'decision must be approved, rejected or expired');
  end if;
  update public.automation_runs
     set status = p_decision,
         payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object('decision', p_decision, 'decided_at', now())
                   || case when p_messages is null then '{}'::jsonb else jsonb_build_object('messages', p_messages) end,
         summary = coalesce(p_summary, summary)
   where id = p_run_id and workflow = 'reactivation' and status = 'pending_approval'
  returning status into v_status;
  if v_status is null then return jsonb_build_object('ok', false, 'error', 'run not found or already decided'); end if;
  return jsonb_build_object('ok', true, 'run_id', p_run_id, 'status', v_status);
end $$;

-- Did it work? Buyers who ordered after the run, treatment vs holdout (lift in percentage points).
create or replace function public.reactivation_results(p_run_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  with a as (select data_day from public.automation_runs where id = p_run_id),
  m as (
    select m.arm, exists (select 1 from cottonil.fact_order o, a
                          where o.customer_id = m.customer_id and o.order_date > a.data_day) bought
    from public.reactivation_members m where m.run_id = p_run_id),
  s as (select arm, count(*) n, count(*) filter (where bought) buyers,
               round(100.0 * count(*) filter (where bought) / nullif(count(*), 0), 2) pct
        from m group by arm)
  select jsonb_build_object(
    'run_id', p_run_id,
    'arms', (select jsonb_object_agg(arm, jsonb_build_object('customers', n, 'buyers', buyers, 'buy_pct', pct)) from s),
    'lift_pp', (select max(pct) filter (where arm = 'treatment') - max(pct) filter (where arm = 'holdout') from s));
$$;

-- ---------------------------------------------------------------- 2) discount guardrail
-- One day of lines above 15% discount: EGP given above a 10% cap, by channel and category, vs the median of the
-- previous 28 days. status = alert when the excess is more than 1.5x that median.
create or replace function public.discount_guardrail(p_day date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_min date; v_max date; v_day date; r jsonb;
begin
  select min(order_date), max(order_date) into v_min, v_max from cottonil.fact_order;
  v_day := coalesce(p_day, v_max);
  if v_day < v_min or v_day > v_max then
    return jsonb_build_object('ok', false, 'error', format('day must be between %s and %s', v_min, v_max));
  end if;

  with d as (select * from cottonil.v_discount_alert_lines where order_date = v_day),
  hist as (
    select order_date, sum(excess_over_10pct_cap_egp) ex
    from cottonil.v_discount_alert_lines
    where order_date between v_day - 28 and v_day - 1 group by 1),
  base as (select percentile_cont(0.5) within group (order by ex) med from hist),
  y as (select count(*) n, sum(excess_over_10pct_cap_egp) ex from cottonil.v_discount_alert_lines
        where order_date > v_day - 365 and order_date <= v_day)
  select jsonb_build_object(
    'ok', true, 'day', v_day,
    'lines', (select count(*) from d),
    'excess_egp', (select coalesce(round(sum(excess_over_10pct_cap_egp)), 0) from d),
    'discount_egp', (select coalesce(round(sum(discount_line_egp)), 0) from d),
    'avg_discount_pct', (select round(avg(discount_pct), 2) from d),
    'by_channel', coalesce((select jsonb_agg(c order by c.excess_egp desc) from (
        select sales_channel channel, count(*) lines, round(sum(excess_over_10pct_cap_egp)) excess_egp from d group by 1) c), '[]'::jsonb),
    'by_category', coalesce((select jsonb_agg(c order by c.excess_egp desc) from (
        select category_en category, count(*) lines, round(sum(excess_over_10pct_cap_egp)) excess_egp from d group by 1
        order by 3 desc limit 5) c), '[]'::jsonb),
    'top_lines', coalesce((select jsonb_agg(t) from (
        select sales_line_id, sales_channel channel, category_en category, discount_pct, round(excess_over_10pct_cap_egp) excess_egp
        from d order by excess_over_10pct_cap_egp desc limit 3) t), '[]'::jsonb),
    'baseline_median_excess_egp', (select round(med::numeric) from base),
    'vs_baseline', (select round(coalesce(sum(excess_over_10pct_cap_egp), 0) / nullif((select med from base), 0)::numeric, 2) from d),
    'status', case when (select coalesce(sum(excess_over_10pct_cap_egp), 0) from d) > 1.5 * coalesce((select med from base), 0)
                    and (select count(*) from d) > 0 then 'alert' else 'ok' end,
    'l12m_lines', (select n from y),
    'l12m_excess_egp', (select round(ex) from y))
  into r;
  return r;
end $$;

-- ---------------------------------------------------------------- 3) weekly digest
-- Last complete Mon-Sun week in the data vs the previous week and the same week last year,
-- plus how the automations and the assistant performed (assistant stats use real time, not the data clock).
create or replace function public.weekly_digest(p_week_end date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_max date; v_end date; r jsonb;
begin
  select max(order_date) into v_max from cottonil.fact_order;
  v_end := coalesce(p_week_end, v_max - (extract(isodow from v_max)::int % 7));
  with w as (
    select 'this_week' k, v_end - 6 d0, v_end d1 union all
    select 'prev_week', v_end - 13, v_end - 7 union all
    select 'last_year', v_end - 370, v_end - 364),
  o as (
    select w.k, count(*) orders, round(sum(o.net_before_tax_egp)) net_egp, round(avg(o.net_before_tax_egp), 2) aov_egp,
           round(100 * sum(o.discount_egp) / nullif(sum(o.gross_egp), 0), 2) discount_pct,
           count(distinct o.customer_id) buyers
    from w join cottonil.fact_order o on o.order_date between w.d0 and w.d1 group by w.k),
  l as (
    select w.k, round(100 * sum(l.margin_egp) / nullif(sum(l.net_line_egp), 0), 2) gm_pct, sum(l.quantity) units
    from w join cottonil.fact_order_line l on l.order_date between w.d0 and w.d1 group by w.k),
  g as (
    select round(sum(excess_over_10pct_cap_egp)) ex, count(*) n from cottonil.v_discount_alert_lines
    where order_date between v_end - 6 and v_end),
  a as (
    select count(*) questions,
           count(*) filter (where status = 'answered') answered,
           count(*) filter (where status = 'refused') refused,
           count(*) filter (where status = 'error') errors,
           round(100.0 * count(*) filter (where status = 'answered' and grounded) / nullif(count(*) filter (where status = 'answered'), 0), 1) grounded_pct,
           round(100.0 * count(*) filter (where cached) / nullif(count(*), 0), 1) cache_hit_pct,
           percentile_cont(0.5) within group (order by latency_ms) filter (where not cached) p50_latency_ms
    from public.assistant_log where channel in ('dashboard', 'api') and created_at > now() - interval '7 days')
  select jsonb_build_object(
    'week', jsonb_build_object('from', v_end - 6, 'to', v_end),
    'kpis', (select jsonb_object_agg(o.k, to_jsonb(o) - 'k' || jsonb_build_object('gm_pct', l.gm_pct, 'units', l.units))
             from o join l using (k)),
    'guardrail', (select jsonb_build_object('lines_above_15pct', n, 'excess_egp', coalesce(ex, 0)) from g),
    'reactivation_last_run', (select jsonb_build_object('run_id', id, 'status', status, 'created_at', created_at,
                                     'treatment', payload->'treatment', 'holdout', payload->'holdout')
                              from public.automation_runs where workflow = 'reactivation' and status <> 'nothing_to_do'
                              order by created_at desc limit 1),
    'assistant_7d', (select to_jsonb(a) from a),
    'eval_last', (select jsonb_build_object('run_id', run_id, 'pass_pct', pass_pct, 'numeric_accuracy_pct', numeric_accuracy_pct)
                  from public.assistant_eval_summary order by started_at desc limit 1))
  into r;
  return r;
end $$;

-- ---------------------------------------------------------------- access: server-side (n8n service key) only
revoke all on table public.automation_runs, public.reactivation_members from anon, authenticated;
grant select, insert, update on public.automation_runs to service_role;
grant select on public.reactivation_members to service_role;
grant usage, select on sequence public.automation_runs_id_seq to service_role;
revoke all on function public.reactivation_pick(text, int, int), public.reactivation_decide(bigint, text, jsonb, text),
  public.reactivation_results(bigint), public.discount_guardrail(date), public.weekly_digest(date)
  from public, anon, authenticated;
grant execute on function public.reactivation_pick(text, int, int), public.reactivation_decide(bigint, text, jsonb, text),
  public.reactivation_results(bigint), public.discount_guardrail(date), public.weekly_digest(date)
  to service_role;

-- 008b (2026-10-25): grounded_pct in weekly_digest now divides by answered rows only (it showed 130.8%). The line above is the fixed version.
