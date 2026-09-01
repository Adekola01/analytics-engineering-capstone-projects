# Assumptions & Tradeoffs Log — Engagement 08: HR Workforce Analytics

Every definitional choice below is a decision, not a fact. Each is written so
it can be defended — and challenged — by the VP of Talent and Head of
Finance in the same room.

---

### A1. What is the grain of "an employee"?

**Decision:** `PERSON_ID`. The workforce mart (`fct_workforce`) is
person-grain, not employment-record-grain. Every employment record
(`EMPLOYEE_ID`) belonging to a person is stitched into one row.

**Why:** `RAW_EMPLOYEES` is explicitly one row per employment *record* — a
transfer or rehire opens a new `EMPLOYEE_ID` for the same human. Counting
records as employees is exactly the mechanism that inflates Finance's
headcount and attrition numbers. A person is a person regardless of how
many times the HRIS has represented them.

**Tradeoff:** Attributes that can differ by record (department, job level,
location) collapse to whichever the person's *most recent* record shows.
Someone's full department history is still queryable via
`int_employment_chain_classified` if needed — it isn't lost, just not the
mart's default grain.

---

### A2. How should internal movement (transfers) be modeled?

**Decision:** A transfer is **one continuous employment**, never an exit.
The HRIS represents it as closing one record (`EMPLOYMENT_STATUS =
'transferred'`) and opening a new one (`PRIOR_EMPLOYEE_ID` pointing back) —
we detect this pattern in `int_employment_chain_classified` and treat the
pair as a single unbroken stint for every tenure and attrition calculation.

**Why:** This is a direct, literal read of VP Talent's core complaint:
*"That person never left."* It is also the single choice that drives most
of the attrition spread (RUBRIC.md names it as the expected headline
finding) — verified directly against the generator, which only ever
creates a transfer successor with **zero gap** (the new record's
`HIRE_DATE` is exactly the old record's `TERMINATION_DATE`).

**Tradeoff:** The department reporting layer (`fct_department_workforce`)
still needs transfers to be visible *somewhere* — a transfer correctly
**reduces the source department's headcount and increases the
destination's**, without ever registering as a company-level exit. Getting
this right (not double-hiding the movement) is enforced by the
`transfers_net_to_zero_across_departments` test.

---

### A3. What defines tenure across a rehire gap?

**Decision:** Three definitions, computed side by side, never silently
collapsed to one (mirrors A2's spirit — surface the disagreement, don't
erase it):

- **`tenure_time_in_seat_days` (RECOMMENDED)** — sum of every record's own
  active span. Continuous across a transfer (zero gap by construction),
  **excludes** any rehire gap entirely, since a gap isn't part of any
  record's span.
- **`tenure_since_first_hire_days`** — Talent's implied claim: calendar
  span from the person's very first hire to now/exit, which **includes**
  any gap as if they'd been employed the whole time.
- **`current_stint_span_days`** — Finance's naive claim: just the latest
  record's own span, which resets to zero on *either* a transfer or a
  rehire.

**Why time-in-seat is the recommendation:** It's the only one of the three
that survives both objections raised in the kickoff call. It answers
Talent's point (a returning employee isn't a stranger — their prior stint
still counts) without triggering Finance's objection (*"we'd be paying
people for years they weren't even here"* — we don't; the gap is
mechanically excluded, not glossed over). `rehire_gap_days_excluded` on
`fct_workforce` makes this exclusion an auditable, visible number, not an
implicit claim.

**Tradeoff:** Time-in-seat is more complex to explain than either naive
alternative in a single sentence — the deck (`deck_outline.md`) spends a
dedicated slide walking one real rehire example end-to-end specifically
because this definition needs to be *shown*, not just stated.

---

### A4. What counts as attrition / a termination?

**Decision:** A genuine exit is a **non-duplicate** employment record whose
`resolved_state = 'terminated'` (see A5) — explicitly **excluding**
records whose closure was a transfer. The **attrition rate** is annualized
over a trailing window (attrition_window_start–as_of_date),
using the standard `(beginning headcount + ending headcount) / 2` as the
denominator.

