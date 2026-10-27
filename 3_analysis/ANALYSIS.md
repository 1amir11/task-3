# Cottonil: analysis and method

Data: Cottonil extract, 19 Oct 2018 – 18 Oct 2026. It covers 540,000 orders, 1,138,536 order lines, 3,398,655 pieces and 841,274,176 EGP of net revenue before tax.
Years are calendar years. 2018 and 2026 are partial and are left out of trends.
Each claim is tagged:
- **Computed**: taken directly from the data.
- **Scenario**: a what-if built on the data.

## 1. How the numbers were checked
- **Three paths.** Every headline number was computed three ways:
  - pandas
  - plain Python `csv`, with no shared code
  - SQL in Supabase after loading

  All three agree, 28 of 28.
- **Grain proven before every join.** Rows = distinct keys in every table, with 0 duplicate keys and 0 orphan rows. Derived columns (gross, discount, net, margin) recompute to the cent.
- **Sources checked before use.** Each data area was tested to see whether it moves with sales. Five first readings did not survive this test (§3).

## 2. Six findings

| # | Finding | Number | Grain · window | Who acts | Type | Limit |
|---|---|---|---|---|---|---|
| 1 | **Growth comes from price, not pieces** | Net revenue ×10.83, pieces ×2.11, net per piece ×5.13. 2026 Jan–Sep vs 2025: net +32.6%, pieces +8.1% | Order lines · 2019 → 2025 | CFO, Commercial director | Computed | Shows how growth is made up. It does not prove pricing power: there is no competitor price and no price test |
| 2 | **Revenue rests on two men's categories** | Men boxers and men tops = 42.6% of net (boxers alone 23.1%). Top 10 of 139 products = 36.1%. Socks are 26.8% of pieces but 13.8% of net | Order lines · full history | Head of merchandising | Computed | The data holds no stock-out or substitution signal |
| 3 | **Each customer orders less often** | Orders per registered customer fell from 2.79 a year (2019) to 0.99 (2025). The customer list grew 6.0× (12,771 → 76,535) while registered orders grew 2.1×. 23,063 of 74,660 buyers (30.9%) have no order in 365 days. 2,645 of them are high-value, with 58,158,124 EGP of past spend | Registered customers · as of 18 Oct 2026 | CRM manager | Computed · reactivation value = Scenario | Customers who joined in 2018 and in 2024 order at the same rate today. The drop comes from the list growing faster than orders, not from newer customers being less loyal. The data cannot say why customers stop |
| 4 | **Every discount point comes out of margin** | Gross margin by line discount: 0% → 41.0% · 0–5% → 38.6% · 5–10% → 36.0% · 10–15% → 32.7% · 15–25% → 29.2%. Line return rate is flat at 2.45–2.55% in every band. A 10% cap would have kept **1,841,869 EGP** in Oct 2025 – Sep 2026 (34,806 lines) | Order lines · full history; cap on the last 12 months | Commercial director, Finance | Computed · cap = Scenario | No price experiment exists, so the volume a cap would lose is unknown |
| 5 | **Profit grew because costs grew slower than sales** | Gross margin stays at 38.15–38.39% every year. Opex fell from 29.1% to 13.6% of net, and the EBITDA proxy rose from 6.3% to 18.8% (2019 → 2025) | Calendar year | CFO | Computed · full payroll = Scenario | Payroll pays 185 of 640 listed staff in 2025. If all 640 were paid at the 2025 average, the 2025 EBITDA proxy would move from +44.1M to about −11.4M EGP. Confirm headcount before quoting profit |
| 6 | **One order in five has no customer** | 102,961 of 540,000 orders (19.07%) carry no customer ID. The share is the same in every channel and year | Orders · full history | Retail operations | Computed | Every customer figure undercounts by about 19% |

Seasonality: November and December run 21.1% and 24.3% above an average month; February runs 15.3% below.
Channels: stores 49.5%, wholesale 38.0%, online 12.5% of net.

## 3. First readings that changed after checking

| Area | First reading | What checking showed | Decision |
|---|---|---|---|
| Stock | 36.2 months of cover means overstock | Stores hold 6.2 months and the warehouse 30.0, and stock does not move with sales | No stock decision until a stock ledger exists |
| Purchasing | Cottonil buys ~100× what it sells | Every product gets about the same order quantity, whatever it sells (correlation 0.03) | Ask which business the purchase orders cover |
| Marketing | Campaigns drive 44.6× the real orders | The figure is clicks × a fixed rate. No order carries a campaign ID | No ROI claim. Ask for a campaign ID and a holdout |
| Customers | Each new customer group is less loyal | 2018 and 2024 joiners order at the same rate; the list grew 6×, orders 2.1× | Lead with orders per customer, 2.79 → 0.99 |
| Discount | Margin is flat whatever the discount | Line margin falls from 41.0% to 29.2% as the discount deepens | Built the discount guardrail |

## 4. What the data can and cannot answer
- **Usable (1 topic):** sales revenue.
- **Usable with a caveat (6 topics):**
  - price vs volume
  - customers (counts undercount by about 19%)
  - discount and margin
  - opex and EBITDA (payroll covers only part of the staff)
  - sales channel
  - returns
- **Not usable for decisions (5 topics):** marketing attribution, purchasing, inventory, branch ranking and delivery performance. These areas are not linked to real demand.

Every decision in this work rests on sales and customer records.

The full table is the **Data trust** tab of the dashboard. It is the same table the assistant reads before answering, so it refuses the same questions.

## 5. Questions for Cottonil
1. **Returns:** 27,940 returned orders are marked Completed or Delivered. Which status is correct?
2. **Customer type:** 98.1% of wholesale orders come from customers tagged Retail. Which tag drives pricing?
3. **Branch dates:** 38,040 orders are dated before their branch opened. Is `opening_date` a re-opening date?
4. **Headcount:** How many staff are actually on payroll? Finding 5 depends on the answer.
