-- ASSUMPTION (see assumptions_log.md A7): a cancelled-and-reissued payroll
-- run produces a duplicate PAY_PERIOD row for the same employee. Dedupe to
-- the earliest PAYROLL_ID per (employee_id, pay_period), flag the dropped
-- duplicate, never delete it.
--
-- Separately: payroll was generated against EVERY employment record,
-- including the ones int_employees_deduped later drops as duplicate
-- records (the 2021 migration double-load). Payroll tied to a deduped-away
-- employee_id is flagged (is_orphaned_payroll), not silently dropped, and
-- excluded from cost totals downstream — otherwise a duplicated employment
-- record would double a real person's payroll cost.

with payroll as (

    select * from {{ ref('stg_payroll') }}

),

employees as (

    select employee_id, is_duplicate_record
    from {{ ref('int_employees_deduped') }}

),

ranked as (

    select
        p.*,
        row_number() over (
            partition by p.employee_id, p.pay_period
            order by p.payroll_id asc
        )                                               as dedup_rank,
        coalesce(e.is_duplicate_record, true)            as is_orphaned_payroll   -- true if employee_id not found at all, or found as a dropped duplicate
    from payroll p
    left join employees e on p.employee_id = e.employee_id

)

select
    payroll_id, employee_id, person_id, pay_period, gross_pay, currency_code,
    is_partial_period, paid_at,
    (dedup_rank > 1)      as is_duplicate_period,
    is_orphaned_payroll
from ranked
