# Engagement 04 — Fintech Loan Portfolio — Deliverables

## What's here

```
dbt/                                    ← the dbt project (drop-in ready)
  models/staging/                       ← stg_applications, stg_loans, stg_repayments, stg_defaults + schema.yml
  models/intermediate/                  ← int_repayments_deduped, int_loan_delinquency, int_loan_register_status
  models/marts/                         ← fct_loan_performance, fct_portfolio_metrics, fct_par_reconciliation_bridge + schema.yml
  tests/                                ← 4 business-rule singular tests
  dbt_project.yml (incl. as_of_date/DPD threshold vars), packages.yml, profiles.example.yml
docs/
  assumptions_log.md                    ← the heavily-weighted deliverable — read this first
  default_definition.md                 ← the standalone policy doc (BRIEF.md deliverable #5)
  source_to_target_map.md
  architecture_diagram.md               ← mermaid, renders on GitHub
  data_quality_framework.md
  orchestration_design.md
  exec_summary.md
  deck_outline.md
  deck.pptx                             <- the actual PowerPoint deck (8-12 slides)
```

## How to validate against your Snowflake sandbox

```bash
# 1. Generate the data (from the original repo, not this folder)
cd analytics-engineering-fellowship/case-studies/04-fintech-loan-portfolio/data_generator
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
export SNOWFLAKE_ROLE=SYSADMIN SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=LENDWELL SNOWFLAKE_SCHEMA=RAW
python generate_data.py

# 2. Point this dbt project at it and build
cd ../../../../deliverables/04-fintech-loan-portfolio/dbt   # this folder
cp profiles.example.yml ~/.dbt/profiles.yml   # or merge into existing
dbt deps
dbt debug
dbt build
dbt docs generate && dbt docs serve
```

## What to sanity-check when it runs

- `dbt build` should show **~22 tests**, all passing (4 tagged `business_rule`).
- `select * from fct_par_reconciliation_bridge where product_type = 'ALL'` —
  `true_par30_loans` should be noticeably higher than `reported_par_loans`
  (the engagement's premise: reported PAR ~6%, true PAR roughly double per
  the CRO's kickoff quote — exact figures depend on your seed).
- `hidden_restructure_risk_par30` should be the largest single positive
  adjustment in the bridge — that's the headline finding.
- If `true_par_meets_or_exceeds_reported_par` ever fails, stop and re-check
  `int_loan_delinquency`/`fct_loan_performance` before touching the test
  itself — see the comment in that test file.
