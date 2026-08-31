# Source-to-Target Mapping — Engagement 04

## RAW_APPLICATIONS → stg_applications

| Source column | Staging column | Transform | Notes |
|---|---|---|---|
| `APPLICATION_ID` | `application_id` | passthrough | unique/not_null tested |
| `CUSTOMER_ID` | `customer_id` | passthrough | |
| `PRODUCT_TYPE` | `product_type` | passthrough | |
| `CHANNEL` | `channel` | passthrough | |
| `REQUESTED_AMOUNT` | `requested_amount` | passthrough | not carried into loan marts |
| `CURRENCY` | `currency_code` | `upper(trim())` | not normalized (A8) |
| `DECISION` | `decision` | `lower(trim())` | accepted_values tested |
| `DECLINE_REASON` | `decline_reason` | passthrough | |
| `SUBMITTED_AT` | `submitted_at` | passthrough | |
| `DECIDED_AT` | `decided_at` | passthrough | |
| *(derived)* | `has_clock_skew` | `decided_at < submitted_at` | flag only, not used downstream (A9) |

## RAW_LOANS → stg_loans → fct_loan_performance

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `LOAN_ID` | `loan_id` | passthrough | `loan_id` (PK) | unique/not_null tested |
| `APPLICATION_ID` | `application_id` | passthrough | `application_id` | relationships tested |
| `CUSTOMER_ID` | `customer_id` | passthrough | `customer_id` | |
| `PRODUCT_TYPE` | `product_type` | passthrough | `product_type` | segmentation cut in every mart |
| `PRINCIPAL_AMOUNT` | `principal_amount` | passthrough | `principal_amount`, `outstanding_balance_estimate` | |
| `CURRENCY` | `currency_code` | `upper(trim())` | `currency_code` | not normalized (A8) |
| `INTEREST_RATE_APR` | `interest_rate_apr` | passthrough | `interest_rate_apr` | |
| `TERM_MONTHS` | `term_months` | passthrough | `term_months` | |
| `LOAN_STATUS` | `loan_status` | `lower(trim())` | `loan_status` | drives active-book filter (A4); NOT used for delinquency (A2) |
| `ORIGINATED_AT` | `originated_at` | passthrough | `originated_at` | |
| `FIRST_DUE_DATE` | `current_schedule_first_due_date` | passthrough | carried for transparency | never used in DPD calc (A2) |
| `RESTRUCTURED_AT` | `restructured_at` | passthrough | `restructured_at`, drives `is_restructured` | |

## RAW_REPAYMENTS → stg_repayments → int_repayments_deduped → int_loan_delinquency → fct_loan_performance

| Source column | Staging column | Transform | Downstream | Notes |
|---|---|---|---|---|
| `REPAYMENT_ID` | `repayment_id` | passthrough | dedup key tiebreak | unique/not_null tested |
| `LOAN_ID` | `loan_id` | passthrough | joins to loans | relationships tested |
| `INSTALMENT_NO` | `instalment_no` | passthrough | dedup partition key | |
| `SCHEDULED_AMOUNT` | `scheduled_amount` | passthrough | `cumulative_scheduled_amount`, overpayment test | |
| `AMOUNT_PAID` | `amount_paid` | passthrough | `cumulative_amount_paid` → `outstanding_balance_estimate` | deduped first (A5) |
| `PAYMENT_STATUS` | `payment_status` | `lower(trim())` | `missed` rows drive `true_dpd` (A1); `partial` rows drive shortfall (A3) | accepted_values tested |
| `DUE_DATE` | `due_date` | passthrough | `oldest_missed_due_date` → `true_dpd` | the core delinquency signal |
| `PAID_AT` | `paid_at` | passthrough | dedup tiebreak (earliest wins) | null on `missed` rows |
| *(derived)* | — | `ROW_NUMBER()` dedup on `(loan_id, instalment_no)` for posted/partial | `is_duplicate_posting` | A5 |

## RAW_DEFAULTS → stg_defaults → int_loan_register_status → fct_loan_performance / fct_par_reconciliation_bridge

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `DEFAULT_ID` | `default_id` | passthrough | (aggregated away) | unique/not_null tested |
| `LOAN_ID` | `loan_id` | passthrough | `is_reported_defaulted` | relationships tested; defensively deduped in `int_loan_register_status` |
| `DEFAULT_REASON` | `default_reason` | passthrough | `most_recent_default_reason` | |
| `OUTSTANDING_AT_DEFAULT` | `outstanding_at_default` | passthrough | `outstanding_at_default` | Collections' own balance snapshot, kept for comparison — not used in our outstanding calc (A6) |
| `CURRENCY` | `currency_code` | `upper(trim())` | carried through | |
| `DEFAULT_STATUS` | `default_status` | `lower(trim())` | `most_recent_default_status` | accepted_values tested; ALL statuses count as "reported" (A7) |
| `FLAGGED_AT` | `flagged_at` | passthrough | `most_recent_flagged_at` | |

## Grain summary

| Layer | Model | Grain |
|---|---|---|
| staging | `stg_applications`/`stg_loans`/`stg_repayments`/`stg_defaults` | 1:1 with source table |
| intermediate | `int_repayments_deduped` | 1 row per repayment posting (dupes flagged, not dropped) |
| intermediate | `int_loan_delinquency` | 1 row per `loan_id` with any repayment activity |
| intermediate | `int_loan_register_status` | 1 row per `loan_id` in the register (defensively deduped) |
| marts | `fct_loan_performance` | 1 row per `loan_id` on the active book |
| marts | `fct_portfolio_metrics` | 1 row per `product_type`, plus 1 `'ALL'` row |
| marts | `fct_par_reconciliation_bridge` | 1 row per `product_type`, plus 1 `'ALL'` row |
