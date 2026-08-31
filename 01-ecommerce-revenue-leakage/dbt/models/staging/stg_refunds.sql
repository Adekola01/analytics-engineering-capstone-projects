-- Staging: 1:1 with RAW_REFUNDS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_refunds') }}

),

renamed as (

    select
        refund_id,
        order_id,
        payment_id,
        refund_amount,
        upper(trim(currency))          as currency_code,
        refund_reason,
        lower(trim(refund_status))     as refund_status,
        requested_at,
        processed_at                   as refund_processed_at

    from source

)

select * from renamed
