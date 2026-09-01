-- ASSUMPTION (see assumptions_log.md A6): the 2021 HRIS migration
-- double-loaded a slice of employment records under a fresh EMPLOYEE_ID with
-- identical person/department/hire/termination details. We treat this as a
-- duplicate RECORD, not a second employment episode. Keep the earliest
-- EMPLOYEE_ID per (person_id, department_id, hire_date, termination_date),
-- flag the dropped duplicate — never delete it — and exclude it from every
-- downstream headcount, tenure, and attrition calculation.

with employees as (

    select * from {{ ref('stg_employees') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by person_id, department_id, hire_date, termination_date
            order by employee_id asc
        ) as dedup_rank
    from employees

)

select
    employee_id, person_id, full_name, department_id, job_level,
    employment_type, location, hire_date, termination_date,
    raw_employment_status, prior_employee_id,
    (dedup_rank > 1) as is_duplicate_record
from ranked
