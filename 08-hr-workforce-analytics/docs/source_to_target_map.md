# Source-to-Target Mapping — Engagement 08

## RAW_DEPARTMENTS → stg_departments

| Source column | Staging column | Transform | Notes |
|---|---|---|---|
| `DEPARTMENT_ID` | `department_id` | passthrough | unique/not_null tested |
| `DEPARTMENT_CODE` | `department_code` | passthrough | |
| `DEPARTMENT_NAME` | `department_name` | passthrough | grain of `fct_department_workforce` |
| `DIVISION` | `division` | passthrough | division-level rollup attribute |
| `COST_CENTER` | `cost_center` | passthrough | cost-center rollup attribute |

## RAW_EMPLOYEES → stg_employees → int_employees_deduped → int_employment_records_resolved → int_employment_chain_classified → int_person_employment_summary → fct_workforce

| Source column | Staging column | Transform | Downstream | Notes |
|---|---|---|---|---|
| `EMPLOYEE_ID` | `employee_id` | passthrough | dedup key, chain key | unique/not_null tested |
| `PERSON_ID` | `person_id` | passthrough | `fct_workforce.person_id` (PK) | A1 |
| `FULL_NAME` | `full_name` | passthrough | not carried into marts | |
| `DEPARTMENT_ID` | `department_id` | passthrough | `current_department_id`, department attribution | relationships tested |
| `JOB_LEVEL` | `job_level` | passthrough | `current_job_level` | |
| `EMPLOYMENT_TYPE` | `employment_type` | `lower(trim())` | `current_employment_type` | |
| `LOCATION` | `location` | passthrough | `current_location` | |
| `HIRE_DATE` | `hire_date` | passthrough | `first_ever_hire_date` / `most_recent_hire_date`, all tenure math | |
| `TERMINATION_DATE` | `termination_date` | passthrough | authoritative for `is_open` (A5) | |
| `EMPLOYMENT_STATUS` | `raw_employment_status` | `lower(trim())` | `resolved_state` (only trusted once closed — A5) | accepted_values tested at staging |
| `PRIOR_EMPLOYEE_ID` | `prior_employee_id` | passthrough | transfer/rehire classification (A2, A3) | |
| *(derived)* | — | dedup on `(person_id, department_id, hire_date, termination_date)` | `is_duplicate_record` | A6 |
| *(derived)* | — | date-authoritative priority logic | `resolved_state`, `is_status_date_conflict` | A5 |
| *(derived)* | — | prior-record self-join | `is_transfer_successor`, `is_rehire_successor`, `gap_days_before` | A2, A3 |
| *(derived)* | — | person-level aggregation | `tenure_time_in_seat_days`, `tenure_since_first_hire_days`, `current_stint_span_days` | A3 |

## RAW_PERFORMANCE_REVIEWS → stg_performance_reviews → int_reviews_deduped

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `REVIEW_ID` | `review_id` | passthrough | (aggregated away) | unique/not_null tested |
| `EMPLOYEE_ID` | `employee_id` | passthrough | joins to employment records; orphan check against `int_employees_deduped` | not_null tested |
| `PERSON_ID` | `person_id` | passthrough | not currently in marts (available for a future performance-by-person cut) | |
| `REVIEW_PERIOD` | `review_period` | passthrough | dedup key | |
| `RATING` | `rating` | `lower(trim())` | dedup key | accepted_values tested |
| `REVIEW_SCORE` | `review_score` | passthrough | dedup key | |
| `REVIEWER_ID` | `reviewer_id` | passthrough | not currently in marts | |
| `REVIEW_DATE` | `review_date` | passthrough (nulls preserved) | `is_missing_review_date` flag | A7; never backfilled |
| *(derived)* | — | dedup on `(employee_id, review_period, rating, review_score)` | `is_duplicate_review` | A7 |
| *(derived)* | — | orphan check against deduped employees | `is_orphaned_review` | A6 |

## RAW_PAYROLL → stg_payroll → int_payroll_deduped

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `PAYROLL_ID` | `payroll_id` | passthrough | dedup tiebreak | unique/not_null tested |
| `EMPLOYEE_ID` | `employee_id` | passthrough | orphan check against `int_employees_deduped` | not_null tested |
| `PERSON_ID` | `person_id` | passthrough | not currently in cost marts (A8) | |
| `PAY_PERIOD` | `pay_period` | passthrough | dedup key | |
| `GROSS_PAY` | `gross_pay` | passthrough | not currently in company-level marts (A8) | |
| `CURRENCY` | `currency_code` | `upper(trim())` | carried through, not normalized (A8) | accepted_values tested |
| `IS_PARTIAL_PERIOD` | `is_partial_period` | passthrough | not currently in marts | |
| `PAID_AT` | `paid_at` | passthrough | not currently in marts | |
| *(derived)* | — | dedup on `(employee_id, pay_period)` | `is_duplicate_period` | A7 |
| *(derived)* | — | orphan check against deduped employees | `is_orphaned_payroll` | A6 |

## Grain summary

| Layer | Model | Grain |
|---|---|---|
| staging | `stg_departments`/`stg_employees`/`stg_performance_reviews`/`stg_payroll` | 1:1 with source table |
| intermediate | `int_employees_deduped` | 1 row per raw employment record (dupes flagged, not dropped) |
| intermediate | `int_employment_records_resolved` | 1 row per non-duplicate employment record, status/date resolved |
| intermediate | `int_employment_chain_classified` | 1 row per non-duplicate employment record, transfer/rehire classified |
| intermediate | `int_person_employment_summary` | 1 row per `person_id` |
| intermediate | `int_payroll_deduped` / `int_reviews_deduped` | 1 row per raw payroll/review row (dupes + orphans flagged) |
| marts | `fct_workforce` | 1 row per `person_id` (BRIEF.md's required person-grain) |
| marts | `fct_department_workforce` | 1 row per `department_id`, plus 1 `'ALL'` row |
| marts | `fct_attrition_tenure_reconciliation_bridge` | single row, trailing attrition window |
