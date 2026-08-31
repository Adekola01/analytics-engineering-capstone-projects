-- THE canonicalization model (BRIEF.md §3 Q1, Q4). Applies one priority
-- order to resolve the raw STATUS mess into a single canonical status per
-- row, using the more-trustworthy structured signals (CANCEL_REASON,
-- a validated reschedule link) to OVERRIDE a misflagged raw status rather
-- than take it at face value.
--
-- Priority (see assumptions_log.md A1/A2 for the full defense):
--   1. CANCEL_REASON populated              -> 'cancelled'   (overrides a
--      no_show/missed misflag — the front desk hit the empty-chair button
--      instead of properly closing out the cancel)
--   2. A validated forward reschedule link  -> 'rescheduled' (overrides a
--      no_show/missed misflag the same way)
--   3. Otherwise, the raw status is grouped into its canonical synonym set.
--
-- Only non-duplicate rows are canonicalized as visits; duplicate rows are
-- passed through with their own canonical_status too (needed for the naive
-- ops-dashboard count in the reconciliation bridge, which counts them).

with appointments as (

    select * from {{ ref('int_appointments_deduped') }}

),

-- A reschedule link only counts if it actually points at a surviving,
-- non-duplicate row. If it doesn't, the row still says "no_show" and we
-- treat that as an unresolved data-quality issue, not a silent reclassification.
valid_targets as (

    select appointment_id
    from appointments
    where is_duplicate_booking = false

),

with_link_validation as (

    select
        a.*,
        (a.rescheduled_to_id is not null
            and t.appointment_id is not null)              as has_validated_reschedule_link,
        (a.rescheduled_to_id is not null
            and t.appointment_id is null)                   as has_orphaned_reschedule_link
    from appointments a
    left join valid_targets t on a.rescheduled_to_id = t.appointment_id

),

canonical as (

    select
        *,

        case
            when cancel_reason is not null then 'cancelled'
            when has_validated_reschedule_link then 'rescheduled'
            when raw_status in ('no_show', 'missed', 'no-show') then 'no_show'
            when raw_status = 'attended' then 'attended'
            when raw_status = 'cancelled' then 'cancelled'
            when raw_status = 'rescheduled' and has_orphaned_reschedule_link then 'unresolved'  -- flagged, not silently dropped
            when raw_status = 'rescheduled' then 'rescheduled'   -- no link at all recorded; treat status literally, flag via DQ test
            else 'unresolved'
        end                                                  as canonical_status,

        -- The two misflag populations the reconciliation bridge quantifies.
        (cancel_reason is not null
            and raw_status in ('no_show', 'missed', 'no-show'))       as is_cancel_misflag,
        (has_validated_reschedule_link
            and raw_status in ('no_show', 'missed', 'no-show'))       as is_reschedule_misflag,

        (raw_status in ('no_show', 'missed', 'no-show'))              as is_naive_no_show   -- the "ops dashboard" definition

    from with_link_validation

)

select * from canonical
