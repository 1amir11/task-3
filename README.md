# Cottonil: Commercial Review, Automations and Data Assistant
HVIA Data & AI Solutions, Case Study 3 · Amir · October 2026

Cottonil's sales grew 10.8× from 2019 to 2025, while the number of pieces sold grew only 2.1×. This package covers four things:
- **Analysis:** the evidence behind that story.
- **Dashboard:** tells the story chapter by chapter.
- **Automations:** turn the findings into weekly work in n8n, on top of a Supabase database.
- **Assistant:** answers questions about the data with a number and its source, or refuses when the data cannot answer.

## What is in this folder

| Folder | Open this | What it shows |
|---|---|---|
| `1_dashboard/` | `index.html` | The dashboard, in 9 tabs: Overview → Growth → Range & season → Customers → Discount → Costs → Automations → Data trust → How it's built. Includes the "Ask the data" chat. |
| `2_presentation/` | `Cottonil_pitch.pptx` | The 15-slide pitch, with tool logos and dashboard screenshots. |
| `3_analysis/` | `ANALYSIS.md` | The six findings, each with its number, grain, owner and limit. Also: how the numbers were checked, the first readings that changed, what the data cannot answer, and questions for Cottonil. |
| `4_supabase/` | `31_schema.sql` … `40_automations.sql` | The whole database, step by step (see below). |
| `5_n8n_workflows/` | `01_assistant.json` … `07_weekly_digest.json` | The 7 n8n workflows, ready to import (see below). |

## How to open the dashboard
From inside `1_dashboard/`, run this command, then open http://localhost:8765:
```
python -m http.server 8765
```
You can also double-click `index.html`. Every chart, table and simulator works offline. Only the chat and the **Run now** buttons need the n8n server to be running.

## How it is built

```
Raw CSV extract ──► Python clean mart ──► Supabase (Postgres 17 + pgvector) ──► n8n workflows ──► Dashboard / Telegram
                                           • cottonil: sales spine, 1.95M rows        • Ask the data (RAG + SQL)
                                           • analytics: 9 certified views              • Reactivation (monthly)
                                           • kb_chunks: 46 entries, vector(1536)       • Discount guardrail (daily)
                                           • logs: every run and every question        • Weekly digest
                                                                                        • KB refresh + weekly eval
```

| Step | File | Does |
|---|---|---|
| 1 | `30_build_mart.py` | Turns the raw CSVs into 13 clean files and checks the totals against the raw data |
| 2 | `31_schema.sql`, `32_load.sql` | Creates the tables with keys, then loads them in one transaction |
| 3 | `33_aggregates.sql`, `35_analytics_layer.sql` | Pre-computed tables, certified views, the data-trust table, and a read-only role for the assistant |
| 4 | `36_match_kb.sql`, `37_kb_seed.sql` | Hybrid search (keyword + vector) and the knowledge base: definitions, rules, checked SQL |
| 5 | `39_rag_api.sql` | The assistant's safe SQL tool (SELECT only, read-only, row limit), answer cache, logs, and the 19-question test set |
| 6 | `40_automations.sql` | The functions behind Reactivation, the Discount guardrail and the Weekly digest |
| 7 | `38_dashboard_snapshot.sql` | The queries that produced every number in `1_dashboard/data.js` |

## The n8n workflows

| File | Runs | Does |
|---|---|---|
| `01_assistant.json` | Webhook, on demand | Checks the question → cache → embedding → hybrid search → AI agent with 3 tools (schema, read-only SQL, knowledge) → checks every number against the SQL → answers and logs |
| `02_kb_ingestion.json` | Nightly 03:00 | Embeds only new or changed knowledge entries; coverage must reach 100% |
| `03_eval.json` | Sunday 07:00 | Sends the 19 test questions to the assistant and grades them; fails below 90% |
| `04_error_alerts.json` | On any failure | Logs failures of the other workflows to Supabase |
| `05_reactivation.json` | 1st of month, or Run now | Picks dormant high-value buyers, holds out ~10%, writes Arabic messages, asks the CRM manager on Telegram |
| `06_discount_guardrail.json` | Daily 08:00, or Run now | Measures discount above the cap; alerts on Telegram only on unusual days |
| `07_weekly_digest.json` | Monday 08:00 | Week-over-week KPIs, discount leakage, workflow health. No AI |

**To import:** In n8n, open a new workflow, choose ⋯ → Import from file, then:
1. Create 3 credentials: **Supabase API** (named `Cottonil`), **OpenRouter** (`Cottonil`) and **Telegram** (`Cottonil_project`).
2. In the Config node of workflows 05, 06 and 07, set `TELEGRAM_CHAT_ID`.
3. In `03_eval.json`, replace `YOUR-N8N-HOST` with your n8n address.

The files contain no keys and no chat IDs.

## Results in one line each
- **Growth is price, not volume.** Net revenue grew 10.8× from 2019 to 2025; pieces sold grew 2.1×.
- **Customers buy less often.** Orders per registered customer fell from 2.79 to 0.99 a year. 2,645 high-value buyers, with 58.2M EGP of past spend, have been quiet for over a year. The **Reactivation** workflow targets them.
- **Discounts cost margin.** Gross margin falls from 41.0% on lines sold at full price to 29.2% on lines discounted 15–25%. A 10% cap would have kept 1.84M EGP in the last 12 months (scenario). The **Discount guardrail** workflow flags this every morning.
- **Revenue is concentrated.** Two men's categories make 42.6% of revenue.
- **Profit gains rest on cost leverage, and need a check.** Payroll covers 185 of 640 listed staff, so the EBITDA proxy must be confirmed before anyone quotes it.
- **The assistant passed 19 of 19 questions** in its last test run (24 Oct 2026), refusals included. It cannot read any raw table, and the test set runs again every Sunday.

## Limits
- Stock, purchasing, marketing attribution, branches and delivery are not linked to real demand in this data. The **Data trust** tab lists what can and cannot be said. Every decision uses sales and customer data only.
- Numbers tagged **Scenario** are what-ifs, not forecasts.
- No password or API key is in this package. The keys live only in the n8n credentials.
