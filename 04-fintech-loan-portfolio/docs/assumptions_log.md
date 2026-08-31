# Assumptions & Tradeoffs Log — Engagement 04: Fintech Loan Portfolio

Every definitional choice below is a decision, not a fact. Each is written so
it can be defended — and challenged — by Credit Risk and Collections.

---

### A1. What is a default? (DPD threshold)

**Decision:** Two thresholds, both computed the same way, exposed side by
side rather than picking one "the" default: **PAR30** (≥30 days past due)
and **PAR90** (≥90 days past due). DPD itself is defined as:

> `AS_OF_DATE − due_date of the OLDEST instalment currently showing
> payment_status = 'missed'` (0 if no missed instalments).

**Why 30/90, not a single cutoff:** These are the two industry-standard
regulatory reporting bands (PAR30 for early-warning, PAR90 for capital/
provisioning decisions) — the CRO's provisioning/regulatory concern in the
kickoff call is specifically a PAR90-adjacent question, while Collections'
"which loans need a call this week" concern is closer to PAR30. Neither
team should have to pick one at the expense of the other.

**Why ledger-derived, not `RAW_DEFAULTS` membership:** RUBRIC.md's
non-negotiables explicitly rule out "reporting PAR straight off
`RAW_DEFAULTS` with no independent ledger computation" — and that register
is exactly the number under dispute. DPD is computed independently in
`int_loan_delinquency`, entirely from `RAW_REPAYMENTS`.

---

### A2. How does a restructuring affect the default clock?

