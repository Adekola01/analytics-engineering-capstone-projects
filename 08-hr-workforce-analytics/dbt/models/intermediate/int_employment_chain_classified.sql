-- THE internal-movement classifier (BRIEF.md §3 Q2/Q3). For every record
-- that succeeds another (PRIOR_EMPLOYEE_ID is not null), determines whether
-- that succession was a TRANSFER (prior record's resolved_state =
-- 'transferred_out' — zero gap, an internal move) or a REHIRE (prior
-- record's resolved_state = 'terminated' — a genuine gap, the person left
-- and came back). This distinction is the single choice that drives most
-- of the attrition and tenure spread (assumptions_log.md A2).

with records as (

    select * from {{ ref('int_employment_records_resolved') }}

),

with_prior as (

    select
        r.*,
        p.resolved_state    as prior_resolved_state,
        p.termination_date  as prior_termination_date
    from records r
    left join records p on r.prior_employee_id = p.employee_id

),

classified as (

    select
        *,

        (prior_employee_id is not null and prior_resolved_state = 'transferred_out') as is_transfer_successor,
        (prior_employee_id is not null and prior_resolved_state = 'terminated')       as is_rehire_successor,

        case
            when prior_employee_id is not null and prior_resolved_state = 'terminated'
            then datediff('day', prior_termination_date, hire_date)
            else 0
        end                                                                            as gap_days_before,

        -- This record's own active span, in days, for time-in-seat summation.
        datediff('day', hire_date, coalesce(termination_date, cast('{{ var("as_of_date") }}' as date))) as record_span_days

    from with_prior

)

select * from classified
