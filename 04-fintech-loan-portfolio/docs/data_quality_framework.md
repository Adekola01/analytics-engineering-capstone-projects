# Data Quality Framework — Engagement 04

## Test inventory (~22 tests total, 4 business-rule)

### Generic / schema tests (~18)
Primary key integrity, referential integrity, domain integrity, and range
sanity checks across `models/staging/schema.yml` and `models/marts/schema.yml`.

| Category | Examples | Default severity |
|---|---|---|
| Primary key integrity | `unique`/`not_null` on `application_id`, `loan_id`, `repayment_id`, `default_id`, `product_type` (marts) | error |
| Referential integrity | `loans.application_id`, `repayments.loan_id`, `defaults.loan_id` → parents | error |
| Domain integrity | `accepted_values` on `decision`, `loan_status`, `payment_status`, `default_status` | error |
| Range sanity | `principal_amount > 0`, `true_dpd >= 0`, `outstanding_balance_estimate >= 0` | error |

### Business-rule (singular) tests (4) — `dbt/tests/*.sql`

| Test | Rule | Severity | What happens when it fails in prod |
|---|---|---|---|
| `no_overpayment_per_instalment` | A single non-duplicate posting ≤ 101% of its scheduled amount | **error** (hard stop) | Cash is being over-attributed to an instalment — could wrongly clear a delinquent instalment. Blocks the run; routed to the servicing-gateway team if it's a real overpayment pattern, or to on-call analytics engineering if it's a dedup bug. |
| `no_duplicate_postings_counted_twice` | At most one non-duplicate posted/partial row per `(loan_id, instalment_no)` feeds cash totals | **error** (hard stop) | Bug in `int_repayments_deduped` itself — pages on-call directly, not a source-data issue. |
| `bridge_ties_to_true_par` | Bridge's `bridged_par30/90_loans` = `true_par30/90_loans` exactly, every `product_type` row | **error** (hard stop) | The CRO's board deck (built from the bridge) and the mart Credit Risk queries directly have diverged. Never let two "true" numbers coexist — blocks downstream deck generation until fixed. |
| `true_par_meets_or_exceeds_reported_par` | Portfolio-level true PAR30 ≥ reported PAR (the engagement's core finding, as a regression guard) | **error** (hard stop) | Signals the restructure clock-reset has been silently re-honoured, or the register is being trusted as ground truth again — both are RUBRIC.md below-bar failures. Treated as a logic bug in our own models, investigated before any other test. |

## Severity philosophy

Same posture as Engagement 01: given the CRO's stated risk ("if the higher
number is right, we are under-provisioned and that is a regulatory issue"),
a data-quality framework that lets a known-wrong, risk-understating PAR
number reach the board on a `warn` is a bigger risk than a blocked pipeline.
All primary-key/referential tests and all four business-rule tests are hard
stops. `warn` is reserved for the currency-mix visibility check (A8) —
informative, not correctness-breaking, and explicitly out of this
engagement's scope.

## "What happens when this fails in production"

1. `dbt build` runs staging → intermediate → marts in dependency order;
   `error`-severity failures halt everything downstream of the failing model.
2. The four business-rule tests run last, against the finished marts — a
   failure means the marts *materialized* but the PAR number can't be
   trusted yet. They are **not swapped into the schema the risk
   dashboard/board deck reads from** until the run is green (same
   blue-green pattern as Engagement 01 — see `orchestration_design.md`).
3. Hard-stop failure → orchestrator marks the DAG failed, pages the on-call
   analytics engineer, and the previous day's last-known-good PAR numbers
   continue serving reads. The CRO never sees a transiently wrong number.
4. Source-origin issues (e.g. a genuine gateway overpayment pattern) get a
   separate notification routed to the servicing-platform team — per
   BRIEF.md, this is fixed at the source, not patched in the warehouse.
