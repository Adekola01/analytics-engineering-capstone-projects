# Default-Definition Document — Engagement 04

This is the written policy, in one place, for anyone who needs the contract
without reading the full assumptions log.

## 1. Days-past-due (DPD)

> **DPD = AS_OF_DATE minus the due date of the oldest instalment currently
> showing `payment_status = 'missed'`. Zero if no instalment is missed.**

Computed entirely from `RAW_REPAYMENTS` (via `int_loan_delinquency`) —
never from `RAW_LOANS.FIRST_DUE_DATE`, `RESTRUCTURED_AT`, or `LOAN_STATUS`.

## 2. PAR thresholds

| Metric | Threshold | Primary audience |
|---|---|---|
| PAR30 | DPD ≥ 30 | Collections — early-warning, who to call this week |
| PAR90 | DPD ≥ 90 | CRO / regulators — provisioning, capital adequacy |

## 3. Restructuring treatment

**The clock reset is not honoured.** A restructured loan's DPD is measured
against its *original* instalment schedule, exactly like any other loan.
`RAW_LOANS.loan_status = 'restructured'` and `RESTRUCTURED_AT` are preserved
and exposed (`is_restructured` on `fct_loan_performance`) for
transparency and segmentation — but they never suppress a delinquency flag.

## 4. Partial-payment treatment

A `partial` posting satisfies that instalment's due date for DPD purposes
(it is not "missed"). The shortfall is tracked as a separate metric
(`cumulative_partial_shortfall`, `partial_payment_rate`) — an early-warning
signal in its own right, never blended into the DPD/PAR calculation.

## 5. Active book (denominator)

`loan_status != 'closed'`. Declined/pending applications never enter the
book. See `assumptions_log.md` A4 for why `loan_status` is trusted here
specifically, despite being distrusted for delinquency purposes.

## 6. Duplicate postings

Gateway double-posts are deduped to the earliest-settled row per
`(loan_id, instalment_no)`, flagged not deleted, and excluded from
`cumulative_amount_paid` — see `assumptions_log.md` A5.

## 7. Outstanding balance (for PAR-by-value)

`principal_amount − cumulative deduped cash received`, floored at zero. See
`assumptions_log.md` A6 for the amortization-schedule limitation this implies.

## 8. Reported PAR (the register)

Any loan present in `RAW_DEFAULTS`, regardless of `default_status`, counts
as "reported" — matching what Finance currently pulls for the board pack.

## One-sentence summary for the room

*"We measure every loan against its original repayment schedule using only
what was actually paid — a restructuring can change the loan's paperwork,
but it cannot change whether the borrower is current."*
