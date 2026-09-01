# Executive Summary — Northwind Atlas Workforce Reconciliation

**To:** Chief People Officer, VP of Talent, Head of Finance / FP&A
**From:** Analytics Engineering
**Re:** Attrition (22–33%) and tenure (~1-year spread), reconciled

## The one-paragraph version

Talent and Finance were each counting something real — they just weren't
counting the same thing. The HRIS represents an internal transfer by
closing one employment record and opening another, and Finance's number
takes that closure literally as an exit. It isn't. We built one
person-grain workforce model that stitches every person's transfers and
rehires into a coherent history, and a bridge that walks Finance's
record-based attrition number down to a true, person-based number —
naming every adjustment along the way.

## What explains the attrition spread

1. **Transfers miscounted as exits (the headline finding).** Every
   internal department move closes a record in the HRIS. Finance's naive
   count takes every closed record as a termination. It isn't a departure
   — the person is still employed, just in a different department.
2. **Duplicate employment records.** A 2021 migration double-loaded a
   slice of records; a small number of these duplicates happen to be
   closed records, inflating the naive count further.

Once both are removed, the true attrition rate is a single, defensible
number — computed entirely independently of Finance's or Talent's own
naive methods, and it ties out to a direct recount from the raw employment
ledger.

## What explains the tenure spread

Three tenure definitions exist, and each side was implicitly using a
different one:
- **Finance's naive number** resets to zero on either a transfer *or* a
  rehire — understating tenure for anyone who's ever moved departments.
- **Talent's implied number** counts straight from a person's first-ever
  hire date, including any time they were gone — which is exactly what
  Finance's "we'd be paying people for years they weren't here" objection
  is about.
- **Our recommended number** ("time-in-seat") sums the actual duration of
  every employment record a person has held — continuous across a
  transfer, but excluding any rehire gap entirely. It answers Talent's
  point without triggering Finance's objection, and the excluded gap is
  reported as its own auditable number, not hidden.

## What we found and fixed vs. what needs a source-system fix

**Fixed in the model:**
- Duplicate employment records, duplicate payroll periods, and duplicate
  review submissions — deduped, flagged, excluded from every calculation.
- The status/date conflict the Data Lead flagged — resolved by treating
  the termination date as authoritative for whether a record is open,
  since the conflict only ever affects that determination, never the
  transfer-vs-exit distinction on already-closed records.

**Needs a source-system fix (not something we patch in the warehouse):**
- The HRIS's practice of closing a record on a transfer, with no clean
  "this was a move, not an exit" flag independent of a downstream status
  field — recommend a dedicated transfer event type at the source.
- Missing performance review dates from a failing cycle-close job — real
  data loss that needs fixing at the review system, not backfilled here.

## Known limitation

Payroll cost is not normalized across currencies in this engagement's
marts — `fct_department_workforce` reports headcount, attrition, and
tenure, not cost. A department-level cost view is recommended as follow-on
work once FX normalization is scoped.

## Bottom line for the board

There is one workforce model now (`fct_workforce`), and both Talent's and
Finance's numbers are explainable from it — including exactly how much of
each disagreement was a transfer, a rehire gap, or a duplicate record. The
CPO can walk into the boardroom with one number, sized, sourced, and
defensible.
