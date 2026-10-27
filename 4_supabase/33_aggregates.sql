-- Day 2: certified aggregate tables (materialized views) for the dashboard, n8n and the assistant.
-- Applied as migration 004_aggregates. Refresh with: refresh materialized view cottonil.<name>;
-- Windows: FULL 2018-10-19..2026-10-18; YEARS 2019-2025 for trends; SNAP 2026-10-18 for recency.
set local statement_timeout = 0;

-- 1) Monthly KPIs (grain: calendar month). Orders/registered/active from fact_order; units/money from lines.
create materialized view cottonil.mv_kpi_monthly as
with o as (
  select date_trunc('month', order_date)::date as month,
         count(*) orders,
         count(customer_id) registered_orders,
         count(distinct customer_id) active_customers
  from cottonil.fact_order group by 1),
l as (
  select date_trunc('month', order_date)::date as month,
         sum(quantity) units, sum(gross_line_egp) gross_egp, sum(discount_line_egp) discount_egp,
         sum(net_line_egp) net_egp, sum(margin_egp) margin_egp
  from cottonil.fact_order_line group by 1)
select o.month, o.orders, o.registered_orders, o.active_customers, l.units, l.gross_egp, l.discount_egp,
       l.net_egp, l.margin_egp, round(100 * l.margin_egp / l.net_egp, 4) gm_pct,
       (o.month = '2018-10-01' or o.month = '2026-10-01') partial_month
from o join l using (month) order by month;

-- 2) Yearly KPIs incl. costs and customer frequency (grain: calendar year).
create materialized view cottonil.mv_kpi_yearly as
with m as (
  select extract(year from month)::int yr, sum(orders) orders, sum(registered_orders) registered_orders,
         sum(units) units, sum(gross_egp) gross_egp, sum(discount_egp) discount_egp,
         sum(net_egp) net_egp, sum(margin_egp) margin_egp
  from cottonil.mv_kpi_monthly group by 1),
act as (select extract(year from order_date)::int yr, count(distinct customer_id) active_customers
        from cottonil.fact_order where customer_id is not null group by 1),
ox as (select extract(year from expense_date)::int yr, sum(amount_egp) opex_egp from cottonil.fact_opex group by 1),
pay as (select left(pay_month, 4)::int yr, sum(net_paid_egp) payroll_egp, count(distinct employee_id) paid_employees
        from cottonil.fact_payroll group by 1),
pool as (select y yr, (select count(*) from cottonil.dim_customer where joined_date <= make_date(y, 12, 31)) customer_pool
         from generate_series(2018, 2026) y)
select m.yr, m.orders, m.registered_orders, m.units, m.gross_egp, m.discount_egp, m.net_egp, m.margin_egp,
       round(100 * m.margin_egp / m.net_egp, 4) gm_pct,
       round(m.net_egp / m.units, 4) net_per_unit,
       ox.opex_egp, round(100 * ox.opex_egp / m.net_egp, 4) opex_pct,
       pay.payroll_egp, pay.paid_employees,
       m.margin_egp - ox.opex_egp - pay.payroll_egp ebitda_proxy_egp,
       round(100 * (m.margin_egp - ox.opex_egp - pay.payroll_egp) / m.net_egp, 4) ebitda_proxy_pct,
       pool.customer_pool, act.active_customers,
       round(m.registered_orders::numeric / pool.customer_pool, 4) orders_per_pool_customer,
       round(100.0 * act.active_customers / pool.customer_pool, 2) active_pct_of_pool,
       (m.yr in (2018, 2026)) partial_year
from m join ox using (yr) join pay using (yr) join pool using (yr) join act using (yr) order by m.yr;

-- 3) Category x year (grain: category-year).
create materialized view cottonil.mv_category_year as
select extract(year from l.order_date)::int yr, p.category_en, sum(l.quantity) units, sum(l.net_line_egp) net_egp,
       sum(l.margin_egp) margin_egp,
       round(100 * sum(l.net_line_egp) / sum(sum(l.net_line_egp)) over (partition by extract(year from l.order_date)::int), 4) share_of_year_pct
from cottonil.fact_order_line l join cottonil.dim_product p using (product_id)
group by 1, 2 order by 1, 4 desc;

