# Data Quality Framework — Engagement 01

## Test inventory (30 tests total, 4 business-rule)

### Generic / schema tests (26)
Structural integrity — primary keys, referential integrity, accepted value
sets, and range sanity checks — spread across `models/staging/schema.yml`
and `models/marts/schema.yml`. All run on every `dbt build`.

| Category | Examples | Default severity |
|---|---|---|
| Primary key integrity | `unique`/`not_null` on `order_id`, `payment_id`, `refund_id`, `shipment_id`, `report_month`, `order_cohort_month` | error |
| Referential integrity | `payments.order_id`, `refunds.order_id`/`payment_id`, `shipping.order_id` → `stg_orders`/`stg_payments` | error |
| Domain integrity | `accepted_values` on `order_status`, `payment_status`, `refund_status`, `shipment_status` | error |
| Range sanity | `order_amount > 0`, `net_revenue >= 0`, `cancellation_leakage_amount >= 0` | error |

### Business-rule (singular) tests (4) — `dbt/tests/*.sql`

| Test | Rule | Severity | What happens when it fails in prod |
|---|---|---|---|
| `no_over_refunding` | `sum(refund_amount)` per payment ≤ the payment's settled amount | **error** (hard stop) | `dbt build` fails before marts are swapped. Source-system incident — routed to the payments/refunds team, not fixed in the warehouse. Board number is never published wrong. |
| `no_duplicate_settlements_counted_in_revenue` | At most one non-duplicate succeeded payment per order feeds revenue | **error** (hard stop) | Indicates a bug in `int_payments_deduped` logic itself (not a source-data issue) — pages the on-call analytics engineer directly, since this is our code's correctness, not upstream data quality. |
| `bridge_ties_to_fct_revenue` | Bridge's `finance_reconciled_number` = `sum(fct_revenue.net_revenue)` per cohort month (±$1 rounding) | **error** (hard stop) | The board deck and the queryable mart have diverged — never let Finance see two different "true" numbers. Blocks the run; deck generation (manual, downstream of the mart) is blocked until fixed. |
| `net_revenue_ties_to_raw_ledger` | `sum(net_revenue)` = deduped succeeded payments − completed refunds, computed independently from staging | **error** (hard stop) | The most senior tie-out check — catches a bug in `fct_revenue` itself. Non-negotiable per RUBRIC.md; nothing downstream runs until this passes. |

## Severity philosophy

- **error** is the default posture for this engagement. Given the client's
  complaint is literally "I don't trust the number," a data-quality
  framework that lets a known-wrong number reach the board on a `warn` is a
  bigger risk than a late/blocked pipeline. All four business-rule tests and
  all primary-key/referential tests are hard stops.
- **warn** is reserved for signals that are informative but not
  correctness-breaking today — e.g. a currency-mix test on `fct_revenue_monthly`
  (see `assumptions_log.md` A6) that flags non-USD volume without blocking
  the run, since FX normalization is out of this engagement's scope.

## "What happens when this fails in production" — the general story

1. `dbt build` runs staging → intermediate → marts in dependency order.
2. Generic tests run inline as each model is built; an `error`-severity
   failure on a staging/intermediate model halts everything downstream of it
   (marts never build on top of known-bad intermediate data).
3. The four business-rule tests run last, against the finished marts. A
   failure here means the marts *materialized* but are not trustworthy —
   they are **not swapped into the schema the BI tool/board deck reads from**
   until the run is green (blue-green pattern via dbt's `--defer`/prod-build
   pattern — see `orchestration_design.md`).
4. On any hard-stop failure: the orchestrator marks the DAG run failed,
   pages the on-call analytics engineer via the alerting channel, and the
   previous day's (last-known-good) marts continue serving reads — nobody
   sees a partially-built or wrong number.
5. Data-origin issues (e.g. `no_over_refunding`) get a second, separate
   notification routed to the owning source-system team, distinct from the
   on-call page — these are "fix at the source" per BRIEF.md definition of
   done #3, not warehouse patches.
