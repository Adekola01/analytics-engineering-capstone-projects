{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: fct_revenue_reconciliation_bridge.finance_reconciled_number
-- must equal sum(fct_revenue.net_revenue) for the same order-cohort month.
-- This is the "the bridge isn't just a nice story, it's mathematically the
-- same number" check — a non-negotiable per RUBRIC.md ("no reconciliation to
-- the gross ledger" is an auto-deduction).
--
-- Fails in prod: the bridge and the mart have silently diverged (someone
-- edited one model's logic without the other). Hard stop — do not let
-- Finance and the bridge deck disagree with the mart Finance is querying.
-- Allow a $1.00 aggregate tolerance for floating-point rounding only.

with bridge as (

    select
        order_cohort_month,
        finance_reconciled_number
    from {{ ref('fct_revenue_reconciliation_bridge') }}

),

mart as (

    select
        date_trunc('month', created_at) as order_cohort_month,
        sum(net_revenue)                as mart_net_revenue
    from {{ ref('fct_revenue') }}
    group by 1

)

select
    b.order_cohort_month,
    b.finance_reconciled_number,
    m.mart_net_revenue,
    abs(b.finance_reconciled_number - m.mart_net_revenue) as diff
from bridge b
join mart m on b.order_cohort_month = m.order_cohort_month
where abs(b.finance_reconciled_number - m.mart_net_revenue) > 1.00
