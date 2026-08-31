-- ASSUMPTION #5 (see assumptions_log.md): the payment gateway occasionally
-- double-logs a settled webhook (same order, same amount, processed seconds
-- apart). We treat this as a duplicate EVENT, not two payments, and keep the
-- earliest-settled row per order as the "real" one. The dropped duplicates
-- are surfaced as a metric (duplicate_payment_amount) so Finance can see how
-- much of the historical "double counting" complaint this actually explains.
--
-- Failed attempts are passed through untouched — they carry no cash and are
-- useful for retry-rate analysis, just not for revenue.

with payments as (

    select * from {{ ref('stg_payments') }}

),

succeeded as (

    select
        *,
        row_number() over (
            partition by order_id, payment_status
            order by processed_at asc, payment_id asc
        ) as settle_rank
    from payments
    where payment_status = 'succeeded'

),

deduped_succeeded as (

    select
        payment_id,
        order_id,
        payment_status,
        amount,
        currency_code,
        payment_method,
        gateway_fee,
        attempted_at,
        processed_at,
        false as is_duplicate_settlement
    from succeeded
    where settle_rank = 1

),

dropped_duplicates as (

    select
        payment_id,
        order_id,
        payment_status,
        amount,
        currency_code,
        payment_method,
        gateway_fee,
        attempted_at,
        processed_at,
        true as is_duplicate_settlement
    from succeeded
    where settle_rank > 1

),

failed as (

    select
        payment_id,
        order_id,
        payment_status,
        amount,
        currency_code,
        payment_method,
        gateway_fee,
        attempted_at,
        processed_at,
        false as is_duplicate_settlement
    from payments
    where payment_status != 'succeeded'

)

select * from deduped_succeeded
union all
select * from dropped_duplicates   -- kept, flagged true, so nothing is silently dropped
union all
select * from failed
