-- ASSUMPTION (see assumptions_log.md A5): the front-desk booking UI
-- occasionally double-submits, writing a second row with a new
-- APPOINTMENT_ID but identical slot details (same patient, doctor,
-- scheduled_for). We treat this as a duplicate EVENT, not two visits.
--
-- IMPORTANT — this is also *why* the Data Lead doesn't trust the link
-- columns: when a genuine reschedule-origin row gets double-submitted, the
-- duplicate copy is written WITHOUT its forward link (RESCHEDULED_TO_ID),
-- making it look like an orphaned no-show/reschedule with nowhere to go.
-- The fix is sequencing: dedupe BEFORE resolving chains, and when two
-- candidate rows tie on slot details, keep the one that actually carries a
-- reschedule link over the one that doesn't — that's the real row.

with appointments as (

    select * from {{ ref('stg_appointments') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by patient_id, doctor_id, scheduled_for
            order by
                -- Prefer the row that carries a reschedule link (real row)
                -- over an orphaned duplicate that lost its link.
                case when rescheduled_to_id is not null or rescheduled_from_id is not null
                     then 0 else 1 end,
                appointment_id asc
        ) as dedup_rank
    from appointments

)

select
    appointment_id, patient_id, doctor_id, location, appointment_type,
    raw_status, scheduled_for, booked_at, checked_in_at, checkout_at,
    cancel_reason, rescheduled_to_id, rescheduled_from_id,
    (dedup_rank > 1) as is_duplicate_booking
from ranked