-- 4) Discount band vs margin and returns (grain: order line, FULL window).
create materialized view cottonil.mv_discount_band as
with x as (
  select l.*, l.discount_line_egp / nullif(l.gross_line_egp, 0) dp,
         exists (select 1 from cottonil.fact_return r where r.sales_line_id = l.sales_line_id) returned
  from cottonil.fact_order_line l)
select case when dp = 0 then '0%' when dp <= 0.05 then '0-5%' when dp <= 0.10 then '5-10%'
            when dp <= 0.15 then '10-15%' else '15-25%' end band,
       min(case when dp = 0 then 1 when dp <= 0.05 then 2 when dp <= 0.10 then 3 when dp <= 0.15 then 4 else 5 end) band_order,
       count(*) lines, sum(gross_line_egp) gross_egp, sum(discount_line_egp) discount_egp,
       sum(net_line_egp) net_egp, sum(margin_egp) margin_egp,
       round(100 * sum(margin_egp) / sum(net_line_egp), 4) gm_pct,
       round(100.0 * avg(returned::int), 4) line_return_pct
from x group by 1 order by 2;

-- 5) Seasonality index, 2019-2025: each year normalised to its own monthly mean (=100), then averaged.
create materialized view cottonil.mv_seasonality as
with m as (select extract(year from month)::int yr, extract(month from month)::int mo, net_egp, units
           from cottonil.mv_kpi_monthly where month between '2019-01-01' and '2025-12-01'),
n as (select mo, 100 * net_egp / avg(net_egp) over (partition by yr) ni, 100 * units / avg(units) over (partition by yr) ui from m)
select mo month_of_year, round(avg(ni), 4) net_index, round(avg(ui), 4) units_index from n group by mo order by mo;

-- 6) Customer RFM snapshot at 2026-10-18 (grain: registered buyer). Used by the Reactivation workflow.
create materialized view cottonil.mv_customer_rfm as
with o as (
  select customer_id, min(order_date) first_order, max(order_date) last_order, count(*) orders,
         sum(net_before_tax_egp) net_egp
  from cottonil.fact_order where customer_id is not null group by 1),
fav as (
  select distinct on (o.customer_id) o.customer_id, p.category_en fav_category
  from cottonil.fact_order o join cottonil.fact_order_line l using (sales_order_id)
       join cottonil.dim_product p on p.product_id = l.product_id
  where o.customer_id is not null
  group by o.customer_id, p.category_en
  order by o.customer_id, sum(l.net_line_egp) desc),
b as (
  select o.*, round(o.net_egp / o.orders, 2) aov_egp, ('2026-10-18'::date - o.last_order) recency_days,
         ntile(5) over (order by o.last_order) r_score,
         ntile(5) over (order by o.orders) f_score,
         ntile(5) over (order by o.net_egp) m_score
  from o)
select b.customer_id, c.customer_name_ar, c.governorate_ar, c.customer_segment, c.age_band, c.joined_date,
       b.first_order, b.last_order, b.orders, b.net_egp, b.aov_egp, b.recency_days, f.fav_category,
       b.r_score, b.f_score, b.m_score, (b.recency_days > 365) dormant,
       case when b.m_score = 5 then 'High' when b.m_score >= 3 then 'Mid' else 'Low' end value_tier
from b join cottonil.dim_customer c using (customer_id) join fav f using (customer_id);
create unique index on cottonil.mv_customer_rfm (customer_id);

-- 7) Discount guardrail feed: lines with discount above 15% (grain: order line; the workflow filters one day).
create view cottonil.v_discount_alert_lines as
select l.order_date, l.sales_order_id, l.sales_line_id, o.sales_channel, p.category_en, p.product_name_ar,
       l.quantity, l.gross_line_egp, l.discount_line_egp, l.net_line_egp, l.margin_egp,
       round(100 * l.discount_line_egp / l.gross_line_egp, 2) discount_pct,
       round(l.discount_line_egp - 0.10 * l.gross_line_egp, 2) excess_over_10pct_cap_egp
from cottonil.fact_order_line l
join cottonil.fact_order o using (sales_order_id)
join cottonil.dim_product p on p.product_id = l.product_id
where l.discount_line_egp > 0.15 * l.gross_line_egp;
