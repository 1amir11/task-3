-- Day 2: knowledge-base content for the assistant's RAG (loaded into cottonil.kb_chunks).
-- Every SQL example was run against the analytics views on 2026-10-23; metadata.verified_answer = the result.
-- Embeddings are added later by an n8n workflow (OpenAI text-embedding-3-small).
-- Rerunnable (upsert on title): ids stay fixed, so assistant_eval_set.kb_id keeps pointing at the right chunk.
-- Only an edited chunk gets a new content_hash, so the nightly KB ingestion re-embeds just that one. A title dropped from this list is deleted.
create unique index if not exists kb_chunks_title_key on cottonil.kb_chunks (title);

with seed (chunk_type, title, content, metadata) as (values
-- ============================================================ glossary / rules of answering
('glossary', 'How to answer (rules)',
 'Rules: every number must come from a SQL result on the analytics schema, never from memory. Always state grain and window. Currency EGP, net = net before tax. Windows: FULL 2018-10-19..2026-10-18; trends use complete years 2019-2025; 2018 and 2026 are partial; YTD = Jan-Sep 2026 vs Jan-Sep 2025; snapshot date 2026-10-18. Before answering about any topic, check analytics.data_trust; if status = not_usable, refuse and explain the reason. Do not make causal claims.',
 '{"lang":"en"}'),
('glossary', 'Arabic terms / مصطلحات',
 'الإيراد / المبيعات = net revenue (net_egp). الأوردرات = orders. القطع / الكمية = units. هامش الربح / الربحية = gross margin (gm_pct). الخصم = discount. العملاء الخاملين / اللي بطلوا يشتروا = dormant customers. معدل الشراء / تكرار الشراء = orders per customer per year (orders_per_pool_customer). الموسمية = seasonality. الفئة / القسم = category. المرتجعات = returns. المصاريف التشغيلية = opex. الفروع = branches. الحملات / التسويق = marketing campaigns. المشتريات = purchase orders. المخزون = stock / inventory.',
 '{"lang":"ar"}'),
('glossary', 'Available views',
 'analytics.kpi_monthly (month), analytics.kpi_yearly (yr; includes opex, payroll, ebitda_proxy, customer_pool, orders_per_pool_customer), analytics.category_year (yr, category_en), analytics.product_totals (product, FULL), analytics.channel_year (yr, sales_channel), analytics.discount_band (band), analytics.seasonality (month_of_year), analytics.customer_rfm (one row per registered buyer, snapshot 2026-10-18), analytics.returns_year (yr), analytics.data_trust (topic, status, safe_to_say, cannot_answer, reason).',
 '{"lang":"en"}'),

-- ============================================================ metric definitions
('metric', 'Net revenue / الإيراد',
 'Net revenue = sum of net_egp (net before tax, after discount). Grain: order line, aggregated by month in analytics.kpi_monthly and by year in analytics.kpi_yearly. FULL total 841,274,176 EGP. 2019 = 21,620,205 EGP; 2025 = 234,138,548 EGP. Mark 2018 and 2026 as partial years.',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Units and orders / القطع والأوردرات',
 'Units = sum of quantity on order lines (3,398,655 FULL). Orders = count of orders (540,000 FULL). Both in analytics.kpi_monthly / kpi_yearly. Units per order is flat (~6.3) every year.',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Gross margin / هامش الربح',
 'Gross margin % = margin_egp / net_egp x 100, where margin = net - quantity x unit cost. Column gm_pct. About 38.3% in every year (2025 = 38.35%). Cost of goods is part of the extract, not audited.',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Net per unit / متوسط سعر القطعة',
 'Net per unit = net_egp / units (column net_per_unit in analytics.kpi_yearly). It grew 5.13x from 2019 to 2025, while units grew 2.11x.',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Purchase frequency / معدل الشراء',
 'orders_per_pool_customer = registered orders in the year / customers who had joined by year end (customer_pool). 2019 = 2.79, 2020 = 1.61, 2021 = 1.26, 2022 = 1.12, 2023 = 1.06, 2024 = 1.00, 2025 = 0.99. active_pct_of_pool = share of the pool that ordered at least once that year (78.25% in 2019, 61.61% in 2025).',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Dormant customer / العميل الخامل',
 'Dormant = registered buyer whose last order is more than 365 days before the snapshot 2026-10-18 (column dormant in analytics.customer_rfm). 23,063 of 74,660 buyers = 30.89%. Dormant is not the same as churned: the data has no reason or contact info.',
 '{"view":"analytics.customer_rfm"}'),
('metric', 'RFM and value tier',
 'In analytics.customer_rfm: r_score/f_score/m_score are quintiles (1-5, 5 = best) of recency, number of orders and net spend. value_tier: High = m_score 5, Mid = 3-4, Low = 1-2. fav_category = the category with the highest net spend for that customer. Older customers have more orders, so High value partly means long tenure.',
 '{"view":"analytics.customer_rfm"}'),
('metric', 'Discount band / شرائح الخصم',
 'Discount % per order line = discount / gross. Bands: 0%, 0-5%, 5-10%, 10-15%, 15-25% (max 20%). analytics.discount_band gives lines, discount_egp, gm_pct and line_return_pct per band. Total discount 37.9M EGP (FULL).',
 '{"view":"analytics.discount_band"}'),
('metric', 'Seasonality index / الموسمية',
 'Each year 2019-2025 is normalised so that its average month = 100, then the 12 months are averaged across years (analytics.seasonality, net_index and units_index). Peak December 124.3, November 121.1; low February 84.7.',
 '{"view":"analytics.seasonality"}'),
('metric', 'Opex and EBITDA proxy / المصاريف والربح التشغيلي',
 'opex_pct = operating expenses / net revenue (analytics.kpi_yearly). ebitda_proxy = gross margin - opex - payroll; it is NOT audited EBITDA (no D&A, interest, tax). 2019: opex 29.08%, EBITDA proxy 6.31%. 2025: opex 13.63%, EBITDA proxy 18.83%. Always add the payroll-coverage caveat from analytics.data_trust (topic opex_ebitda).',
 '{"view":"analytics.kpi_yearly"}'),
('metric', 'Category share / حصة الفئة',
 'Category share = category net / total net. analytics.category_year has net per category per year and share_of_year_pct. FULL: Men boxers 23.08%, Men tops 19.56%, Socks 13.81%.',
 '{"view":"analytics.category_year"}'),
('metric', 'Returns / المرتجعات',
 'analytics.returns_year: returns count, units returned and refund_egp by return year. FULL: 28,500 returns, 13,914,504 EGP refunds = 1.65% of net. Order-level return rate 5.28%; line-level about 2.5%. Do not mix the two grains.',
 '{"view":"analytics.returns_year"}'),
('metric', 'Sales channel / القنوات',
 'analytics.channel_year: orders, net and AOV by year and sales_channel (Retail POS, Wholesale / reseller, E-commerce). FULL share of net: Retail POS 49.48%, Wholesale 37.99%, E-commerce 12.53%. Channel is an order label, see data_trust.',
 '{"view":"analytics.channel_year"}'),

-- ============================================================ findings (the story)
('finding', 'Finding 1: growth is price-led / النمو جاي من السعر',
 'Net revenue grew 10.83x from 2019 to 2025 while units grew only 2.11x; net per unit grew 5.13x. YTD Jan-Sep 2026 vs 2025: net +32.55%, units +8.13%. Owner: CFO / Commercial. Limitation: prices follow a ramp to the 2026 catalogue; no elasticity can be estimated.',
 '{"tag":"computed"}'),
('finding', 'Finding 2: discount erodes margin / الخصم بياكل الهامش',
 'Line gross margin is 41.0% with no discount and falls to 38.6% (0-5%), 36.0% (5-10%), 32.7% (10-15%) and 29.2% (15-25%). Total discount 37.9M EGP. Returns are flat across bands (~2.5% of lines), so deeper discounts do not reduce returns. Action: test a 10% discount cap. Owner: Commercial director. Limitation: the volume response is unknown.',
 '{"tag":"computed"}'),
('finding', 'Finding 3: customers buy less often / العملاء بيشتروا أقل',
 'Orders per registered customer per year fell from 2.79 (2019) to 0.99 (2025): the registered base grew about 6x (12,771 to 76,535) while registered orders grew about 2.1x. 23,063 buyers (30.9%) are dormant; their lifetime net is 158.6M EGP; 2,645 of them are High value (58.2M EGP lifetime). Action: reactivation campaign with a 10% holdout. Scenario: 5% reactivation at their own average order value is about 1.44M EGP.',
 '{"tag":"computed + scenario"}'),
('finding', 'Finding 4: menswear concentration / التركيز في الرجالي',
 'Men boxers (23.08%) and Men tops (19.56%) are 42.6% of net revenue; the single top product (3 قطع بوكسر رجالى مارسريزيه) is 7.50%. Mix is stable over time. Owner: Merchandising. Limitation: no substitution data.',
 '{"tag":"computed"}'),
('finding', 'Finding 5: profit gains are operating leverage / الربح جاي من تخفيض نسبة المصاريف',
 'Gross margin is flat (~38.3%), opex fell from 29.1% to 13.6% of net (2019-2025) and the EBITDA proxy rose from 6.3% to 18.8%; it was near zero in 2020-2022. Owner: CFO. Limitation: payroll covers only 62-322 of 640 employees per year; with full payroll the 2025 proxy could be negative (scenario).',
 '{"tag":"computed + scenario"}'),
('finding', 'Seasonality for planning / الموسمية للتخطيط',
 'November (121.1) and December (124.3) are the peak months, February (84.7) the low. The shape is the same for all categories. Use it for staffing and stock planning in October.',
 '{"tag":"computed"}'),

-- ============================================================ trust rules (refusals)
('trust_rule', 'Marketing ROI / عائد الحملات',
 'Questions about marketing ROI, ROAS, orders or revenue from campaigns, or the best marketing channel: refuse. Reason: no campaign_id links orders to campaigns, and orders_attributed is clicks x a fixed rate (24.1M = 44.6x the 540,000 real orders). Safe to say: 2,200 campaigns and 219.5M EGP campaign spend, which is 18.7x the Marketing line in opex (11.76M EGP), so the spend scope must be confirmed.',
 '{"topic":"marketing"}'),
('trust_rule', 'Inventory and stock / المخزون',
 'Questions about stockouts, overstock, days of cover or reorder: refuse. Reason: stock tables are not linked to sales demand and there is no stock ledger; the stockout score has no predictive power.',
 '{"topic":"inventory"}'),
('trust_rule', 'Purchasing and suppliers / المشتريات والموردين',
 'Questions about supplier performance, purchase volumes, working capital or landed cost: refuse. Reason: purchase order quantity is statistically uniform (90-6,500 per line), 99.9x units sold and unrelated to demand; no goods-receipt table.',
 '{"topic":"purchasing"}'),
('trust_rule', 'Branch ranking / ترتيب الفروع',
 'Questions about the best or worst branch, branch performance or where to open: refuse to rank. Reason: orders are assigned to branches at random (all 80 branches sell 9.8M-11.4M EGP); 38,040 orders predate the branch opening date.',
 '{"topic":"branches"}'),
('trust_rule', 'Delivery and carriers / الشحن',
 'Questions about the best carrier or delivery performance: refuse to compare. Reason: the 3 carriers are identical (4-day median, ~3% delayed, ~51 EGP fee) and delay does not depend on lead time.',
 '{"topic":"delivery"}'),
('trust_rule', 'Return reasons / أسباب المرتجعات',
 'Questions about why customers return or which product has the most returns: give totals only. Reason: the 5 reasons are spread evenly (19.8%-20.3%) and do not vary by category or channel. Totals (28,500 returns, 13.9M EGP, 1.65% of net) are usable.',
 '{"topic":"returns"}'),
('trust_rule', 'Churn reasons and loyalty / أسباب ترك العملاء',
 'Questions about why customers stopped buying or which cohort is more loyal: do not claim a cause. Reason: every registered customer orders at the same yearly rate regardless of join year; the drop in frequency comes from the base growing faster than orders.',
 '{"topic":"customers"}'),
('trust_rule', 'Channel profitability / ربحية القنوات',
 'Questions about which channel is more profitable: say margin and discount are the same across channels; channel is an order label (98.1% of wholesale orders come from Retail-tagged customers). Revenue share by channel is usable.',
 '{"topic":"sales_channel"}'),
('trust_rule', 'Forecasts and causes / التوقعات والأسباب',
 'Questions asking for a forecast or a cause (why did sales grow, what will sales be next year): give the computed trend and seasonality only and say it is not a forecast model. No promotion, weather or competitor data exists.',
 '{"topic":"general"}'),
('trust_rule', 'Individual customers / بيانات عميل معين',
 'Questions asking for a specific customer''s name or personal data: refuse. The assistant answers about segments and totals only; customer names are not in its views.',
 '{"topic":"privacy"}'),

-- ============================================================ SQL examples (few-shot), each verified
('sql_example', 'Revenue in a year / الإيراد في سنة',
 'Q: الإيراد في 2025 كام؟ / What was net revenue in 2025?
SQL: select net_egp from analytics.kpi_yearly where yr = 2025;',
 '{"verified_answer":"234,138,548 EGP"}'),
('sql_example', 'Growth 2019 to 2025 / النمو',
 'Q: المبيعات زادت قد إيه من 2019 لـ 2025؟ والكمية؟
SQL: select max(net_egp) filter (where yr=2025) / max(net_egp) filter (where yr=2019) net_x, max(units) filter (where yr=2025)::numeric / max(units) filter (where yr=2019) units_x from analytics.kpi_yearly;',
 '{"verified_answer":"10.83x net, 2.11x units"}'),
('sql_example', 'Year to date / من أول السنة',
 'Q: أداء 2026 لحد دلوقتي مقارنة بنفس الفترة من 2025؟
SQL: select sum(net_egp) filter (where month between ''2026-01-01'' and ''2026-09-01'') / sum(net_egp) filter (where month between ''2025-01-01'' and ''2025-09-01'') - 1 net_growth, sum(units) filter (where month between ''2026-01-01'' and ''2026-09-01'')::numeric / sum(units) filter (where month between ''2025-01-01'' and ''2025-09-01'') - 1 units_growth from analytics.kpi_monthly;',
 '{"verified_answer":"net +32.55%, units +8.13% (Jan-Sep)"}'),
('sql_example', 'Top categories / أكبر الفئات',
 'Q: أكتر فئات بتبيع؟ / Top categories by revenue
SQL: select category_en, round(100 * sum(net_egp) / sum(sum(net_egp)) over (), 2) share_pct from analytics.category_year group by 1 order by 2 desc limit 5;',
 '{"verified_answer":"Men boxers 23.08%, Men tops 19.56%, Socks 13.81%"}'),
('sql_example', 'Top product / أكتر منتج',
 'Q: أكتر منتج بيجيب إيراد؟
SQL: select product_name_ar, category_en, net_egp, round(100 * net_egp / sum(net_egp) over (), 2) share_pct from analytics.product_totals order by net_egp desc limit 5;',
 '{"verified_answer":"3 قطع بوكسر رجالى مارسريزيه 7.50%"}'),
('sql_example', 'Dormant customers / العملاء الخاملين',
 'Q: كام عميل بطّل يشتري؟
SQL: select count(*) filter (where dormant) dormant, count(*) buyers, round(100.0 * avg(dormant::int), 2) pct, sum(net_egp) filter (where dormant) dormant_lifetime_net from analytics.customer_rfm;',
 '{"verified_answer":"23,063 of 74,660 = 30.89%; lifetime net 158.6M EGP"}'),
('sql_example', 'High-value dormant / العملاء المهمين اللي بطلوا',
 'Q: كام عميل مهم (high value) خامل؟
SQL: select count(*), sum(net_egp) from analytics.customer_rfm where dormant and value_tier = ''High'';',
 '{"verified_answer":"2,645 customers, 58,158,124 EGP lifetime net"}'),
('sql_example', 'Purchase frequency trend / معدل الشراء',
 'Q: العميل بيشتري كام مرة في السنة؟ واتغير إزاي؟
SQL: select yr, orders_per_pool_customer, active_pct_of_pool, customer_pool from analytics.kpi_yearly where yr between 2019 and 2025 order by yr;',
 '{"verified_answer":"2.79 (2019) -> 0.99 (2025)"}'),
('sql_example', 'Discount vs margin / الخصم والهامش',
 'Q: الخصم بيأثر على الربح؟
SQL: select band, lines, discount_egp, gm_pct, line_return_pct from analytics.discount_band order by band_order;',
 '{"verified_answer":"41.0% -> 38.6% -> 36.0% -> 32.7% -> 29.2%"}'),
('sql_example', 'Peak months / أعلى شهور',
 'Q: إيه أعلى شهور في المبيعات؟
SQL: select month_of_year, net_index from analytics.seasonality order by net_index desc;',
 '{"verified_answer":"Dec 124.3, Nov 121.1, May 107.9; Feb lowest 84.7"}'),
('sql_example', 'Opex and EBITDA / المصاريف والربح',
 'Q: نسبة المصاريف والربح التشغيلي اتغيرت إزاي؟
SQL: select yr, gm_pct, opex_pct, ebitda_proxy_pct, paid_employees from analytics.kpi_yearly where yr between 2019 and 2025 order by yr;',
 '{"verified_answer":"2019 opex 29.08% EBITDA 6.31%; 2025 opex 13.63% EBITDA 18.83%"}'),
('sql_example', 'Channel share / حصة القنوات',
 'Q: كل قناة بتجيب كام في المية من المبيعات؟
SQL: select sales_channel, round(100 * sum(net_egp) / sum(sum(net_egp)) over (), 2) share_pct from analytics.channel_year group by 1 order by 2 desc;',
 '{"verified_answer":"Retail POS 49.48%, Wholesale 37.99%, E-commerce 12.53%"}'),
('sql_example', 'Returns total / المرتجعات',
 'Q: المرتجعات كام؟
SQL: select sum(returns) returns, sum(refund_egp) refund_egp from analytics.returns_year;',
 '{"verified_answer":"28,500 returns, 13,914,504 EGP"}'),
('sql_example', 'Check trust before answering',
 'Q: الحملات الإعلانية جابت كام أوردر؟ (any question on a risky topic)
SQL: select status, safe_to_say, cannot_answer, reason from analytics.data_trust where topic = ''marketing'';
Then: status is not_usable, so refuse and explain the reason; give safe_to_say only.',
 '{"verified_answer":"not_usable"}')),
up as (
  insert into cottonil.kb_chunks (chunk_type, title, content, metadata)
  select chunk_type, title, content, metadata::jsonb from seed
  on conflict (title) do update set chunk_type = excluded.chunk_type, content = excluded.content, metadata = excluded.metadata
  where (kb_chunks.chunk_type, kb_chunks.content, kb_chunks.metadata) is distinct from (excluded.chunk_type, excluded.content, excluded.metadata)
  returning id)
delete from cottonil.kb_chunks where title not in (select title from seed);
