# Executive Summary — LendWell Portfolio-at-Risk Reconciliation

**To:** Chief Risk Officer, Head of Credit Risk, Head of Collections
**From:** Analytics Engineering
**Re:** The PAR gap between the reported number and the lender's due-diligence number

## The one-paragraph version

The reported PAR number and the higher number a due-diligence lender found
are not measuring different things by accident — the defaults register is a
hand-maintained list that a loan can quietly disappear from the moment it's
restructured, whether or not the borrower actually recovers. We built a PAR
number computed directly from the repayment ledger, independent of the
register, and a reconciliation bridge that shows exactly which loans the
register is missing and why.

## What explains the gap

1. **Hidden restructure risk (the headline finding).** When a loan is
   restructured, the servicer resets its visible due-date clock and the
   register almost never gets a new entry for it — even when the borrower
   falls behind again on the new schedule. These loans are indistinguishable
   from healthy ones in the current reporting, and they are the single
   largest driver of the gap.
2. **Unregistered, non-restructured delinquents.** Some loans are genuinely
   past due and were simply never booked into the register yet — this is a
   coverage/timing lag in Collections' process, not a clock-reset trick, and
   is a separate, smaller line in the bridge.
3. **Stale register entries.** A handful of register entries are for loans
   that are no longer delinquent by ledger truth, or were flagged for a
   reason unrelated to arrears (fraud, death, bankruptcy) — a small,
   offsetting adjustment in the other direction.

## What we found and fixed vs. what needs a process fix

**Fixed in the model:**
- Gateway double-posted repayments — deduped, excluded from cash totals.
- Partial payments — correctly distinguished from missed instalments rather
  than either being ignored or counted as full defaults.

**Needs a process fix (not something we patch in the warehouse):**
- Restructuring should trigger a *review*, not an automatic removal from the
  watch-list — right now it's structurally almost impossible for a
  restructured loan to re-enter the register even if it re-defaults.
- No freshness SLA exists on the repayments feed; recommend one, since it
  directly stales the DPD calculation.

## Known limitations

- Outstanding balance is estimated as principal minus cash received (no
  interest/principal amortization split available in the source data) —
  sharpens PAR-by-value specifically; does not affect PAR-by-count or the
  bridge's loan-count reconciliation.
- Currency is not normalized to USD/local-equivalent; flagged, not hidden.

## Bottom line for the board

There is one ledger-true PAR number now (`fct_par_reconciliation_bridge`),
computed independently of the register, that explains — loan by loan,
product by product — exactly how much risk the current reporting was
missing and why. The reported number and the true number are both
queryable from the same mart, and the difference between them is no longer
a mystery.
