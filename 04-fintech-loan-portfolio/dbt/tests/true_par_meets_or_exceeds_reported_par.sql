{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (the engagement's core finding, encoded as a regression
-- guard): at the portfolio ('ALL') level, ledger-true PAR30 can never be
-- LOWER than Collections' reported PAR. The whole premise of this
-- engagement is that the register UNDERSTATES risk (restructuring resets
-- the visible clock; booking lags the ledger) — if a future code change
-- ever flips this relationship, someone has reintroduced the clock-reset
-- bug (e.g. started honouring RAW_LOANS.FIRST_DUE_DATE) or started trusting
-- the register as ground truth, both of which RUBRIC.md treats as
-- below-bar failures.
--
-- Fails in prod: hard stop + a note to re-read assumptions_log.md A2 before
-- touching int_loan_delinquency or fct_loan_performance again.

select
    product_type,
    reported_par_loans,
    true_par30_loans
from {{ ref('fct_par_reconciliation_bridge') }}
where product_type = 'ALL'
  and true_par30_loans < reported_par_loans
