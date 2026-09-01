{{ config(materialized='table') }}

-- Grain: one row per department, plus one 'ALL' company-total row
-- (BRIEF.md deliverable #4). Transfers correctly REDUCE the source
-- department and INCREASE the destination — they are never counted as an
-- exit anywhere in this model. All flow metrics (transfers, exits) are
-- measured over the trailing attrition window for consistency with
-- fct_attrition_tenure_reconciliation_bridge.

with departments as (

    select * from {{ ref('stg_departments') }}

),

active_people as (

    select * from {{ ref('fct_workforce') }}
    where is_currently_active = true

),

records as (

    select * from {{ ref('int_employment_chain_classified') }}
    where hire_date <= cast('{{ var("as_of_date") }}' as date)

),

-- Transfers OUT: this record's own department, closed as 'transferred_out'
-- within the window — headcount leaving this department for another.
transfers_out as (

    select
        department_id,
        count(*) as transfer_out_count
    from records
    where resolved_state = 'transferred_out'
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)
    group by 1

),

-- Transfers IN: the successor record's new department, for successions
-- classified as a transfer, opening within the window — headcount arriving
-- in this department from another.
transfers_in as (

    select
        department_id,
        count(*) as transfer_in_count
    from records
    where is_transfer_successor = true
      and hire_date >= cast('{{ var("attrition_window_start") }}' as date)
      and hire_date <= cast('{{ var("as_of_date") }}' as date)
    group by 1

),

-- Genuine exits, attributed to the department the person was leaving FROM.
genuine_exits as (

    select
        department_id,
        count(*) as genuine_exit_count
    from records
    where resolved_state = 'terminated'
      and termination_date >= cast('{{ var("attrition_window_start") }}' as date)
      and termination_date <= cast('{{ var("as_of_date") }}' as date)
    group by 1

),

by_department as (

    select
        d.department_id,
        d.department_name,
        d.division,
        d.cost_center,

        count(ap.person_id)                                            as active_headcount,
        round(avg(ap.tenure_time_in_seat_years), 2)                     as avg_tenure_time_in_seat_years,

        coalesce(tin.transfer_in_count, 0)                              as transfers_in,
        coalesce(tout.transfer_out_count, 0)                            as transfers_out,
        coalesce(ge.genuine_exit_count, 0)                              as genuine_exits,

        div0(coalesce(ge.genuine_exit_count, 0), nullif(count(ap.person_id), 0)) as naive_department_attrition_rate

    from departments d
    left join active_people ap  on d.department_id = ap.current_department_id
    left join transfers_in tin  on d.department_id = tin.department_id
    left join transfers_out tout on d.department_id = tout.department_id
    left join genuine_exits ge  on d.department_id = ge.department_id
    group by 1, 2, 3, 4

),

total as (

    select
        null                                             as department_id,
        'ALL'                                              as department_name,
        'ALL'                                                as division,
        'ALL'                                                  as cost_center,
        sum(active_headcount)                                    as active_headcount,
        round(sum(avg_tenure_time_in_seat_years * active_headcount)
              / nullif(sum(active_headcount), 0), 2)                as avg_tenure_time_in_seat_years,
        sum(transfers_in)                                              as transfers_in,
        sum(transfers_out)                                              as transfers_out,
        sum(genuine_exits)                                               as genuine_exits,
        div0(sum(genuine_exits), nullif(sum(active_headcount), 0))       as naive_department_attrition_rate
    from by_department

)

select * from by_department
union all
select * from total
order by (department_name = 'ALL'), department_name
