-- Load outputs/mart/*.csv into Supabase "task3" (run once by Amir via Docker psql; see outputs/BUILD_LOG.md).
-- One transaction: if any file fails, nothing is loaded. HEADER MATCH checks the CSV column names against the table.
\set ON_ERROR_STOP on
-- Supabase's default statement timeout is too short for 1.1M rows with FK checks; lift it for this session only.
set statement_timeout = 0;
begin;
\copy cottonil.dim_product      from '/mart/dim_product.csv'      with (format csv, header match)
\copy cottonil.dim_sku          from '/mart/dim_sku.csv'          with (format csv, header match)
\copy cottonil.dim_branch (branch_id, branch_name_ar, governorate_ar, city_ar, address_ar, retail_location_type, opening_date) from '/mart/dim_branch.csv'       with (format csv, header match)
\copy cottonil.dim_customer     from '/mart/dim_customer.csv'     with (format csv, header match)
\copy cottonil.fact_order       from '/mart/fact_order.csv'       with (format csv, header match)
\copy cottonil.fact_order_line  from '/mart/fact_order_line.csv'  with (format csv, header match)
\copy cottonil.fact_return      from '/mart/fact_return.csv'      with (format csv, header match)
\copy cottonil.fact_shipment    from '/mart/fact_shipment.csv'    with (format csv, header match)
\copy cottonil.fact_opex        from '/mart/fact_opex.csv'        with (format csv, header match)
\copy cottonil.fact_payroll     from '/mart/fact_payroll.csv'     with (format csv, header match)
\copy ops.marketing_campaigns   from '/mart/ops_marketing_campaigns.csv'  with (format csv, header match)
\copy ops.purchase_orders       from '/mart/ops_purchase_orders.csv'      with (format csv, header match)
\copy ops.purchase_order_items  from '/mart/ops_purchase_order_items.csv' with (format csv, header match)
commit;

select 'fact_order' t, count(*) from cottonil.fact_order
union all select 'fact_order_line', count(*) from cottonil.fact_order_line
union all select 'dim_customer', count(*) from cottonil.dim_customer;
