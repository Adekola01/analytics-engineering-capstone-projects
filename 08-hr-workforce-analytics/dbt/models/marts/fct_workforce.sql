{{ config(materialized='table') }}

-- Grain: one row per PERSON_ID (BRIEF.md deliverable #1, RUBRIC.md's
-- required person-grain choice). THE single mart both Talent and Finance
-- pull their number from.
--
-- Three tenure definitions, side by side, never silently collapsed to one
-- (assumptions_log.md A3):
--   * tenure_time_in_seat_days  -> RECOMMENDED. Sum of every record's own
--     active span. Continuous across a transfer (zero gap by construction),
--     excludes a rehire gap entirely. Answers "how much has this person
--     actually worked here."
--   * tenure_since_first_hire_days -> Talent's naive claim. Calendar span
--     from first-ever hire to now/exit — INCLUDES any rehire gap as if the
--     person had been employed the whole time.
--   * current_stint_span_days -> Finance's naive claim. Just the latest
--     record's own span — resets to zero on EITHER a transfer or a rehire.

with summary as (

    select * from {{ ref('int_person_employment_summary') }}

),

departments as (

    select * from {{ ref('stg_departments') }}

),

final as (

    select
        s.person_id,
        s.first_ever_hire_date,
        s.most_recent_hire_date,
        s.most_recent_termination_date,
        s.employment_record_count,
        s.is_currently_active,
        s.has_dangling_transfer,
        s.had_transfer,
        s.had_rehire,

        s.current_department_id,
        d.department_name,
        d.division,
        d.cost_center,
        s.current_job_level,
        s.current_employment_type,
        s.current_location,

        s.total_time_in_seat_days                                  as tenure_time_in_seat_days,
        round(s.total_time_in_seat_days / 365.25, 2)                as tenure_time_in_seat_years,

        s.tenure_since_first_hire_days,
        round(s.tenure_since_first_hire_days / 365.25, 2)           as tenure_since_first_hire_years,

        s.current_stint_span_days,
        round(s.current_stint_span_days / 365.25, 2)                as current_stint_span_years,

        -- The gap in days a rehire's tenure_since_first_hire overstates
        -- relative to actual time-in-seat — the direct rebuttal to
        -- Finance's "we'd be paying them for years they weren't here"
        -- objection: we don't; this column proves it's excluded.
        (s.tenure_since_first_hire_days - s.total_time_in_seat_days) as rehire_gap_days_excluded

    from summary s
    left join departments d on s.current_department_id = d.department_id

)

select * from final
