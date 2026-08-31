-- Staging: 1:1 with RAW_SHIPPING. Light renaming/casting only.
-- SHIPPED_AT / DELIVERED_AT nulls are preserved as-is (carrier API timeouts) —
-- the "what does on-time/delivered mean when the timestamp is missing" call
-- belongs downstream, not here.

with source as (

    select * from {{ source('raw', 'raw_shipping') }}

),

renamed as (

    select
        shipment_id,
        order_id,
        carrier,
        shipping_cost,
        lower(trim(status))    as shipment_status,
        shipped_at,
        delivered_at

    from source

)

select * from renamed
