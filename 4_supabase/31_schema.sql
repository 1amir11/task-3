-- Cottonil Task 3: Supabase schema (Day 1).
-- Applied to Supabase project "task3" as migration 001_cottonil_schema.
-- Money columns use plain NUMERIC (no scale), so the raw values are stored exactly and sums match the audit to the cent.
-- Schema `cottonil` = the trusted sales/customer spine (the assistant may read it through certified views later).
-- Schema `ops`      = operational tables kept only for the Data-Trust page and guard; never granted to the assistant.

create extension if not exists vector with schema extensions;

create schema if not exists cottonil;
create schema if not exists ops;

-- ---------------------------------------------------------------- dimensions
create table cottonil.dim_product (
  product_id        text primary key,
  product_name_ar   text not null,
  category_en       text not null,
  audience          text,
  listed_price_egp  numeric not null
);

create table cottonil.dim_sku (
  sku_id            text primary key,
  product_id        text not null references cottonil.dim_product,
  size              text,
  color_ar          text,
  price_multiplier  numeric
);

create table cottonil.dim_branch (
  branch_id             text primary key,
  branch_name_ar        text,
  governorate_ar        text,
  city_ar               text,
  retail_location_type  text,
  opening_date          date,         -- meaning unclear (first vs re-opening), see AUDIT
  address_ar            text          -- added by migration 002 (missed in 001)
);

create table cottonil.dim_customer (
  customer_id       text primary key,
  customer_segment  text,
  customer_name_ar  text,
  governorate_ar    text,
  joined_date       date,
  age_band          text
);

-- ---------------------------------------------------------------- facts (sales spine)
create table cottonil.fact_order (
  sales_order_id      text primary key,
  order_date          date not null,
  branch_id           text references cottonil.dim_branch,
  customer_id         text references cottonil.dim_customer,  -- NULL = anonymous (19.07%)
  sales_channel       text,
  payment_method      text,
  items_count         int,
  gross_egp           numeric,
  discount_egp        numeric,
  net_before_tax_egp  numeric,
  tax_egp             numeric,
  paid_total_egp      numeric,
  status              text
);

create table cottonil.fact_order_line (
  sales_line_id      text primary key,
  sales_order_id     text not null references cottonil.fact_order,
  order_date         date not null,
  branch_id          text,
  sku_id             text references cottonil.dim_sku,
  product_id         text references cottonil.dim_product,
  quantity           int not null,
  unit_price_egp     numeric,
  gross_line_egp     numeric,
  discount_line_egp  numeric,
  net_line_egp       numeric,
  unit_cost_egp      numeric,
  margin_egp         numeric
);

create table cottonil.fact_return (
  return_id          text primary key,
  sales_order_id     text references cottonil.fact_order,
  sales_line_id      text references cottonil.fact_order_line,
  return_date        date,
  sku_id             text,
  return_quantity    int,
  refund_amount_egp  numeric,
  reason             text,
  refund_method      text
);

create table cottonil.fact_shipment (
  shipment_id          text primary key,
  sales_order_id       text references cottonil.fact_order,
  ship_date            date,
  delivery_date        date,
  ship_to_governorate  text,
  carrier              text,
  shipping_fee_egp     numeric,
  fulfillment_status   text
);

create table cottonil.fact_opex (
  expense_id               text primary key,
  expense_date             date,
  branch_or_department_id  text,
  expense_category         text,
  amount_egp               numeric,
  payment_method           text,
  vendor_name              text
);

create table cottonil.fact_payroll (
  payroll_id        text primary key,
  employee_id       text,
  pay_month         char(7),          -- YYYY-MM
  base_salary_egp   numeric,
  overtime_egp      numeric,
  bonus_egp         numeric,
  deductions_egp    numeric,
  net_paid_egp      numeric
);

create index on cottonil.fact_order (order_date);
create index on cottonil.fact_order (customer_id);
create index on cottonil.fact_order_line (sales_order_id);
create index on cottonil.fact_order_line (order_date);
create index on cottonil.fact_order_line (product_id);

-- ---------------------------------------------------------------- ops (not demand-linked; trust page only)
create table ops.marketing_campaigns (
  campaign_id        text primary key,
  start_date         date,
  end_date           date,
  channel            text,
  target_audience    text,
  governorate_ar     text,
  budget_egp         numeric,
  spend_egp          numeric,
  impressions        bigint,
  clicks             bigint,
  orders_attributed  bigint
);

create table ops.purchase_orders (
  po_id                   text primary key,
  po_date                 date,
  supplier_id             text,
  receiving_warehouse_id  text,
  po_status               text,
  currency                text,
  po_subtotal_egp         numeric,
  payment_terms_days      int,
  po_purpose              text
);

create table ops.purchase_order_items (
  po_line_id     text primary key,
  po_id          text references ops.purchase_orders,
  sku_id         text,
  quantity       int,
  unit_cost_egp  numeric,
  line_cost_egp  numeric,
  delivery_date  date
);

-- ---------------------------------------------------------------- knowledge base for RAG
-- The embedding column is added once the embedding provider is chosen (vector size depends on it).
create table cottonil.kb_chunks (
  id          bigserial primary key,
  chunk_type  text not null check (chunk_type in ('metric','finding','trust_rule','sql_example','glossary')),
  title       text not null,
  content     text not null,
  metadata    jsonb not null default '{}'::jsonb,
  fts         tsvector generated always as (to_tsvector('simple', title || ' ' || content)) stored
);
create index on cottonil.kb_chunks using gin (fts);

-- ---------------------------------------------------------------- read-only role for the assistant (NOLOGIN for now)
-- Grants on certified views are added on Day 2; Amir sets LOGIN + password himself.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'assistant_ro') then
    create role assistant_ro nologin;
  end if;
end $$;
revoke all on schema ops from assistant_ro;
