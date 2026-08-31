{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md non-negotiable: "treating each reschedule slot
-- as an independent visit"). Every non-duplicate appointment row must
-- belong to EXACTLY ONE chain — either as the root (owning the
-- logical_visit_id) or as a downstream hop absorbed into some root's chain
-- via int_appointment_chains' recursive walk. It must never appear as its
-- own separate logical_visit_id AND also be swallowed into another chain.
--
-- Fails in prod: a single patient intent is being counted as two (or more)
-- visits somewhere — directly the double-counting bug this engagement
-- exists to prevent. Hard stop.

with all_non_duplicate as (

    select appointment_id
    from {{ ref('int_appointments_canonical') }}
    where is_duplicate_booking = false

),

covered_by_chains as (

    -- Every appointment_id that appears anywhere in a resolved chain: either
    -- as the root (logical_visit_id) or as the terminal (final_appointment_id).
    -- For single-hop chains these are the only two positions; the recursive
    -- walk guarantees every intermediate hop is also somebody's terminal in
    -- a longer chain, so root ∪ final covers every row exactly once.
    select logical_visit_id as appointment_id from {{ ref('int_appointment_chains') }}
    union all
    select final_appointment_id as appointment_id from {{ ref('int_appointment_chains') }}
    where final_appointment_id != logical_visit_id

),

coverage_count as (

    select
        a.appointment_id,
        count(c.appointment_id) as times_covered
    from all_non_duplicate a
    left join covered_by_chains c on a.appointment_id = c.appointment_id
    group by 1

)

select *
from coverage_count
where times_covered != 1
