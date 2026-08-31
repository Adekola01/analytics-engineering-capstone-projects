# Data Quality Framework — Engagement 05

## Test inventory (~20 tests total, 4 business-rule)

### Generic / schema tests (~16)
Primary key integrity, referential integrity, and domain integrity across
`models/staging/schema.yml` and `models/marts/schema.yml`.

| Category | Examples | Default severity |
|---|---|---|
| Primary key integrity | `unique`/`not_null` on `patient_id`, `doctor_id`, `appointment_id`, `billing_id`, `logical_visit_id` | error |
| Referential integrity | `appointments.patient_id`/`doctor_id` → parents | error |
| Domain integrity | `accepted_values` on `sex`, `raw_status`, `line_type`, `final_canonical_status`, `no_show_risk_segment` | error |

### Business-rule (singular) tests (4) — `dbt/tests/*.sql`

| Test | Rule | Severity | What happens when it fails in prod |
|---|---|---|---|
| `every_row_has_one_canonical_status` | Every row resolves to a known, non-null canonical status (`unresolved` is an allowed, flagged outcome) | **error** (hard stop) | A row isn't counted in either the naive or true no-show number — both totals would silently shrink. Blocks the run before any mart builds on top of it. |
| `no_double_counted_visit_intent` | Every non-duplicate appointment row belongs to exactly one chain position (root or terminal) | **error** (hard stop) | Direct check on RUBRIC.md's non-negotiable — a patient's single intent being counted as two visits. Pages on-call immediately; this is the correctness dimension worth the most weight. |
| `bridge_ties_to_fct_appointments` | Bridge's `bridged_true_no_show_count` = `fct_appointments`' true no-show count, every location | **error** (hard stop) | The COO's board deck (from the bridge) and what Clinical Ops queries directly have diverged. Blocks deck generation until fixed — never let two "true" numbers coexist in a room that already doesn't trust the number. |
| `billing_never_contradicts_canonical_status` | No office-visit charge against a no-show; no no-show fee against an attended visit | **error** (hard stop) | Either the canonicalization logic is wrong, or Revenue Cycle's billing feed has a real keying error. Routed to on-call analytics engineering first (check our logic), then to Revenue Cycle if the billing data itself is the source. |

## Severity philosophy

Same posture as prior engagements: the COO explicitly said they "can't run
an initiative against a number [they] don't trust" — a data-quality
framework that lets a wrong no-show number reach the board initiative
decision on a `warn` defeats the entire purpose of the engagement. All
primary-key/referential tests and all four business-rule tests are hard
stops. There is no `warn`-severity test in this engagement's inventory —
unlike currency in Engagements 01/04, nothing here is genuinely out of
scope; everything touches the headline number directly.

## "What happens when this fails in production"

1. `dbt build` runs staging → intermediate (dedup → canonicalize → chains)
   → marts in dependency order; an `error` failure halts everything
   downstream, which matters more here than most engagements since the
   pipeline stages have a strict must-run-in-order dependency (dedup before
   canonicalize before chains — see assumptions_log.md A4).
2. Business-rule tests run last, against the finished marts. A failure
   means the marts materialized but can't be trusted — **not swapped into
   the schema Clinical Ops/the board deck reads from** until green (same
   blue-green pattern as prior engagements — see `orchestration_design.md`).
3. Hard-stop failure → orchestrator marks the run failed, pages the on-call
   analytics engineer, and yesterday's last-known-good marts keep serving
   reads. Nobody in the no-show reduction initiative sees a wrong number.
4. Front-desk-origin issues (e.g. a sudden spike in `unresolved` rows,
   suggesting a new location started keying statuses differently) get a
   separate notification to the Patient Access Manager — per BRIEF.md,
   fixed at the front desk, not patched in the warehouse.
