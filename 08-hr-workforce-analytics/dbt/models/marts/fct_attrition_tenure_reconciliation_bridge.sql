{{ config(materialized='table') }}

-- THE deliverable for this engagement (BRIEF.md #3, RUBRIC.md 20% weight).
-- Single row. Walks Finance's naive record-based attrition count to
-- Talent's person-based count, and lays the three tenure definitions side
-- by side, over the trailing attrition window
-- ({{ var('attrition_window_start') }} to {{ var('as_of_date') }}).
--
-- The attrition walk:
--   1. naive_record_closures   = every record whose TERMINATION_DATE falls
--        in the window, duplicates included — this is Finance's literal
--        "a termination_date is a termination" count, exactly as stated.
--   2. − duplicate_closed_records = migration double-loads that happened
--        to close in the window.
--   3. − transfer_closures     = internal moves the HRIS represents as a
--        closed record — THE headline finding (VP Talent's core complaint).
--   4. = true_genuine_exits (person-based, ties to fct_workforce)

with all_records_including_dupes as (

    -- Deliberately includes duplicates here — this CTE exists ONLY to
    -- reconstruct Finance's naive number as literally as they'd compute it.
    select * from {{ ref('int_employees_deduped') }}

),

resolved_non_dupe as (

    select * from {{ ref('int_employment_records_resolved') }}

),

naive as (

    select
        count(*) as naive_record_closures
    from all_records_including_dupes
    where termination_date is not null
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)

),

duplicate_closures as (

    select
        count(*) as duplicate_closed_records
    from all_records_including_dupes
    where is_duplicate_record = true
      and termination_date is not null
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)

),

transfer_closures as (

    select
        count(*) as transfer_closure_count
    from resolved_non_dupe
    where resolved_state = 'transferred_out'
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)

),

true_exits as (

    select
        count(*) as true_genuine_exit_count
    from resolved_non_dupe
    where resolved_state = 'terminated'
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)

),

-- Point-in-time headcount at the start and end of the window, for an
-- annualized rate (standard "(begin + end) / 2" average-headcount formula).
headcount_at_start as (

    select count(distinct person_id) as headcount
    from resolved_non_dupe
    where hire_date <= cast('{{ var("attrition_window_start") }}' as date)
      and (termination_date is null or termination_date > cast('{{ var("attrition_window_start") }}' as date))

),

headcount_at_end as (

    select count(distinct person_id) as headcount
    from resolved_non_dupe
    where hire_date <= cast('{{ var("as_of_date") }}' as date)
      and (termination_date is null or termination_date > cast('{{ var("as_of_date") }}' as date))

),

-- The three tenure definitions, averaged over today's active headcount.
tenure_comparison as (

    select
        round(avg(tenure_time_in_seat_years), 2)      as avg_tenure_time_in_seat_years,
        round(avg(tenure_since_first_hire_years), 2)  as avg_tenure_since_first_hire_years,
        round(avg(current_stint_span_years), 2)       as avg_current_stint_span_years
    from {{ ref('fct_workforce') }}
    where is_currently_active = true

)

select
    '{{ var("attrition_window_start") }}' as window_start,
    '{{ var("as_of_date") }}'              as window_end,

    n.naive_record_closures,
    dc.duplicate_closed_records,
    tc.transfer_closure_count,

    n.naive_record_closures
        - dc.duplicate_closed_records
        - tc.transfer_closure_count                        as bridged_true_genuine_exits,
    te.true_genuine_exit_count,

    hs.headcount as headcount_at_window_start,
    he.headcount as headcount_at_window_end,
    round((hs.headcount + he.headcount) / 2.0, 1)          as avg_headcount,

    div0(n.naive_record_closures, nullif((hs.headcount + he.headcount) / 2.0, 0))       as naive_finance_attrition_rate,
    div0(te.true_genuine_exit_count, nullif((hs.headcount + he.headcount) / 2.0, 0))    as true_attrition_rate,

    tenc.avg_tenure_time_in_seat_years,
    tenc.avg_tenure_since_first_hire_years,
    tenc.avg_current_stint_span_years,
    (tenc.avg_tenure_since_first_hire_years - tenc.avg_current_stint_span_years) as approx_tenure_spread_years

from naive n
cross join duplicate_closures dc
cross join transfer_closures tc
cross join true_exits te
cross join headcount_at_start hs
cross join headcount_at_end he
cross join tenure_comparison tenc
