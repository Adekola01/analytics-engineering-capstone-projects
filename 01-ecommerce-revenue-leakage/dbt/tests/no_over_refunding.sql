{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: total refunds against any single payment can never exceed
-- the amount that was actually settled on that payment. If this fails, the
-- refund ledger is internally inconsistent (a source-system bug, not a
-- modeling artifact) and net_revenue can no longer be trusted.
--
-- Fails in prod: pipeline run is marked failed, marts are NOT swapped
-- (dbt build stops before marts materialize), and Finance is alerted before
-- the board sees a wrong number. See docs/data_quality_framework.md.

select
    r.payment_id,
    p.amount            as payment_amount,
    sum(r.refund_amount) as total_refunded
from {{ ref('stg_refunds') }} r
join {{ ref('stg_payments') }} p on r.payment_id = p.payment_id
group by 1, 2
having sum(r.refund_amount) > p.amount
