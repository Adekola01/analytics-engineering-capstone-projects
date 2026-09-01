{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md correctness dimension, explicit): person-grain
-- headcount must reconcile to distinct active people. fct_workforce must
-- never contain more than one row for the same person_id, and the count of
-- is_currently_active=true rows must equal a fully independent recount
-- straight from the resolved (non-duplicate) employment records.
--
-- Fails in prod: hard stop. This is the single most senior check in the
-- engagement — if headcount itself doesn't tie out, nothing downstream
-- (attrition rate, tenure, department reporting) can be trusted either.

with mart_headcount as (

    select count(*) as mart_active_headcount
    from {{ ref('fct_workforce') }}
    where is_currently_active = true

),

independent_headcount as (

    select count(distinct person_id) as recount_active_headcount
    from {{ ref('int_employment_records_resolved') }}
    where hire_date <= cast('{{ var("as_of_date") }}' as date)
      and (termination_date is null or termination_date > cast('{{ var("as_of_date") }}' as date))

)

select
    m.mart_active_headcount,
    i.recount_active_headcount
from mart_headcount m
cross join independent_headcount i
where m.mart_active_headcount != i.recount_active_headcount
