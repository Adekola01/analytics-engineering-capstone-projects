{{ config(materialized='table') }}

-- Grain: one row per order_id. This is the single mart both Finance and Ops
-- pull their number from (per BRIEF.md definition-of-done #1).
--
-- Definitions applied here (see docs/assumptions_log.md for full rationale):
--   * "Recognized" (Finance view)  -> revenue recognized at PAYMENT date, cash basis.
--   * "Fulfilled" (Ops view)       -> order actually shipped (shipped_at is not null).
--   * Net revenue                  -> settled amount (deduped) minus refunds, ever.
--   * Cancellation leakage         -> charged, cancelled, and NOT fully refunded.
--   * Duplicate payments           -> excluded from revenue entirely (int_payments_deduped).

with base as (

    select * from {{ ref('int_order_financials') }}

),

final as (

    select
        order_id,
        customer_id,
        order_status,
        currency_code,
        created_at,
        updated_at,
        has_clock_skew,

        order_amount,
        was_charged,
        settled_amount,
        gateway_fee,
        payment_processed_at,
        duplicate_payment_amount,

        total_refunded,
        refund_count,
        first_refund_processed_at,
        last_refund_processed_at,

        shipment_status,
        shipped_at,
        delivered_at,
        was_delivered,
        (shipped_at is not null)                                   as was_fulfilled,   -- Ops' definition

        -- ---- Finance view: cash-basis, recognized at payment, net of refunds ----
        coalesce(settled_amount, 0)                                as gross_revenue,
        coalesce(settled_amount, 0) - coalesce(total_refunded, 0)  as net_revenue,
        date_trunc('month', payment_processed_at)                  as revenue_recognition_month,

        -- ---- Ops view: fulfillment-basis, attributed to order month ----
        case when shipped_at is not null then order_amount else 0 end as fulfilled_amount,
        date_trunc('month', created_at)                               as fulfillment_month,

        -- ---- The finding the engagement hinges on ----
        case
            when order_status = 'cancelled'
                 and was_charged
                 and coalesce(total_refunded, 0) < coalesce(settled_amount, 0)
            then coalesce(settled_amount, 0) - coalesce(total_refunded, 0)
            else 0
        end                                                         as cancellation_leakage_amount,

        case
            when order_status = 'cancelled'
                 and was_charged
                 and coalesce(total_refunded, 0) < coalesce(settled_amount, 0)
            then true else false
        end                                                         as is_unrefunded_cancellation_leakage

    from base

)

select * from final
