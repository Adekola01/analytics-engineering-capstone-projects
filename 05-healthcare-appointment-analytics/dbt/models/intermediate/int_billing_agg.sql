-- Billing is a CORROBORATING signal only (see assumptions_log.md A6 — the
-- Director of Revenue Cycle's explicit warning: "billing tells you about
-- money, not attendance"). This model aggregates billing lines per
-- surviving (non-duplicate) appointment_id; it does not drive canonical
-- status anywhere.
--
-- Billing was generated against ALL appointment rows, including the ones
-- int_appointments_deduped later drops as duplicate bookings — so a small
-- number of billing lines reference an appointment_id that no longer exists
-- as a "real" visit. We flag these (is_orphaned_billing) rather than
-- silently dropping them; they're excluded from the appointment-grain join
-- downstream but remain queryable here for revenue-cycle's own reconciliation.

with billing as (

    select * from {{ ref('stg_billing') }}

),

appointments as (

    select appointment_id, is_duplicate_booking
    from {{ ref('int_appointments_deduped') }}

),

flagged as (

    select
        b.*,
        (a.appointment_id is null)                         as is_unmatched_billing,
        coalesce(a.is_duplicate_booking, false)             as is_orphaned_billing   -- billed to a row later deduped away
    from billing b
    left join appointments a on b.appointment_id = a.appointment_id

),

per_appointment as (

    select
        appointment_id,
        sum(case when line_type = 'office_visit' then billed_amount else 0 end)   as office_visit_billed,
        sum(case when line_type = 'no_show_fee' then billed_amount else 0 end)    as no_show_fee_billed,
        sum(case when line_type = 'late_cancel_fee' then billed_amount else 0 end) as late_cancel_fee_billed,
        max(case when line_type = 'office_visit' then true else false end)        as has_office_visit_charge,
        max(case when line_type = 'no_show_fee' then true else false end)         as has_no_show_fee_charge,
        max(case when line_type = 'late_cancel_fee' then true else false end)     as has_late_cancel_fee_charge,
        min(service_at)                                                            as service_at,
        max(posted_at)                                                             as last_posted_at
    from flagged
    where is_unmatched_billing = false
      and is_orphaned_billing = false
    group by 1

)

select * from per_appointment
