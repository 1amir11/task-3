-- Day 2: hybrid search over the knowledge base (migration 006_match_kb).
-- Combines vector similarity (pgvector, cosine) and keyword search (full-text) with Reciprocal Rank Fusion:
--   score = 1/(60 + vector_rank) + 1/(60 + keyword_rank)
-- If query_embedding is NULL (e.g., before embeddings exist), it falls back to keyword search only.
create or replace function cottonil.match_kb(
  query_text      text,
  query_embedding extensions.vector(1536) default null,
  match_count     int default 6,
  type_filter     text default null)
returns table (id bigint, chunk_type text, title text, content text, metadata jsonb, score double precision)
language sql stable
set search_path = cottonil, extensions, public
as $$
  with vec as (
    select k.id, row_number() over (order by k.embedding <=> query_embedding) r
    from cottonil.kb_chunks k
    where query_embedding is not null and k.embedding is not null
      and (type_filter is null or k.chunk_type = type_filter)
    order by k.embedding <=> query_embedding limit 30),
  kw as (
    select k.id, row_number() over (order by ts_rank(k.fts, q) desc) r
    from cottonil.kb_chunks k, websearch_to_tsquery('simple', query_text) q
    where k.fts @@ q and (type_filter is null or k.chunk_type = type_filter)
    order by ts_rank(k.fts, q) desc limit 30),
  fused as (
    select coalesce(v.id, w.id) id,
           coalesce(1.0 / (60 + v.r), 0) + coalesce(1.0 / (60 + w.r), 0) score
    from vec v full join kw w on v.id = w.id)
  select k.id, k.chunk_type, k.title, k.content, k.metadata, f.score::double precision
  from fused f join cottonil.kb_chunks k on k.id = f.id
  order by f.score desc limit match_count;
$$;

grant execute on function cottonil.match_kb(text, extensions.vector, int, text) to assistant_ro;
