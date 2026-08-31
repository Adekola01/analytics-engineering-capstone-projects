# Engagement 01 — E-Commerce Revenue Leakage — Deliverables

## What's here

```
dbt/                                    ← the dbt project (drop-in ready)
  models/staging/                       ← stg_orders, stg_payments, stg_refunds, stg_shipping + schema.yml
  models/intermediate/                  ← int_payments_deduped, int_order_financials
  models/marts/                         ← fct_revenue, fct_revenue_monthly, fct_revenue_reconciliation_bridge + schema.yml
  tests/                                ← 4 business-rule singular tests
  dbt_project.yml, packages.yml, profiles.example.yml
docs/
  assumptions_log.md                    ← the heavily-weighted deliverable — read this first
  source_to_target_map.md
  architecture_diagram.md               ← mermaid, renders on GitHub
  business_metric_definitions.md
  data_quality_framework.md
  orchestration_design.md
  exec_summary.md
  deck_outline.md
```

## How to validate against your Snowflake sandbox

```bash
# 1. Generate the data (from the original repo, not this folder)
cd analytics-engineering-fellowship/case-studies/01-ecommerce-revenue-leakage/data_generator
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
export SNOWFLAKE_ROLE=SYSADMIN SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=LUMEN_LOOM SNOWFLAKE_SCHEMA=RAW
python generate_data.py

# 2. Point this dbt project at it and build
cd ../../../../deliverables/01-ecommerce-revenue-leakage/dbt   # this folder
cp profiles.example.yml ~/.dbt/profiles.yml   # or merge into existing
dbt deps
dbt debug
dbt build
dbt docs generate && dbt docs serve
```

## What to sanity-check when it runs

- `dbt build` should show **30 tests**, all passing (4 tagged `business_rule`).
- `select * from fct_revenue_reconciliation_bridge` — `finance_reconciled_number`
  minus `ops_number`, as a % (`gap_pct_of_ops_number`), should land roughly in
  the 8–12% range the brief describes, though the exact figure will vary with
  your seed/order count.
- If any business-rule test fails, it's worth checking first whether it's a
  real bug vs. a generator-version difference — the model logic is written
  directly against the generator's documented behavior (see `generate_data.py`
  flaw catalog referenced in `assumptions_log.md`), but always re-verify
  against your actual loaded data before assuming the model is wrong.
