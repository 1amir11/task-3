"""Build clean load-ready CSVs for Supabase (Day 1).

Reads raw CSVs read-only, writes outputs/mart/<table>.csv.
- Every value is read as TEXT and written back unchanged, so no number is re-rounded.
- Only change: M/D/YYYY dates -> ISO YYYY-MM-DD, BOM removed, column names lower-cased (_EGP -> _egp).
- Rows are never dropped. sales_payments is not loaded (1:1 with orders, all 'Paid', amount = paid_total).
Run from project root:  python scripts/30_build_mart.py
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "COTTONIL" / "COTTONIL_Data" / "02_TABLES"
OUT = ROOT / "outputs" / "mart"
OUT.mkdir(parents=True, exist_ok=True)

# target file -> (raw file, M/D/YYYY date columns, primary key)
TABLES = {
    "dim_product":          ("products_catalog.csv", [], "product_id"),
    "dim_sku":              ("sku_variants.csv", [], "sku_id"),
    "dim_branch":           ("branches.csv", ["opening_date"], "branch_id"),
    "dim_customer":         ("customers.csv", ["joined_date"], "customer_id"),
    "fact_order":           ("sales_orders.csv", [], "sales_order_id"),
    "fact_order_line":      ("sales_order_items.csv", [], "sales_line_id"),
    "fact_return":          ("sales_returns.csv", [], "return_id"),
    "fact_shipment":        ("delivery_shipments.csv", [], "shipment_id"),
    "fact_opex":            ("operating_expenses.csv", [], "expense_id"),
    "fact_payroll":         ("payroll.csv", [], "payroll_id"),
    "ops_marketing_campaigns":  ("marketing_campaigns.csv", [], "campaign_id"),
    "ops_purchase_orders":      ("purchase_orders.csv", [], "po_id"),
    "ops_purchase_order_items": ("purchase_order_items.csv", [], "po_line_id"),
}
DROP = {"dim_product": ["source_url"]}  # URL column not needed in the database

for name, (raw, mdy, key) in TABLES.items():
    df = pd.read_csv(RAW / raw, encoding="utf-8-sig", dtype=str, keep_default_na=False)
    n_raw = len(df)
    df = df.drop(columns=DROP.get(name, []))
    for c in mdy:
        df[c] = pd.to_datetime(df[c], format="%m/%d/%Y").dt.strftime("%Y-%m-%d")
    assert df[key].is_unique, f"{name}: duplicate {key}"
    assert len(df) == n_raw, f"{name}: rows changed"
    df.columns = [c.replace("_EGP", "_egp") for c in df.columns]
    df.to_csv(OUT / f"{name}.csv", index=False, encoding="utf-8")
    size = (OUT / f"{name}.csv").stat().st_size / 1e6
    print(f"{name:26} rows {len(df):>9,}  cols {df.shape[1]:>2}  {size:7.1f} MB")

# check: the mart keeps the audit totals (recomputed from the written files)
o = pd.read_csv(OUT / "fact_order.csv", usecols=["net_before_tax_egp"])
l = pd.read_csv(OUT / "fact_order_line.csv", usecols=["quantity", "net_line_egp"])
print(f"\ncheck net (orders) {o.net_before_tax_egp.sum():,.2f}  net (lines) {l.net_line_egp.sum():,.2f}  "
      f"units {l.quantity.sum():,}  orders {len(o):,}")
