{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: at most one non-duplicate posted/partial row per
-- (loan_id, instalment_no) may feed cumulative_amount_paid. This is the
-- direct check on int_repayments_deduped's correctness — if it ever returns
-- rows, a loan's outstanding balance is understated and its true_dpd could
-- be wrongly cleared by double-counted cash.
--
-- Fails in prod: hard stop, same posture as no_overpayment_per_instalment —
-- this is a bug in OUR dedup logic, not a source-data issue, so it pages the
-- on-call analytics engineer directly rather than routing to the servicer.

select
    loan_id,
    instalment_no,
    count(*) as non_duplicate_postings
from {{ ref('int_repayments_deduped') }}
where is_duplicate_posting = false
  and payment_status in ('posted', 'partial')
group by 1, 2
having count(*) > 1
