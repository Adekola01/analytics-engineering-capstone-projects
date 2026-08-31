# Source-to-Target Mapping — Engagement 05

## RAW_PATIENTS → stg_patients

| Source column | Staging column | Transform | Notes |
|---|---|---|---|
| `PATIENT_ID` | `patient_id` | passthrough | unique/not_null tested |
| `BIRTH_YEAR` | `birth_year` | passthrough | |
| `SEX` | `sex` | `upper(trim())` | accepted_values tested |
| `INSURANCE_PLAN` | `insurance_plan` | `lower(trim())` | |
| `HOME_LOCATION` | `home_location` | `lower(trim())` | |
| `REGISTERED_AT` | `registered_at` | passthrough | |

## RAW_DOCTORS → stg_doctors

| Source column | Staging column | Transform | Notes |
|---|---|---|---|
| `DOCTOR_ID` | `doctor_id` | passthrough | unique/not_null tested |
| `PROVIDER_NAME` | `provider_name` | passthrough | |
| `SPECIALTY` | `specialty` | `lower(trim())` | |
| `PRIMARY_LOCATION` | `primary_location` | `lower(trim())` | |
| `HIRED_AT` | `hired_at` | passthrough | |
| `IS_ACTIVE` | `is_active` | passthrough | |

## RAW_APPOINTMENTS → stg_appointments → int_appointments_deduped → int_appointments_canonical → int_appointment_chains → fct_appointments

| Source column | Staging column | Transform | Downstream | Notes |
|---|---|---|---|---|
| `APPOINTMENT_ID` | `appointment_id` | passthrough | dedup key, chain key | unique/not_null tested |
| `PATIENT_ID` | `patient_id` | passthrough | `fct_appointments.patient_id` | relationships tested |
| `DOCTOR_ID` | `doctor_id` | passthrough | `originating_doctor_id`/`final_doctor_id` | relationships tested |
| `LOCATION` | `location` | `lower(trim())` | `originating_location`/`final_location`, bridge grouping | |
| `APPOINTMENT_TYPE` | `appointment_type` | `lower(trim())` | `fct_appointments.appointment_type` | |
| `STATUS` | `raw_status` | `lower(trim())`, synonyms NOT collapsed | canonicalized in `int_appointments_canonical` (A4) | accepted_values tested at staging |
| `SCHEDULED_FOR` | `scheduled_for` | passthrough | `originally_scheduled_for` (root) / `final_scheduled_for` (terminal) | |
| `BOOKED_AT` | `booked_at` | passthrough | `fct_appointments.booked_at` | |
| `CHECKED_IN_AT` | `checked_in_at` | passthrough (nulls preserved) | `fct_appointments.checked_in_at` | not used in canonicalization (A7) |
| `CHECKOUT_AT` | `checkout_at` | passthrough | `fct_appointments.checkout_at` | |
| `CANCEL_REASON` | `cancel_reason` | `lower(trim())` | drives `canonical_status = 'cancelled'` override (A4) | |
| `RESCHEDULED_TO_ID` | `rescheduled_to_id` | passthrough | validated in `int_appointments_canonical`, walked in `int_appointment_chains` | A4, A5 |
| `RESCHEDULED_FROM_ID` | `rescheduled_from_id` | passthrough | root-detection in `int_appointment_chains` | |
| *(derived)* | — | dedup on `(patient_id, doctor_id, scheduled_for)` | `is_duplicate_booking` | A5 |
| *(derived)* | — | priority logic | `canonical_status`, `is_reschedule_misflag`, `is_cancel_misflag`, `is_naive_no_show` | A1, A4 |
| *(derived)* | — | recursive chain walk | `logical_visit_id`, `final_appointment_id`, `reschedule_count` | A3 |

## RAW_BILLING → stg_billing → int_billing_agg → fct_appointments

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `BILLING_ID` | `billing_id` | passthrough | (aggregated away) | unique/not_null tested |
| `APPOINTMENT_ID` | `appointment_id` | passthrough | joins to appointments | not_null tested; unmatched/orphaned billing flagged, not dropped |
| `PATIENT_ID` | `patient_id` | passthrough | not carried into billing agg (redundant with appointment join) | |
| `LINE_TYPE` | `line_type` | `lower(trim())` | `has_office_visit_charge` / `has_no_show_fee_charge` / `has_late_cancel_fee_charge` | accepted_values tested; never drives canonical status (A6) |
| `BILLED_AMOUNT` | `billed_amount` | passthrough | `office_visit_billed` / `no_show_fee_billed` / `late_cancel_fee_billed` | |
| `INSURANCE_COVERED` | `insurance_covered` | passthrough | not currently in marts | |
| `PATIENT_RESPONSIBILITY` | `patient_responsibility` | passthrough | not currently in marts | |
| `SERVICE_AT` | `service_at` | passthrough | `int_billing_agg.service_at` | |
| `POSTED_AT` | `posted_at` | passthrough | `int_billing_agg.last_posted_at` | cross-month lag not modeled further (A6) |

## Grain summary

| Layer | Model | Grain |
|---|---|---|
| staging | `stg_patients`/`stg_doctors`/`stg_appointments`/`stg_billing` | 1:1 with source table |
| intermediate | `int_appointments_deduped` | 1 row per raw appointment (dupes flagged, not dropped) |
| intermediate | `int_appointments_canonical` | 1 row per raw appointment, canonical status applied |
| intermediate | `int_appointment_chains` | 1 row per logical visit (root), pre-detail-join |
| intermediate | `int_billing_agg` | 1 row per surviving `appointment_id` with any billing activity |
| marts | `fct_appointments` | 1 row per logical visit (reschedule chain collapsed) |
| marts | `fct_patient_engagement` | 1 row per `patient_id` |
| marts | `fct_noshow_reconciliation_bridge` | 1 row per `location`, plus 1 `'ALL'` row |
