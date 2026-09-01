-- THE person-stitching model (BRIEF.md deliverable #1). Collapses every
-- person's employment records (transfers + rehires) into one row, computing
-- all three tenure definitions side by side (assumptions_log.md A3) so the
-- mart layer never has to choose blind.

with records as (

    select * from {{ ref('int_employment_chain_classified') }}

),

latest_record as (

    select *
    from records
    qualify row_number() over (partition by person_id order by hire_date desc) = 1

),

person_agg as (

    select
        person_id,
        min(hire_date)                                       as first_ever_hire_date,
        count(*)                                              as employment_record_count,
        sum(record_span_days)                                 as total_time_in_seat_days,
        bool_or(is_transfer_successor)                        as had_transfer,
        bool_or(is_rehire_successor)                          as had_rehire,
        max(case when resolved_state = 'terminated'
                 then termination_date end)                   as most_recent_genuine_termination_date
        -- (most-recent genuine termination is refined against the actual
        -- latest record below — this MAX is a safe upper bound used only
        -- as a fallback if the latest record itself isn't 'terminated'.)
    from records
    group by 1

)

select
    p.person_id,
    p.first_ever_hire_date,
    p.employment_record_count,
    p.total_time_in_seat_days,
    p.had_transfer,
    p.had_rehire,

    l.employee_id           as current_employee_id,
    l.department_id         as current_department_id,
    l.job_level              as current_job_level,
    l.employment_type        as current_employment_type,
    l.location                as current_location,
    l.hire_date                as most_recent_hire_date,
    l.termination_date          as most_recent_termination_date,
    l.resolved_state              as latest_record_state,
    l.record_span_days              as current_stint_span_days,

    (l.resolved_state = 'open')       as is_currently_active,

    -- A latest record that is 'transferred_out' with no successor found is
    -- a genuine anomaly (a dangling transfer) — should be ~0 rows; caught
    -- by a business-rule test rather than assumed away.
    (l.resolved_state = 'transferred_out') as has_dangling_transfer,

    case
        when l.resolved_state = 'open' then cast('{{ var("as_of_date") }}' as date)
        when l.resolved_state = 'terminated' then l.termination_date
        else p.most_recent_genuine_termination_date  -- dangling-transfer fallback
    end                                              as tenure_reference_end_date,

    datediff(
        'day',
        p.first_ever_hire_date,
        case
            when l.resolved_state = 'open' then cast('{{ var("as_of_date") }}' as date)
            when l.resolved_state = 'terminated' then l.termination_date
            else p.most_recent_genuine_termination_date
        end
    )                                                as tenure_since_first_hire_days

from person_agg p
join latest_record l on p.person_id = l.person_id
