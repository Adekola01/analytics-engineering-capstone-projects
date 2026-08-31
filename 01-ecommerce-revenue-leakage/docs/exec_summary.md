# Executive Summary — Lumen & Loom Revenue Reconciliation

**To:** VP of Finance, Head of Operations
**From:** Analytics Engineering
**Re:** The 8–12% revenue gap

## The one-paragraph version

Finance and Ops were never disagreeing about arithmetic — they were using
two different, both-reasonable definitions of revenue (cash collected vs.
goods fulfilled) without realizing it. We built one shared source of truth
(`fct_revenue`) that both definitions can be computed from, and a
reconciliation bridge that walks line-by-line from Ops' number to Finance's
number, naming every dollar of the gap instead of hiding it.

## What explains the gap

1. **Cancellation leakage** — cash collected on orders that were cancelled
   and never refunded. This is real money Ops correctly excludes (nothing
   shipped) and Finance was correctly including (cash in hand) — but nobody
   had sized or flagged it as its own line before. **This is the one
   actionable finding**: it should be either refunded or explicitly written
   off, not left ambiguous.
2. **Work-in-progress** — orders charged but not yet shipped. Finance's cash
   number legitimately includes this; Ops' fulfillment number legitimately
   doesn't yet. Not an error on either side — a timing difference that
   self-resolves as orders ship.
3. **Refund timing** — refunds settle days to weeks after the original
   order, sometimes crossing a month boundary. This is *why the gap moves
   month to month* — it isn't a new problem each month, it's the same
   mechanic playing out on a rolling basis.
4. **Duplicate payments** — a small number of gateway webhooks were logged
   twice, inflating any naive "sum of successful payments" query. Now
   deduped and excluded; the excluded amount is shown for transparency.

## What we found and fixed vs. what the source systems need to fix

**Fixed in the model (no source-system change needed):**
- Duplicate gateway settlements — deduped in `int_payments_deduped`.
- Missing shipping timestamps — treated as "in transit," not silently
  dropped or imputed.

**Needs a source-system fix (we will not silently patch these in the
warehouse — see RUBRIC.md non-negotiables):**
- A small population of orders (~0.2%) has `UPDATED_AT` before `CREATED_AT`
  — a clock-skew bug in the order-management system's status-update writer.
- No freshness SLA currently exists for the refunds or shipping feeds —
  recommend the same 36h/48h thresholds already applied to orders/payments.

## Known limitation

Currency is not yet normalized to USD — non-USD volume (~15% of orders) is
summed at face value in monthly totals. Flagged via a data-quality warning,
not silently included. Recommended as the next phase of work if
international volume grows.

## Bottom line for the board

There is one number now: `fct_revenue_monthly.net_revenue`, and it ties
exactly to the raw payment/refund ledger (enforced by an automated test on
every pipeline run). Ops' number and Finance's number are both still
available, both correct for what they measure, and both explainable from the
same underlying data.
