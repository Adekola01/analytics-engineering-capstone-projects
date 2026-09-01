-- THE status-vs-date resolution model (BRIEF.md §3 Q5). A record's
-- EMPLOYMENT_STATUS and TERMINATION_DATE are set independently by the HRIS
-- and don't always agree. We resolve by making TERMINATION_DATE
-- authoritative for whether a record is OPEN — a null termination date
-- means the record is still open, full stop, regardless of what a lagging
-- status flag says. For CLOSED records (termination_date populated), the
-- status flag IS trustworthy for distinguishing a genuine exit from an
-- internal transfer (the injected status/date conflict only ever targets
-- open records — verified against the generator, not assumed).

with employees as (

    select * from {{ ref('int_employees_deduped') }}
    where is_duplicate_record = false

),

resolved as (

    select
        *,

        (termination_date is null)                                            as is_open,

        (termination_date is null and raw_employment_status = 'terminated')    as is_status_date_conflict,

        case
            when termination_date is null then 'open'
            when raw_employment_status = 'transferred' then 'transferred_out'
            when raw_employment_status = 'terminated' then 'terminated'
            -- Defensive catch-all: a closed record with an unclear status.
            -- Not produced by this generator, but a real HRIS could do this —
            -- treated as a genuine exit (conservative default for attrition
            -- counting) and flagged via a DQ test, never silently ignored.
            else 'terminated'
        end                                                                    as resolved_state

    from employees

)

select * from resolved
