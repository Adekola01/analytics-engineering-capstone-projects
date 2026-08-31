# Assumptions & Tradeoffs Log — Engagement 05: Healthcare Appointment Analytics

Every definitional choice below is a decision, not a fact. Each is written so
it can be defended — and challenged — by Clinical Ops and Revenue Cycle
in the same room.

---

### A1. What counts as a no-show?

**Decision:** A row is a true no-show only if, after canonicalization, its
**final chain outcome** is `no_show` — meaning: no `CANCEL_REASON` was
recorded, no validated forward reschedule link exists, and the raw status
was `no_show`/`missed`/`no-show`. A row that was actually rescheduled or
cancelled is reclassified to its true outcome regardless of what the front
desk's status flag says.

**Why:** This is a direct, structural answer to the VP of Clinical Ops'
position: *"a no-show is when a patient just doesn't turn up and doesn't
tell us."* `CANCEL_REASON` and a validated reschedule link are both
stronger, more structured signals of what actually happened than a
free-text-adjacent status flag that the Patient Access Manager has already
told us is unreliable by design ("staff close it out however the location
trained them"). We trust the structured signal over the human-keyed flag
when they conflict.

**Tradeoff:** A patient who reschedules but never actually intends to come
back (a "soft no-show" hiding behind a reschedule) is *not* counted as a
no-show under this definition — they show up as `attended` or `no_show` on
whatever their final slot resolves to, or simply exits the data with an
open reschedule if unresolved. This is a real, known blind spot, flagged in
`exec_summary.md` as a recommended follow-on metric ("reschedule-to-no-show
conversion"), not silently absorbed into the headline rate.

---

### A2. What is the denominator?

**Decision:** Two denominators, both exposed, never confused:
- **Kept-intent visits** (`attended` + `no_show` final outcomes) — the
  denominator for `true_no_show_rate`. This is "of the visits a patient
  actually meant to keep, how many did they miss."
- **All logical visits** (kept-intent + `cancelled`) — the denominator for
  `reschedule_rate`/`cancellation_rate`. These describe scheduling
  behavior, not attendance, so cancellations belong in their denominator.

**Why exclude cancellations from the no-show rate specifically:** A
cancellation is the patient (or the clinic) proactively freeing the slot —
categorically different from silently not showing up. Blending the two
would answer a different, less useful question ("what fraction of booked
slots didn't get used") that conflates two distinct operational problems
(no-show reduction vs. cancellation-driven scheduling gaps) into one number
neither team could act on cleanly.

**Tradeoff:** This denominator choice is *why* our rate is meaningfully
lower than a naive "no_show rows ÷ all booked slots" calculation, even
before misflags are corrected — worth stating explicitly in the defense,
since it's a second, independent reason the numbers differ beyond the
misflag corrections in the bridge.

---

### A3. How should rescheduled appointments be tracked?

**Decision:** A reschedule is a **chain**: original slot → new slot,
linked via `RESCHEDULED_TO_ID`/`RESCHEDULED_FROM_ID`. The chain collapses
to **one logical visit**, owned by the root (the first slot in the chain),
whose outcome is the chain's **terminal** slot's canonical status. A
reschedule, at any hop count, is never itself a no-show or a separate
visit — only the final terminal outcome counts.

**Why:** This is the direct answer to RUBRIC.md's correctness dimension and
the live-defense question ("patient rescheduled twice then attended — how
many no-shows is that?" — **zero**, because every hop before the terminal
one is a *move*, not an outcome). `int_appointment_chains` is written as a
genuinely recursive walk (capped defensively at 10 hops), not a one-off
join, specifically so this holds even though this dataset only ever
produces single-hop chains — the model shouldn't happen to be correct by
luck of the generator's specific parameters.

**Tradeoff:** The chain's location/provider/appointment_type attributes are
taken from the **final** slot (where care was actually attempted), while
the originally-scheduled date is preserved separately
(`originally_scheduled_for`) for lag analysis. A chain that moves clinics
mid-reschedule (not present in this dataset, but not impossible in
production) would attribute the whole visit to its final location — worth
flagging to the Data Lead as an edge case to watch for.

---

### A4. How do you reconcile status flags across locations?

**Decision:** Canonicalize by priority, not literal string matching:
1. `CANCEL_REASON` populated → `cancelled` (overrides a no-show/missed flag)
2. A **validated** forward reschedule link → `rescheduled` (same override)
3. Otherwise, group raw synonyms: `no_show`/`missed`/`no-show` → `no_show`

**Why "validated":** The Data Lead explicitly said they've "never fully
trusted" the link columns. We traced *why*: the double-submit duplicate
bug (A5) strips the forward link off a duplicated row, making a perfectly
real reschedule pair look broken. Once duplicates are removed first
(`int_appointments_deduped` runs *before* `int_appointments_canonical`),
the remaining links are reliable by construction of the generator — we
verified this by design, not by assumption, and it resolves the Data
Lead's distrust rather than working around it. A link that still doesn't
resolve to a real row after dedup is preserved as `unresolved` (flagged,
tested, never silently dropped) rather than guessed at.

**Tradeoff:** If a future data export genuinely corrupts a link
independent of the duplicate-row mechanism, our model would currently
surface it as `unresolved` rather than auto-correcting it — which is the
right conservative default (see RUBRIC.md non-negotiables on silent drops)
but means `unresolved` volume should be monitored, not just tested for
zero.

---

### A5. Duplicate booking rows

**Decision:** The front-desk UI occasionally double-submits a booking
(same patient/doctor/scheduled_for, new `APPOINTMENT_ID`).
`int_appointments_deduped` keeps one row per
`(patient_id, doctor_id, scheduled_for)`, **preferring the row that
carries a reschedule link** over one that doesn't when the two are
otherwise identical (see A4 for why this specific tiebreak matters), then
earliest `appointment_id`. The dropped duplicate is flagged
(`is_duplicate_booking = true`), never deleted.

**Why keep-not-delete:** Same posture as every prior engagement in this
program — RUBRIC.md's non-negotiables penalize silently dropping rows with
no test or note. Duplicates remain visible for the naive-count side of the
reconciliation bridge (the ops dashboard's `count(*)` would include them)
and are excluded from `fct_appointments`/`fct_patient_engagement` via an
explicit filter, checked by `no_double_counted_visit_intent`.

---

### A6. Can billing be trusted as an attendance signal?

**Decision:** No — billing **corroborates**, it never **overrides**.
Canonical status is decided entirely from `RAW_APPOINTMENTS`; billing
(`has_office_visit_charge`, `has_no_show_fee_charge`, etc. in
`int_billing_agg`/`fct_appointments`) is joined on afterward as a
cross-check, and a business-rule test
(`billing_never_contradicts_canonical_status`) catches the one case that
*would* be a real contradiction (an office-visit charge against a no-show,
or a no-show fee against an attended visit) without ever letting billing
drive the status itself.

**Why:** This is a direct, literal implementation of the Director of
Revenue Cycle's warning: *"billing tells you about money, not attendance...
don't conflate the two."* No-show fees exist at only some locations and
apply inconsistently; claims post weeks later, sometimes into a different
month — none of that is a reliable *timing* signal for whether someone
walked in the door, only a *money* signal.

**Tradeoff:** We do not attempt to reconcile `POSTED_AT`'s cross-month lag
into any of the appointment-grain marts — billing timing is left as a
Revenue Cycle-owned concern, flagged as a known limitation, not modeled
here.

---

### A7. Missing check-in timestamps on attended visits

**Decision:** `CHECKED_IN_AT` being null does not affect `canonical_status`
at all — status is decided from `raw_status`/`CANCEL_REASON`/reschedule
links only. A null check-in on an `attended` row is passed through
untouched.

**Why:** The Data Lead's own note explains this precisely (tablet sync
failure) — it's a known, benign gap in a timestamp field, not a signal
about whether the visit happened. Treating a missing check-in as anything
other than "attended, no check-in stamp" would mean guessing at a
timestamp we don't have, which RUBRIC.md's non-negotiables explicitly rule
out ("hard-coded fixes... instead of dbt logic" / fabricating data).