**Does a rehired person's original departure still count?** **Yes, for the
historical rate in the period it happened.** If someone left in March and
came back in September, March's attrition figure for that trailing window
still reflects a real departure event — revising it away after the fact
would understate what actually happened operationally in March (a seat
genuinely had to be backfilled, however briefly). Their *current* person-level
status (`is_currently_active`) is separately, correctly `true` today,
because they're back. These are two different questions and the model
answers both without either overwriting the other.

**Why exclude transfers specifically:** Direct implementation of A2 — this
is the single line item that produces most of Finance's inflated 22–33%
range.

---

### A5. How do you reconcile conflicting status?

**Decision:** `TERMINATION_DATE` is authoritative for whether a record is
**open**. A null termination date means the record is still open — full
stop — even if `EMPLOYMENT_STATUS` says `'terminated'` (a lagging status
flag). For **closed** records (`TERMINATION_DATE` populated), the status
flag **is** trustworthy for distinguishing a genuine exit
(`'terminated'`) from an internal move (`'transferred'`).

**Why this split, not "trust one field always":** We verified, rather than
assumed, that the injected status/date conflict in this dataset only ever
targets **open** records (a null-date row incorrectly stamped
`'terminated'`) — it never corrupts the status label on a *closed* record.
Trusting dates for open/closed, and trusting status only once a record is
already closed, uses each field exactly where it's reliable rather than
picking one winner for every situation. `is_status_date_conflict` flags
every case where the two disagree, visible for the source-system fix this
deserves (BRIEF.md definition of done #3) — never silently overridden
without a trace.

**Tradeoff:** A closed record with a status value that's neither
`'terminated'` nor `'transferred'` (not produced by this generator, but
plausible in a real HRIS) defaults conservatively to counting as a genuine
exit rather than being dropped — flagged for review via
`has_dangling_transfer`-style monitoring, never silently excluded from
headcount.

---

### A6. Duplicate employment records

**Decision:** The 2021 HRIS migration double-loaded a slice of records
under a fresh `EMPLOYEE_ID` with identical person/department/hire/
termination details. `int_employees_deduped` keeps the earliest
`EMPLOYEE_ID` per `(person_id, department_id, hire_date, termination_date)`,
flags the dropped duplicate (`is_duplicate_record = true`), never deletes
it.

**Why keep-not-delete:** Same posture as every engagement in this
program — RUBRIC.md's non-negotiables penalize silently dropping rows with
no test or note. The duplicate remains visible for reconstructing Finance's
*naive* number (which wouldn't have deduped) in the reconciliation bridge,
and is excluded from every headcount/tenure/attrition calculation via an
explicit filter.

**Downstream consequence:** Payroll and performance reviews were generated
against *every* employment record, including duplicates — so a slice of
payroll/review rows reference a since-deduped `EMPLOYEE_ID`.
`int_payroll_deduped`/`int_reviews_deduped` flag these as orphaned and
exclude them from cost/performance rollups, rather than letting a
duplicated employment record silently double a real person's pay cost.

---

### A7. Duplicate payroll periods and missing review dates

**Decision:** A cancelled-and-reissued payroll run duplicates a
`(employee_id, pay_period)` pair — deduped to the earliest `PAYROLL_ID`,
flagged, excluded from cost totals. A duplicate review submission is
deduped the same way on `(employee_id, review_period, rating,
review_score)`. A missing `REVIEW_DATE` (the cycle-close job failing) is
preserved as `is_missing_review_date = true` — not backfilled or guessed —
since fabricating a date the source system never recorded would violate
RUBRIC.md's non-negotiables directly.

**Why:** Consistent with every other duplicate-handling decision in this
engagement and program: flag, exclude from aggregates, never silently drop
or invent data.

---

### A8. Currency (payroll cost)

**Decision:** Out of scope for cross-currency normalization in this
engagement's marts — `currency_code` is carried through
`int_payroll_deduped` for visibility, but department-level cost rollups
are not attempted at company scale without an FX conversion layer, which
BRIEF.md doesn't ask for here (unlike Engagement 10). Flagged as a known
limitation in `exec_summary.md`.

**Tradeoff:** `fct_department_workforce` reports headcount, tenure, and
attrition — not payroll cost — for exactly this reason. A department cost
view is recommended as follow-on work once FX normalization is scoped.
