{{ config(materialized='table') }}

-- Grain: one row per LOGICAL visit (reschedule chains collapsed to their
-- root — BRIEF.md deliverable #1). THE single mart Clinical Ops and
-- Revenue Cycle both pull their number from.
--
-- is_true_no_show is TRUE only when the chain's terminal outcome is a
-- genuine miss — a reschedule (at any hop count) or a cancellation is never
-- counted as a no-show, no matter what the raw front-desk status said.

with chains as (

    select * from {{ ref('int_appointment_chains') }}

),

root_detail as (

    select
        appointment_id      as logical_visit_id,
        patient_id,
        doctor_id            as originating_doctor_id,
        location              as originating_location,
        appointment_type,
        scheduled_for          as originally_scheduled_for,
        booked_at
    from {{ ref('int_appointments_canonical') }}
    where is_duplicate_booking = false

),

final_detail as (

    select
        appointment_id      as final_appointment_id,
        doctor_id            as final_doctor_id,
        location              as final_location,
        scheduled_for          as final_scheduled_for,
        checked_in_at,
        checkout_at,
        is_cancel_misflag,
        is_reschedule_misflag,
        is_naive_no_show,
        raw_status              as final_raw_status
    from {{ ref('int_appointments_canonical') }}
    where is_duplicate_booking = false

),

billing as (

    select * from {{ ref('int_billing_agg') }}

),

joined as (

    select
        c.logical_visit_id,
        c.final_appointment_id,
        c.final_canonical_status,
        c.reschedule_count,

        r.patient_id,
        r.originating_doctor_id,
        r.originating_location,
        r.appointment_type,
        r.originally_scheduled_for,
        r.booked_at,

        f.final_doctor_id,
        f.final_location,
        f.final_scheduled_for,
        f.checked_in_at,
        f.checkout_at,
        f.final_raw_status,

        b.has_office_visit_charge,
        b.has_no_show_fee_charge,
        b.has_late_cancel_fee_charge,
        b.office_visit_billed,
        b.no_show_fee_billed,
        b.late_cancel_fee_billed

    from chains c
    join root_detail  r on c.logical_visit_id = r.logical_visit_id
    join final_detail f on c.final_appointment_id = f.final_appointment_id
    left join billing b on c.final_appointment_id = b.appointment_id

),

final as (

    select
        *,

        (final_canonical_status = 'attended')      as is_attended,
        (final_canonical_status = 'no_show')        as is_true_no_show,
        (final_canonical_status = 'cancelled')      as is_cancelled,
        (final_canonical_status = 'unresolved')     as is_unresolved,
        (reschedule_count > 0)                      as was_rescheduled,

        -- The strict "kept-intent" denominator (assumptions_log.md A3):
        -- visits the patient meant to keep, i.e. not cancelled and not
        -- still-unresolved. Cancellations are a scheduling outcome, not an
        -- attendance one, and don't belong in a no-show rate's denominator.
        (final_canonical_status in ('attended', 'no_show'))   as is_kept_intent_visit

    from joined

)

select * from final
