{{ config(materialized='table') }}

-- THE deliverable for this engagement (BRIEF.md #3, RUBRIC.md 20% weight).
-- Walks from the "ops dashboard" naive no-show count (every row whose raw
-- STATUS says no_show/missed/no-show, exactly what a straight
-- `count(*) where status in (...)` query would return) down to the
-- ledger-true no-show count, naming every row population removed along the
-- way. One row per location, plus one 'ALL' row.
--
-- The walk:
--   1. naive_no_show_count       = every row flagged no_show/missed/no-show
--                                   in the raw feed, duplicates included —
--                                   this is exactly the ~22% number.
--   2. − duplicate_no_show_rows  = double-submitted booking rows that
--                                   happened to carry a no-show flag.
--   3. − reschedule_misflags     = rows with a validated forward reschedule
--                                   link that the front desk still closed
--                                   out as no_show/missed instead of
--                                   properly marking "rescheduled".
--   4. − cancel_misflags         = rows with a CANCEL_REASON populated
--                                   (a real cancellation) that the front
--                                   desk closed out as no_show/missed.
--   = true_no_show_count (ties exactly to fct_appointments.is_true_no_show)

with canonical as (

    select * from {{ ref('int_appointments_canonical') }}

),

visits as (

    select * from {{ ref('fct_appointments') }}

),

naive_by_location as (

    select
        originating_location as location,
        count(*)                                                        as naive_all_rows,
        count(case when is_naive_no_show then 1 end)                     as naive_no_show_count,
        count(case when is_duplicate_booking and is_naive_no_show
                        then 1 end)                                      as duplicate_no_show_rows,
        count(case when not is_duplicate_booking and is_reschedule_misflag
                        then 1 end)                                      as reschedule_misflags,
        count(case when not is_duplicate_booking and is_cancel_misflag
                        then 1 end)                                      as cancel_misflags,
        count(case when not is_duplicate_booking and canonical_status = 'no_show'
                        then 1 end)                                      as true_no_show_count_from_rows
    from canonical
    -- location comes from the row itself (pre-collapse); a duplicate/target
    -- row always shares its origin's location in this data, so this is a
    -- safe grouping key even before chain resolution.
    group by 1

),

true_by_location as (

    select
        originating_location as location,
        count(*)                                                        as total_logical_visits,
        count(case when is_kept_intent_visit then 1 end)                 as kept_intent_visit_count,
        count(case when is_true_no_show then 1 end)                      as true_no_show_count
    from visits
    group by 1

),

by_location as (

    select
        n.location,
        n.naive_all_rows,
        n.naive_no_show_count,
        div0(n.naive_no_show_count, nullif(n.naive_all_rows, 0))          as naive_no_show_rate,

        n.duplicate_no_show_rows,
        n.reschedule_misflags,
        n.cancel_misflags,

        n.naive_no_show_count
            - n.duplicate_no_show_rows
            - n.reschedule_misflags
            - n.cancel_misflags                                          as bridged_true_no_show_count,

        t.true_no_show_count,
        t.kept_intent_visit_count,
        div0(t.true_no_show_count, nullif(t.kept_intent_visit_count, 0)) as true_no_show_rate

    from naive_by_location n
    join true_by_location t on n.location = t.location

),

total as (

    select
        'ALL' as location,
        sum(naive_all_rows)                as naive_all_rows,
        sum(naive_no_show_count)            as naive_no_show_count,
        div0(sum(naive_no_show_count), nullif(sum(naive_all_rows), 0))     as naive_no_show_rate,
        sum(duplicate_no_show_rows)         as duplicate_no_show_rows,
        sum(reschedule_misflags)            as reschedule_misflags,
        sum(cancel_misflags)                as cancel_misflags,
        sum(bridged_true_no_show_count)     as bridged_true_no_show_count,
        sum(true_no_show_count)             as true_no_show_count,
        sum(kept_intent_visit_count)        as kept_intent_visit_count,
        div0(sum(true_no_show_count), nullif(sum(kept_intent_visit_count), 0)) as true_no_show_rate
    from by_location

)

select * from by_location
union all
select * from total
order by (location = 'ALL'), location
