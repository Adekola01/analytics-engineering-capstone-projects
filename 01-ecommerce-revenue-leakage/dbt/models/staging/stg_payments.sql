-- Staging: 1:1 with RAW_PAYMENTS. One row per payment ATTEMPT (incl. failures/retries).
-- Deliberately NOT deduping the gateway double-logs here — that's a business decision
-- (which record "wins") that belongs in intermediate, not staging.

with source as (

    select * from {{ source('raw', 'raw_payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        lower(trim(payment_status))    as payment_status,
        amount,
        upper(trim(currency))          as currency_code,
        payment_method,
        gateway_fee,
        attempted_at,
        processed_at

    from source

)

select * from renamed
