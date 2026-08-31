-- Staging: 1:1 with RAW_APPLICATIONS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_applications') }}

),

renamed as (

    select
        application_id,
        customer_id,
        product_type,
        channel,
        requested_amount,
        upper(trim(currency))          as currency_code,
        lower(trim(decision))          as decision,
        decline_reason,
        submitted_at,
        decided_at,

        -- Flag (not fix) the clock-skew rows — same pattern as Engagement 01.
        (decided_at < submitted_at)    as has_clock_skew

    from source

)

select * from renamed
