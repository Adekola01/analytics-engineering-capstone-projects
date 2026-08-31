-- Staging: 1:1 with RAW_DOCTORS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_doctors') }}

),

renamed as (

    select
        doctor_id,
        provider_name,
        lower(trim(specialty))         as specialty,
        lower(trim(primary_location))  as primary_location,
        hired_at,
        is_active

    from source

)

select * from renamed