**Decision: we do NOT honour the reset.** `true_dpd` is computed from the
repayment ledger's *original* instalment cadence — never from
`RAW_LOANS.FIRST_DUE_DATE` or `RESTRUCTURED_AT`, which reflect the
servicer's post-restructure "current schedule." A restructured loan that is
90 days late against its original instalment sequence shows `true_dpd = 90`
in our model, in direct contradiction to the servicer's own `loan_status =
'restructured'` (a status the source system treats as "not delinquent").

**Why:** This is the single choice the brief calls "most of the gap," and
it's a straight read of the Head of Credit Risk's position: *"the
borrower's behaviour hasn't changed... compute PAR from what people
actually paid."* The repayment ledger's due dates are generated against the
original schedule regardless of what the servicer's loan record says —
verified directly in the generator logic, not assumed. Honouring the
servicer's reset would mean adopting exactly the mechanism that hides risk.

**Tradeoff:** This puts us at odds with the servicing system's own
`loan_status` field for every restructured-and-still-struggling loan. That's
intentional and is precisely `is_hidden_restructure_risk` — the engagement's
headline finding. We do **not** hide this disagreement; `fct_loan_performance`
carries both `loan_status` (servicer's view) and `true_dpd`/`risk_bucket`
(ours) so anyone querying the mart sees the conflict explicitly rather than
one silently overwriting the other.

---

### A3. How should partially-paid instalments be treated?

**Decision:** A partial posting **clears that instalment's due date** for
DPD purposes — it is not a missed instalment and does not extend `true_dpd`.
Its shortfall (`scheduled_amount − amount_paid`) is tracked separately as
`cumulative_partial_shortfall` and rolled into a portfolio-level
`partial_payment_rate`, but never conflated with delinquency.

**Why:** A borrower who pays 60% of an instalment on time is meaningfully
different from one who pays nothing — collapsing the two into "missed"
would overstate PAR and misdirect collections effort toward the wrong
population. The brief explicitly warns against this conflation (BRIEF.md §3.3).

**Tradeoff:** A loan with heavy, chronic partial payments but zero fully-missed
instalments will show `true_dpd = 0` (current) despite real repayment stress.
`partial_rate`/`cumulative_partial_shortfall` on `fct_loan_performance` are
built precisely so Credit Risk can screen for this population separately —
we recommend it as a secondary early-warning signal, not folded into PAR.

---

### A4. What is the active book? (denominator)

**Decision:** Active book = `RAW_LOANS.loan_status != 'closed'`. Declined
and pending applications are excluded entirely (they never became loans);
closed loans are excluded (fully settled, no remaining exposure).

**Why trust `loan_status` for closure specifically, when A2 explicitly
distrusts it for delinquency:** "Closed" is a mechanical, administrative
fact (the servicer terminated the account because it's paid off) — nothing
in the kickoff call, the generator, or the data dictionary suggests this
label is contested the way "restructured"/"delinquent" are. We draw this
line explicitly rather than distrust every source field uniformly.

**Tradeoff:** If closure itself is ever mis-flagged by the servicer (not
evidenced in this dataset, but plausible in production), a small number of
truly-closed loans could linger in the denominator, or vice versa. Worth a
standing data-quality question to the Data Lead, not assumed away.

---

### A5. Duplicate repayment postings

**Decision:** The servicing gateway occasionally double-posts a settled
repayment (same loan, same instalment, same amount, minutes apart).
`int_repayments_deduped` keeps the earliest-settled row per
`(loan_id, instalment_no)` among `posted`/`partial` rows via `ROW_NUMBER()`,
flags the dropped duplicate `is_duplicate_posting = true` (never deletes it),
and excludes duplicates from every downstream cash total.

**Why keep-not-delete:** Same posture as Engagement 01 — RUBRIC.md's
non-negotiables penalize silently dropping rows with no test or note. The
duplicate is visible in `int_repayments_deduped`, excluded via an explicit
filter, and checked by `no_duplicate_postings_counted_twice`.

**Why this matters for PAR specifically:** Duplicates only occur on
`posted`/`partial` rows (never `missed`), so they don't directly create or
clear a delinquency flag — but they DO inflate `cumulative_amount_paid`,
which understates `outstanding_balance_estimate` if not deduped. This
matters for PAR-**by-value**, even though it doesn't move PAR-by-count.

---

### A6. Outstanding balance (for PAR-by-value)

**Decision:** `outstanding_balance_estimate = greatest(principal_amount −
cumulative_amount_paid, 0)`, where `cumulative_amount_paid` sums all deduped
`posted`/`partial` postings to date.

**Why this approximation:** The raw data doesn't separate principal from
interest in each instalment, so a fully accurate amortization schedule isn't
reconstructable from what's provided. Principal-minus-cash-received is the
simplest defensible proxy and, critically, it ties directly to the ledger
(consistent with the engagement's "compute from what people actually paid"
mandate) rather than to a schedule that could itself be contested.

**Tradeoff:** This slightly overstates true outstanding principal early in a
loan's term (since early instalments are interest-heavy in a typical
amortizing structure) and understates it late in the term. Flagged as a
known limitation in `exec_summary.md` — a full amortization schedule would
sharpen PAR-by-value specifically, not PAR-by-count or the bridge.

---

### A7. Reported PAR / register membership

**Decision:** Any loan present in `RAW_DEFAULTS` counts as "reported,"
regardless of `default_status` (`open`, `in_recovery`, `written_off`).

**Why:** This mirrors what Finance currently pulls for the board pack (per
the Data Lead: "It's what Finance reports PAR from today") — we want the
bridge's starting point to match the number under dispute exactly, not a
cleaner version of it.

**Tradeoff:** Some register entries reflect non-arrears reasons (`deceased`,
`fraud`, `bankruptcy`) that don't map to a DPD state at all — these surface
as `stale_register_entries` in the bridge (present in the register, not
currently ledger-delinquent) rather than being silently excluded from the
"reported" starting point.

---

### A8. Currency

**Decision:** Out of scope, same posture as Engagement 01 — carried through
at face value (`currency_code` on every model), not converted. ~85% of
volume is NGN.

**Tradeoff:** `fct_portfolio_metrics`/`fct_par_reconciliation_bridge` totals
mix currencies at face value. Flagged as a known limitation in
`exec_summary.md`, with FX normalization recommended as future work if
USD/GHS volume grows materially.

---

### A9. Clock-skew applications (`DECIDED_AT` before `SUBMITTED_AT`)

**Decision:** Flagged (`has_clock_skew` in `stg_applications`), never used
in any downstream logic, never corrected.

**Why:** `stg_applications` isn't joined into the PAR pipeline at all today
(loans are the entry point) — this flaw has zero PAR impact, but per
RUBRIC.md's non-negotiables it's a source-system bug to route to the
origination team, not something to quietly patch in the warehouse.
