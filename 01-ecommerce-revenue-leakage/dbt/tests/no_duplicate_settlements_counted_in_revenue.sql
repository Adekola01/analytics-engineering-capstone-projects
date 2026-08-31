{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: exactly one non-duplicate succeeded payment per order may
-- feed revenue. This is the direct check on the "duplicate payment" leg of
-- the reconciliation bridge — if this ever returns rows, gross_revenue in
-- fct_revenue is silently inflated by gateway double-logs.
--
-- Fails in prod: treated the same as no_over_refunding — hard stop, marts
-- not swapped, on-call analytics engineer paged (this is a correctness bug
-- in int_payments_deduped, not a data issue to route to the source team).

select
    order_id,
    count(*) as non_duplicate_succeeded_payments
from {{ ref('int_payments_deduped') }}
where payment_status = 'succeeded'
  and is_duplicate_settlement = false
group by 1
having count(*) > 1
