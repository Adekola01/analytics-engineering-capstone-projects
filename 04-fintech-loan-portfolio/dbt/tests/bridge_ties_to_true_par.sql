{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: fct_par_reconciliation_bridge's bridged_par30_loans and
-- bridged_par90_loans (reported + hidden_restructure_risk +
-- unregistered_delinquents - stale_register_entries) must equal
-- true_par30_loans / true_par90_loans EXACTLY, for every product_type row.
-- This is the "the bridge isn't just a nice story, it's mathematically the
-- same number" check — non-negotiable per RUBRIC.md ("a PAR number with no
-- reconciliation to the default register" is an auto-deduction).
--
-- Fails in prod: the bridge and the ledger-true PAR have silently diverged —
-- never let the CRO's board deck (built from the bridge) disagree with the
-- number Credit Risk queries directly from fct_loan_performance. Hard stop.

select
    product_type,
    bridged_par30_loans,
    true_par30_loans,
    bridged_par90_loans,
    true_par90_loans
from {{ ref('fct_par_reconciliation_bridge') }}
where bridged_par30_loans != true_par30_loans
   or bridged_par90_loans != true_par90_loans
