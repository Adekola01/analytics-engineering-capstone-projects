# Assumptions & Tradeoffs Log — Engagement 01: E-Commerce Revenue Leakage

Every definitional choice below is a decision, not a fact. Each is written so
it can be defended — and challenged — in the room with Finance and Ops.

---

### A1. What is a "completed" order?

**Decision:** There is no single "completed" flag. We reject the premise.
Instead we expose two independent, named boolean signals on every order in
`fct_revenue`:
- `was_charged` — cash was collected (Finance's starting point)
- `was_fulfilled` — the order actually shipped (Ops' starting point)

**Why:** Forcing one "completed" definition is exactly the trap that created
this engagement. `RAW_ORDERS.ORDER_STATUS` itself has a `completed` value,
but it's a source-system lifecycle state set by *some* internal process — not
verified against payment or shipping fact. We do not trust it as a revenue
gate. Both teams can now build their own "completed" on top of these two
primitives without arguing about ours.

**Tradeoff:** Anyone querying the mart casually might grab `order_status =
'completed'` out of habit. Column descriptions in `schema.yml` explicitly
warn against this.

---

### A2. When should revenue be recognized?

**Decision:** Cash basis — Finance recognizes revenue in the calendar month
the **payment settles** (`PROCESSED_AT`), not order placement and not
shipment. Refunds are recognized (netted) in the month **the refund
settles**, not restated back into the original order's month.

**Why:** This matches the VP of Finance's own stated logic verbatim ("if a
customer paid us in March, that's March revenue, even if it shipped in
April"). It is also the simplest, most auditable rule to defend to a board:
one date field drives recognition, full stop. Accrual-based alternatives
(recognize at shipment, or pro-rate across order-to-delivery) would require
allocating revenue across periods with no contractual basis for doing so —
this isn't a subscription or multi-period service, it's a single-shipment
retail sale.

**Tradeoff:** This is *why* the monthly board number moves around after the
fact — refunds that settle weeks or months later reduce a month that's
already been reported. `fct_revenue_reconciliation_bridge` calls this out
explicitly (`refunds_recognized_in_later_month`) so it stops looking like a
mystery and starts looking like an expected mechanic.

---

### A3. How should refunds be treated?

**Decision:** Always net against revenue, always at full historical value,
regardless of how much time has passed or whether it crosses a month
boundary. Partial refunds reduce `net_revenue` by exactly the partial amount
— they are not treated as "order downgrades" or re-priced.

**Why:** A refund is real cash leaving the business. There is no accounting
basis for a sale to remain "whole" revenue after money has been returned.

**Tradeoff:** We do **not** cap lookback — a refund six months after the
original sale still reduces that original month's `net_revenue` when queried
retroactively (cohort view) even though the *board* would have already seen
the un-netted number for that closed month (calendar view). This is
intentional and is exactly what `fct_revenue_reconciliation_bridge`
(cohort/lifetime) vs `fct_revenue_monthly` (calendar/point-in-time) are for —
they are two different, both-correct views. This distinction must be
explained live in the defense.

---

### A4. Paid-but-cancelled orders: revenue, liability, or leakage?

**Decision:** **Leakage.** Flagged explicitly via
`is_unrefunded_cancellation_leakage` / `cancellation_leakage_amount` in
`fct_revenue`, and surfaced as its own named line in the reconciliation
bridge — never netted quietly into "net revenue" and never dropped.

**Why:** This is cash the company holds for a good/service it will never
deliver and hasn't returned. It isn't earned revenue (nothing shipped), and
it isn't cleanly a liability either (no refund has been promised or
processed) — it's a control gap. RUBRIC.md explicitly calls this out as a
required, actionable finding, and Ops' own quote ("that's not revenue,
that's wishful thinking") is directionally right about *this specific
population* of orders, even though Ops is wrong that *all* of Finance's
number is wishful thinking.

**Tradeoff:** We chose to still include this amount inside `gross_revenue`/
`net_revenue` (since cash was in fact collected) but flag it separately
rather than exclude it. An alternative, equally defensible position is to
carve it out of net_revenue entirely and book it as a liability-like
"unearned, uncollectable" bucket. We chose inclusion + flagging because it
keeps `net_revenue` tying cleanly to the raw cash ledger (a non-negotiable
per RUBRIC.md) while still making the leakage impossible to miss.

---

### A5. Duplicate / retried payments

**Decision:** Two different phenomena, handled two different ways:
1. **Failed retries** (customer's card declined, retries, then succeeds) —
   kept as-is in `stg_payments`/`int_payments_deduped`, flagged `failed`, and
   excluded from revenue by status alone. No special handling needed; they
   were never cash.
2. **Gateway double-logged settlements** (same order, same amount, two
   `succeeded` rows seconds apart — a webhook delivered twice) — deduped in
   `int_payments_deduped` by keeping the earliest-settled row per
   `(order_id, payment_status='succeeded')` via `ROW_NUMBER()`, and flagging
   the dropped row `is_duplicate_settlement = true` rather than deleting it.

**Why keep-not-delete:** RUBRIC.md's non-negotiables explicitly penalize
"silently dropping rows... with no test or note." The duplicate row still
exists in `int_payments_deduped`, is excluded from every downstream
aggregation via `where is_duplicate_settlement = false`, and its dollar value
is surfaced as its own bridge line (`duplicate_payments_excluded`) so its
magnitude is visible, not just its existence.

**Tradeoff:** "Earliest-settled wins" is an arbitrary tiebreak (both rows are
identical in amount) — any tiebreak produces the same revenue number, so the
choice only matters for which `payment_id` downstream systems would
reference. We chose earliest as the more intuitive "original event."

---

### A6. Currency

**Decision:** Out of scope for this engagement — treated at face value, not
converted. `currency_code` is carried through every model for visibility,
and a data-quality test flags (does not block) any non-`USD` amounts feeding
`fct_revenue_monthly` totals.

**Why:** The brief and rubric are centered on the recognition/leakage/
duplication problem, not FX. ~85% of volume is USD per the generator's
currency mix; conflating currencies in headline totals would itself be a
data-quality bug, so it's flagged rather than silently summed.

**Tradeoff:** `fct_revenue_monthly` totals technically mix currencies at
face value today. This is called out explicitly as a **known limitation** in
the exec summary — not hidden — with FX-normalization named as the
recommended next phase of work (see `docs/exec_summary.md`).

---

### A7. Clock-skew rows (`UPDATED_AT` before `CREATED_AT`)

**Decision:** Flagged (`has_clock_skew` in `stg_orders`/`fct_revenue`), never
used in any date-based logic, never corrected/overwritten.

**Why:** `UPDATED_AT` isn't used anywhere in the revenue model (we use
`CREATED_AT` for cohorting and `PAYMENT_PROCESSED_AT` for recognition), so
this flaw has zero revenue impact — but RUBRIC.md's non-negotiables penalize
silently dropping or "fixing" bad data in place. This is a source-system bug
to route back to the order-management team, not something an analytics
engineer should quietly patch in the warehouse.

---

### A8. Orphaned / no-payment shipments

**Decision:** `int_order_financials` left-joins shipping onto orders; a
shipment for an order with no successful payment is still visible (via
`was_fulfilled = true`, `was_charged = false`) rather than dropped by an
inner join.

**Why:** This combination (shipped but never charged) would itself be worth
surfacing to Ops as a possible fulfillment-system bug or a payment-gateway
gap — dropping it via an inner join would hide a real operational anomaly.
