-- Grain: one row per order_id. This is the pre-mart join layer — no rounding
-- of business decisions happens here beyond aggregation; the *definitions*
-- (what counts as revenue, when it's recognized) are applied in the marts.

with orders as (

    select * from {{ ref('stg_orders') }}

),

payments as (

    select * from {{ ref('int_payments_deduped') }}

),

refunds as (

    select * from {{ ref('stg_refunds') }}

),

shipping as (

    select * from {{ ref('stg_shipping') }}

),

-- One real settled payment per order (duplicates already flagged, not counted).
settled_payment as (

    select
        order_id,
        payment_id             as settlement_payment_id,
        amount                 as settled_amount,
        currency_code,
        gateway_fee,
        processed_at           as payment_processed_at
    from payments
    where payment_status = 'succeeded'
      and is_duplicate_settlement = false

),

duplicate_payment_amount as (

    select
        order_id,
        sum(amount) as duplicate_amount
    from payments
    where is_duplicate_settlement = true
    group by 1

),

refund_agg as (

    select
        order_id,
        sum(refund_amount)                                   as total_refunded,
        min(refund_processed_at)                             as first_refund_processed_at,
        max(refund_processed_at)                             as last_refund_processed_at,
        count(*)                                             as refund_count
    from refunds
    where refund_status = 'completed'
    group by 1

),

shipping_agg as (

    -- An order can only legitimately have one shipment in this business; if the
    -- generator ever produces more, dedupe defensively rather than fan out revenue.
    select
        order_id,
        min(shipment_status)   as shipment_status,       -- deterministic tiebreak, arbitrary but stable
        min(shipped_at)        as shipped_at,
        max(delivered_at)      as delivered_at
    from shipping
    group by 1

)

select
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_amount,
    o.currency_code,
    o.created_at,
    o.updated_at,
    o.has_clock_skew,

    sp.settlement_payment_id,
    sp.settled_amount,
    sp.gateway_fee,
    sp.payment_processed_at,
    (sp.settlement_payment_id is not null)         as was_charged,

    coalesce(dup.duplicate_amount, 0)              as duplicate_payment_amount,

    coalesce(rf.total_refunded, 0)                 as total_refunded,
    rf.first_refund_processed_at,
    rf.last_refund_processed_at,
    coalesce(rf.refund_count, 0)                   as refund_count,

    sh.shipment_status,
    sh.shipped_at,
    sh.delivered_at,
    (sh.shipment_status = 'delivered')             as was_delivered

from orders o
left join settled_payment          sp  on o.order_id = sp.order_id
left join duplicate_payment_amount dup on o.order_id = dup.order_id
left join refund_agg               rf  on o.order_id = rf.order_id
left join shipping_agg             sh  on o.order_id = sh.order_id
