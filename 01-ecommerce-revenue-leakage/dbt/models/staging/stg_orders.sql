-- Staging: 1:1 with RAW_ORDERS. Light renaming/casting only — no business logic.
-- Grain: one row per order_id (verified unique/not_null in schema.yml).

with source as (

    select * from {{ source('raw', 'raw_orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        lower(trim(order_status))      as order_status,
        order_amount,
        upper(trim(currency))          as currency_code,
        created_at,
        updated_at,

        -- Flag (not fix) the clock-skew rows the Data Lead didn't know about.
        -- Downstream models decide what to do with this; staging just surfaces it.
        (updated_at < created_at)      as has_clock_skew

    from source

)

select * from renamed
