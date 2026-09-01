# Engagement 08 — HR Workforce Analytics — Deliverables

## What's here

```
dbt/                                    ← the dbt project (drop-in ready)
  models/staging/                       ← stg_departments, stg_employees, stg_performance_reviews,
                                           stg_payroll + schema.yml
  models/intermediate/                  ← int_employees_deduped, int_employment_records_resolved,
                                           int_employment_chain_classified, int_person_employment_summary,
                                           int_payroll_deduped, int_reviews_deduped
  models/marts/                         ← fct_workforce, fct_department_workforce,
                                           fct_attrition_tenure_reconciliation_bridge + schema.yml
  tests/                                ← 4 business-rule singular tests
  dbt_project.yml (incl. as_of_date/attrition_window vars), packages.yml, profiles.example.yml
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
cd analytics-engineering-fellowship/case-studies/08-hr-workforce-analytics/data_generator
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
export SNOWFLAKE_ROLE=SYSADMIN SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=PEOPLECORE SNOWFLAKE_SCHEMA=RAW
python generate_data.py

# 2. Point this dbt project at it and build
cd ../../../../deliverables/08-hr-workforce-analytics/dbt   # this folder
cp profiles.example.yml ~/.dbt/profiles.yml   # or merge into existing
dbt deps
dbt debug
dbt build
dbt docs generate && dbt docs serve
```

## What to sanity-check when it runs

- `dbt build` should show **~20 tests**, all passing (4 tagged `business_rule`).
- `select * from fct_attrition_tenure_reconciliation_bridge` —
  `naive_finance_attrition_rate` should land in the 22–33% range the brief
  describes, `true_attrition_rate` meaningfully lower; `transfer_closure_count`
  should be the largest single subtracted component.
- `select department_name, transfers_in, transfers_out from
  fct_department_workforce where department_name != 'ALL'` — `sum(transfers_in)`
  and `sum(transfers_out)` should be exactly equal.
- `avg_tenure_since_first_hire_years` should be noticeably higher than
  `avg_current_stint_span_years`, with `avg_tenure_time_in_seat_years`
  sitting between them — that's the ~1-year spread from the brief,
  decomposed.
- If `transfers_net_to_zero_across_departments` or
  `department_headcount_sums_to_company_total` ever fail, check
  `int_employment_chain_classified` first — see the comments in those test
  files.
