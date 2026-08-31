# Engagement 05 — Healthcare Appointment Analytics — Deliverables

## What's here

```
dbt/                                    ← the dbt project (drop-in ready)
  models/staging/                       ← stg_patients, stg_doctors, stg_appointments, stg_billing + schema.yml
  models/intermediate/                  ← int_appointments_deduped, int_appointments_canonical,
                                           int_appointment_chains, int_billing_agg
  models/marts/                         ← fct_appointments, fct_patient_engagement,
                                           fct_noshow_reconciliation_bridge + schema.yml
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
cd analytics-engineering-fellowship/case-studies/05-healthcare-appointment-analytics/data_generator
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
export SNOWFLAKE_ROLE=SYSADMIN SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=CAREGRID SNOWFLAKE_SCHEMA=RAW
python generate_data.py

# 2. Point this dbt project at it and build
cd ../../../../deliverables/05-healthcare-appointment-analytics/dbt   # this folder
cp profiles.example.yml ~/.dbt/profiles.yml   # or merge into existing
dbt deps
dbt debug
dbt build
dbt docs generate && dbt docs serve
```

## What to sanity-check when it runs

- `dbt build` should show **~20 tests**, all passing (4 tagged `business_rule`).
- `select * from fct_noshow_reconciliation_bridge where location = 'ALL'` —
  `naive_no_show_rate` should land near ~22%, `true_no_show_rate` near ~13%
  (exact figures depend on your seed).
- `reschedule_misflags` should be the largest single subtracted component
  in the bridge — that's the headline finding.
- If `no_double_counted_visit_intent` ever fails, check
  `int_appointment_chains` before anything else — it means a row is either
  missing from every chain or appearing in more than one.
