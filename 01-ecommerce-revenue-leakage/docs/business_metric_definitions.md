# Business Metric Definitions — Engagement 01

Each metric below is a contract: one definition, one owner model, one column.
Anyone quoting a revenue number should be able to point to a row in this
table.

| Metric | Definition | Model.column | Grain |
|---|---|---|---|
| **Gross revenue** | Sum of deduped, succeeded payment amounts, recognized in the month the payment settled. Excludes duplicate gateway webhooks. Includes cash from orders later cancelled (see Cancellation leakage). | `fct_revenue.gross_revenue` (order) / `fct_revenue_monthly.gross_revenue` (monthly) | order / month |
| **Net revenue** | Gross revenue minus the full lifetime value of refunds tied to that payment, regardless of what month the refund itself settled. **This is the number that ties to the raw ledger** (payments minus refunds), enforced by `net_revenue_ties_to_raw_ledger`. | `fct_revenue.net_revenue` / `fct_revenue_monthly.net_revenue` | order / month |
| **Refund rate** | Total refund dollars ÷ gross revenue dollars, same month. | `fct_revenue_monthly.refund_rate` | month |
| **Cancellation leakage** | Cash collected on a `cancelled` order that has not been (fully) refunded back to the customer. The engagement's headline actionable finding. | `fct_revenue.cancellation_leakage_amount` / `fct_revenue_monthly.cancellation_leakage` | order / month |
| **Recognized revenue by month** | Net revenue grouped by the calendar month the underlying payment settled (cash basis, per Finance's own stated logic — see `assumptions_log.md` A2). | `fct_revenue_monthly.report_month` + `net_revenue` | month |
| **Ops' fulfilled revenue** | Order amount for orders that actually shipped, attributed to the month the order was **created** (Ops' mental model). | `fct_revenue.fulfilled_amount` / bridge `ops_number` | order / cohort month |
| **Duplicate payment exposure** | Dollar value of gateway-duplicated settlements that were excluded from revenue — a visibility metric, not a revenue-reducing one (already excluded upstream). | `fct_revenue_monthly.duplicate_payment_amount_excluded` | month |
| **The gap** (bridge) | `finance_reconciled_number − ops_number`, decomposed into WIP, cancellation leakage, duplicate payments, and refunds. | `fct_revenue_reconciliation_bridge.total_bridge_adjustment` / `gap_pct_of_ops_number` | cohort month |

## What each stakeholder should query

- **VP of Finance / board deck:** `fct_revenue_monthly` — calendar-month,
  cash-basis, ties to the ledger.
- **Head of Operations:** `fct_revenue.fulfilled_amount` filtered to
  `was_fulfilled = true`, cohorted by `fulfillment_month` — or the
  `ops_number` column directly in the bridge.
- **The board conversation itself:**
  `fct_revenue_reconciliation_bridge` — the only model designed to be read
  left-to-right as a walk from one team's number to the other's.
