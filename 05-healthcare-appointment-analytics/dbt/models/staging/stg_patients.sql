-- Staging: 1:1 with RAW_PATIENTS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_patients') }}

),

renamed as (

    select
        patient_id,
        birth_year,
        upper(trim(sex))               as sex,
        lower(trim(insurance_plan))    as insurance_plan,
        lower(trim(home_location))     as home_location,
        registered_at

    from source

)

select * from renamed
