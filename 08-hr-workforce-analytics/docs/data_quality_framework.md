# Data Quality Framework — Engagement 08

## Test inventory (~20 tests total, 4 business-rule)

### Generic / schema tests (~16)
Primary key integrity, referential integrity, and domain integrity across
`models/staging/schema.yml` and `models/marts/schema.yml`.

| Category | Examples | Default severity |
|---|---|---|
| Primary key integrity | `unique`/`not_null` on `department_id`, `employee_id`, `review_id`, `payroll_id`, `person_id`, `department_name` | error |
| Referential integrity | `employees.department_id` → parent | error |
| Domain integrity | `accepted_values` on `raw_employment_status`, `rating`, `currency_code` | error |
| Range sanity | `tenure_time_in_seat_days >= 0` | error |

### Business-rule (singular) tests (4) — `dbt/tests/*.sql`

| Test | Rule | Severity | What happens when it fails in prod |
|---|---|---|---|
| `headcount_reconciles_to_distinct_active_people` | `fct_workforce`'s active-person count equals an independent recount straight from resolved employment records | **error** (hard stop) | The single most senior check — if headcount doesn't tie, nothing downstream (attrition, tenure, department reporting) can be trusted. Blocks the run before any dependent mart is exposed. |
| `transfers_net_to_zero_across_departments` | `sum(transfers_in)` = `sum(transfers_out)` company-wide (RUBRIC.md's explicit correctness check) | **error** (hard stop) | A transfer is creating or destroying headcount somewhere — either a classification bug in `int_employment_chain_classified` or a window-boundary edge case. Pages on-call; this is the direct mechanical proof that transfers aren't being miscounted. |
| `department_headcount_sums_to_company_total` | `sum(active_headcount)` across departments equals the `'ALL'` row (RUBRIC.md's explicit correctness check) | **error** (hard stop) | An active person is either double-attributed or has fallen out of every department cut (null/orphaned `current_department_id`) while still counting company-wide. Blocks department-level reporting until fixed. |
| `bridge_ties_to_true_genuine_exits` | Bridge's `bridged_true_genuine_exits` = `true_genuine_exit_count` exactly | **error** (hard stop) | The CPO's board deck (from the bridge) and what Talent/Finance would independently recompute have diverged. Blocks deck generation — never let two "true" attrition numbers coexist. |

## Severity philosophy

Same posture as every engagement in this program, sharpened by the stakes
here: the CPO explicitly said *"I genuinely cannot tell them, and that is
not acceptable"* about a board-facing number. A framework that lets a wrong
headcount or attrition figure reach the board on a `warn` defeats the
purpose. All primary-key/referential tests and all four business-rule
tests are hard stops. The one `warn`-severity check
(`has_dangling_transfer` accepted_values) exists because a dangling
transfer, while a genuine anomaly worth investigating, doesn't corrupt any
*other* person's numbers — it's informative, not correctness-breaking for
the rest of the mart.

## "What happens when this fails in production"

1. `dbt build` runs staging → intermediate (dedupe → resolve → classify →
   collapse-to-person) → marts, in strict dependency order; an `error`
   failure halts everything downstream — this matters more here than in
   most engagements, since a bug early in the chain (e.g. a broken
   transfer/rehire classification) would silently corrupt both attrition
   *and* tenure at once.
2. Business-rule tests run last, against the finished marts. A failure
   means the marts materialized but can't be trusted — **not swapped into
   the schema the CPO's dashboard/board deck reads from** until green (same
   blue-green pattern as prior engagements — see `orchestration_design.md`).
3. Hard-stop failure → orchestrator marks the run failed, pages the on-call
   analytics engineer, and yesterday's last-known-good marts keep serving
   reads. Nobody presents a board number that doesn't tie out.
4. Source-origin issues (e.g. a spike in `is_status_date_conflict` or
   `is_missing_review_date`) get a separate notification to the HRIS/Data
   Lead team — per BRIEF.md, fixed at the source, not patched in the
   warehouse.
