# Source-to-Target Mapping — Engagement 01

## RAW_ORDERS → stg_orders → fct_revenue

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `ORDER_ID` | `order_id` | passthrough | `order_id` (PK) | unique/not_null tested |
| `CUSTOMER_ID` | `customer_id` | passthrough | `customer_id` | |
| `ORDER_STATUS` | `order_status` | `lower(trim())` | `order_status` | accepted_values tested; NOT used as revenue gate (see A1) |
| `ORDER_AMOUNT` | `order_amount` | passthrough | `order_amount`, `fulfilled_amount` (conditional) | |
| `CURRENCY` | `currency_code` | `upper(trim())` | `currency_code` | not normalized (see A6) |
| `CREATED_AT` | `created_at` | passthrough | `created_at`, drives `fulfillment_month` / cohort month | |
| `UPDATED_AT` | `updated_at` | passthrough | `updated_at` | not used in logic (see A7) |
| *(derived)* | `has_clock_skew` | `updated_at < created_at` | `has_clock_skew` | flag only, never corrected |

## RAW_PAYMENTS → stg_payments → int_payments_deduped → fct_revenue

| Source column | Staging column | Transform | Downstream | Notes |
|---|---|---|---|---|
| `PAYMENT_ID` | `payment_id` | passthrough | `settlement_payment_id` in `int_order_financials` | unique/not_null tested |
| `ORDER_ID` | `order_id` | passthrough | joins to orders | relationships tested |
| `PAYMENT_STATUS` | `payment_status` | `lower(trim())` | filters `succeeded` into revenue | accepted_values tested |
| `AMOUNT` | `amount` | passthrough | `settled_amount` → `gross_revenue` | deduped first (see A5) |
| `CURRENCY` | `currency_code` | `upper(trim())` | carried through | |
| `PAYMENT_METHOD` | `payment_method` | passthrough | not currently in marts | available for future payment-method cut |
| `GATEWAY_FEE` | `gateway_fee` | passthrough | `gateway_fee` | not netted against revenue (gross vs. fee is a separate P&L question, out of scope) |
| `ATTEMPTED_AT` | `attempted_at` | passthrough | not currently in marts | retry-analysis input, out of scope this engagement |
| `PROCESSED_AT` | `processed_at` | passthrough | `payment_processed_at` → `revenue_recognition_month` | drives Finance's recognition month (A2) |
| *(derived)* | — | `ROW_NUMBER()` dedup on `(order_id, succeeded)` | `is_duplicate_settlement` | duplicate leg of the bridge (A5) |

## RAW_REFUNDS → stg_refunds → fct_revenue

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `REFUND_ID` | `refund_id` | passthrough | (aggregated away) | unique/not_null tested |
| `ORDER_ID` | `order_id` | passthrough | joins to orders | |
| `PAYMENT_ID` | `payment_id` | passthrough | joins to payments; over-refund test | relationships tested |
| `REFUND_AMOUNT` | `refund_amount` | passthrough | `total_refunded` (sum) | net_revenue = gross − this (A3) |
| `CURRENCY` | `currency_code` | `upper(trim())` | carried through | |
| `REFUND_REASON` | `refund_reason` | passthrough | not currently in marts | available for a future "why are we refunding" cut |
| `REFUND_STATUS` | `refund_status` | `lower(trim())` | filters `completed` | accepted_values tested |
| `REQUESTED_AT` | `requested_at` | passthrough | not currently in marts | |
| `PROCESSED_AT` | `refund_processed_at` | passthrough | `last_refund_processed_at` → drives timing bridge leg | A2, A3 |

## RAW_SHIPPING → stg_shipping → fct_revenue

| Source column | Staging column | Transform | Mart column(s) | Notes |
|---|---|---|---|---|
| `SHIPMENT_ID` | `shipment_id` | passthrough | (aggregated away) | unique/not_null tested |
| `ORDER_ID` | `order_id` | passthrough | joins to orders | |
| `CARRIER` | `carrier` | passthrough | not currently in marts | |
| `SHIPPING_COST` | `shipping_cost` | passthrough | not currently in marts | out of scope (not a revenue field) |
| `STATUS` | `shipment_status` | `lower(trim())` | `was_delivered` | accepted_values tested |
| `SHIPPED_AT` | `shipped_at` | passthrough (nulls preserved) | `was_fulfilled` = `shipped_at is not null` | Ops' definition (A1); nulls = carrier API timeout, not "unshipped" |
| `DELIVERED_AT` | `delivered_at` | passthrough (nulls preserved) | `was_delivered` | |

## Grain summary

| Layer | Model | Grain |
|---|---|---|
| staging | `stg_orders` / `stg_payments` / `stg_refunds` / `stg_shipping` | 1:1 with source table |
| intermediate | `int_payments_deduped` | 1 row per payment attempt (dupes flagged, not dropped) |
| intermediate | `int_order_financials` | 1 row per `order_id` |
| marts | `fct_revenue` | 1 row per `order_id` |
| marts | `fct_revenue_monthly` | 1 row per `revenue_recognition_month` |
| marts | `fct_revenue_reconciliation_bridge` | 1 row per order-cohort month (`created_at` month) |
