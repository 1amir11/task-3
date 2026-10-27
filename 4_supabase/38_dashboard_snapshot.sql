-- Dashboard data snapshot (Day 3). Run in Supabase "task3"; the JSON result is pasted into dashboard/data.js.
-- Every number on the dashboard comes from these queries over the analytics layer (no number typed by hand).

-- 1) Main snapshot
select json_build_object(
 'yearly',(select json_agg(json_build_object('yr',yr,'orders',orders,'units',units,'gross',round(gross_egp),'disc',round(discount_egp),'net',round(net_egp),'margin',round(margin_egp),'gm',round(gm_pct,2),'npu',round(net_per_unit,2),'opex',round(opex_egp),'opex_pct',round(opex_pct,2),'payroll',round(payroll_egp),'paid',paid_employees,'ebitda',round(ebitda_proxy_egp),'ebitda_pct',round(ebitda_proxy_pct,2),'pool',customer_pool,'active',active_customers,'opc',round(orders_per_pool_customer,3),'act_pct',round(active_pct_of_pool,1),'partial',partial_year) order by yr) from analytics.kpi_yearly),
 'monthly',(select json_agg(json_build_object('m',to_char(month,'YYYY-MM'),'net',round(net_egp),'units',units,'orders',orders,'gm',round(gm_pct,2)) order by month) from analytics.kpi_monthly where not partial_month),
 'category',(select json_agg(x order by net desc) from (select category_en cat, sum(units) units, round(sum(net_egp)) net, round(100*sum(margin_egp)/sum(net_egp),2) gm from analytics.category_year group by 1) x),
 'products',(select json_agg(x) from (select product_name_ar n, category_en c, units, round(net_egp) net, round(gm_pct,2) gm from analytics.product_totals order by net_egp desc limit 10) x),
 'disc',(select json_agg(json_build_object('band',band,'lines',lines,'gross',round(gross_egp),'disc',round(discount_egp),'net',round(net_egp),'gm',round(gm_pct,2),'ret',round(line_return_pct,2)) order by band_order) from analytics.discount_band),
 'season',(select json_agg(json_build_object('m',month_of_year,'net',round(net_index,1),'units',round(units_index,1)) order by month_of_year) from analytics.seasonality),
 'channel',(select json_agg(x order by net desc) from (select sales_channel ch, sum(orders) orders, round(sum(net_egp)) net from analytics.channel_year group by 1) x),
 'trust',(select json_agg(t) from analytics.data_trust t),
 'rfm',(select json_agg(x) from (select value_tier tier, dormant, count(*) n, round(sum(net_egp)) net, round(avg(aov_egp)) aov from analytics.customer_rfm group by 1,2 order by 1,2) x),
 'buyers',(select count(*) from analytics.customer_rfm),
 'onetime',(select count(*) from analytics.customer_rfm where orders=1)
) j;

-- 2) Automation previews + YTD / L12M
select json_build_object(
 'react_cat',(select json_agg(x) from (select fav_category, count(*) n from analytics.customer_rfm where dormant and value_tier='High' group by 1 order by 2 desc limit 5) x),
 'ytd',(select json_build_object('net26',sum(net_egp) filter (where month between '2026-01-01' and '2026-09-01'),'net25',sum(net_egp) filter (where month between '2025-01-01' and '2025-09-01'),'u26',sum(units) filter (where month between '2026-01-01' and '2026-09-01'),'u25',sum(units) filter (where month between '2025-01-01' and '2025-09-01')) from analytics.kpi_monthly),
 'l12m',(select json_build_object('net',sum(net_egp),'gross',sum(gross_egp),'disc',sum(discount_egp)) from analytics.kpi_monthly where month between '2025-10-01' and '2026-09-01'),
 'guard_day',(select json_agg(x) from (select sales_channel ch, count(*) n, round(sum(excess_over_10pct_cap_egp)) ex from cottonil.v_discount_alert_lines where order_date='2026-09-30' group by 1 order by 3 desc) x)
) j;

-- 3) Discount-cap simulator: EGP of discount above a cap, L12M order lines
select c cap_pct, count(*) filter (where l.discount_line_egp > l.gross_line_egp*c/100.0) lines_over,
 round(sum(greatest(l.discount_line_egp - l.gross_line_egp*c/100.0, 0))) excess_egp
from cottonil.fact_order_line l, (values (5),(7.5),(10),(12.5),(15)) v(c)
where l.order_date between '2025-10-01' and '2026-09-30'
group by c order by c;

-- 4) "How it's built" tab (added 2026-10-27): database size, table rows, knowledge base, eval, automation runs
select json_build_object(
 'db_mb', round(pg_database_size(current_database())/1048576.0),
 'rows', (select json_object_agg(relname, n_live_tup) from pg_stat_user_tables where schemaname in ('cottonil','ops') and (relname like 'fact_%' or relname like 'dim_%' or relname like 'marketing%')),
 'analytics_views', (select count(*) from information_schema.views where table_schema='analytics'),
 'mviews', (select count(*) from pg_matviews),
 'kb', (select json_build_object('n',count(*),'emb',count(embedding)) from cottonil.kb_chunks),
 'eval_last', (select row_to_json(e) from (select * from public.assistant_eval_summary order by started_at desc limit 1) e),
 'asklog', (select count(*) from public.assistant_log),
 'runs', (select json_object_agg(workflow, n) from (select workflow, count(*) n from public.automation_runs group by 1) r)
) j;
