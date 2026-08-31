# Executive Summary — CareGrid No-Show Reconciliation

**To:** Chief Operating Officer, VP of Clinical Operations, Director of Revenue Cycle
**From:** Analytics Engineering
**Re:** The no-show rate — ~22% vs. ~13%, reconciled

## The one-paragraph version

Both numbers were being computed correctly from the data as it's keyed —
they just weren't answering the same question. The ops dashboard counts
every row flagged `no_show`/`missed`, including patients who actually
rescheduled or cancelled but whose slot got closed out with the
empty-chair button. We built a single appointment model that resolves
reschedule chains to one logical visit and reclassifies misflagged
statuses using the more trustworthy structured signals (a cancellation
reason, a validated reschedule link) — landing at a true no-show rate of
roughly 13%, with every point of the ~9-point gap named and quantified.

## What explains the gap

1. **Reschedule misflags (the largest component).** About half of all
   rescheduled visits were closed out by the front desk as `no_show`/
   `missed` instead of `rescheduled`. The patient moved the visit — the
   chair got filled later — but the original slot still shows up as a
   miss on any naive count.
2. **Cancel misflags.** A smaller share of cancellations — including late
   cancels — were likewise keyed as missed visits rather than cancelled.
3. **Duplicate bookings.** A double-submit bug in the scheduling UI
   occasionally writes the same slot twice; a small number of these
   duplicates carry a no-show flag and get double-counted on any naive row
   count.

None of these are hidden in the "true" number — they're each a named,
counted line in the reconciliation bridge, by location.

## What we found and fixed vs. what needs a front-desk fix

**Fixed in the model:**
- Duplicate bookings — deduped, excluded from the true count, but kept
  visible for the naive-count comparison.
- The link-column reliability question the Data Lead raised — traced to
  the duplicate-booking bug specifically (a duplicated row loses its
  reschedule link) and resolved by deduping *before* trusting the links,
  not by ignoring the links altogether.

**Needs a front-desk fix (not something we patch in the warehouse):**
- Staff need a clear, consistent rule for closing out a moved or
  cancelled visit as `rescheduled`/`cancelled` — not the empty-chair
  button. This is a training and workflow issue, quantified per location
  in the bridge so it can be prioritized by where it's worst.
- No-show fee billing is inconsistent across locations and should not be
  read as an attendance signal — confirmed directly against the ledger; a
  business-rule test now guards against it ever contradicting attendance.

## Known limitation

A patient who reschedules but never actually intends to return (a "soft"
no-show hiding behind a reschedule) is not captured by `true_no_show_rate`
today. Recommended as a follow-on metric ("reschedule-to-no-show
conversion") — not folded into the headline rate, which would reintroduce
the exact conflation this engagement exists to remove.

## Bottom line for the board

There is one appointment model now (`fct_appointments`), and both the ops
dashboard's number and the clinical team's number are explainable from it.
The ~13% true rate is what the no-show reduction initiative should be
measured against; the reconciliation bridge is what to show anyone who
still trusts the ~22%.
