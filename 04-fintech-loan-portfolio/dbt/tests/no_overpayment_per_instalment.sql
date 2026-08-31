{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: a single non-duplicate posting against an instalment can
-- never exceed that instalment's scheduled amount. If this fails, either the
-- servicer posted an overpayment we need a policy for (rare, real-world
-- possible via fees/rounding) or our dedup logic in int_repayments_deduped
-- is wrong and is summing rows it should have excluded.
--
-- Fails in prod: hard stop. Overstated payments understate outstanding
-- balance and can wrongly clear a delinquent instalment, hiding risk in the
-- exact direction this engagement exists to prevent.

select
    loan_id,
    instalment_no,
    scheduled_amount,
    amount_paid
from {{ ref('int_repayments_deduped') }}
where is_duplicate_posting = false
  and payment_status in ('posted', 'partial')
  and amount_paid > scheduled_amount * 1.01   -- 1% tolerance for rounding
