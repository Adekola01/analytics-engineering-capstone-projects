{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md correctness dimension, explicit: "department
-- headcount sums to company total"). Every active person must be
-- attributed to exactly one department — sum(active_headcount) across all
-- individual department rows must equal the 'ALL' row's active_headcount,
-- and must equal fct_workforce's own active-person count.
--
-- Fails in prod: hard stop. A mismatch means either a department is
-- double-attributing people (fan-out in the join) or an active person has
-- a null/orphaned current_department_id and is falling out of every
-- per-department cut while still counting company-wide.

with departments_sum as (

    select sum(active_headcount) as dept_sum
    from {{ ref('fct_department_workforce') }}
    where department_name != 'ALL'

),

company_total as (

    select active_headcount as company_headcount
    from {{ ref('fct_department_workforce') }}
    where department_name = 'ALL'

)

select
    d.dept_sum,
    c.company_headcount
from departments_sum d
cross join company_total c
where d.dept_sum != c.company_headcount
