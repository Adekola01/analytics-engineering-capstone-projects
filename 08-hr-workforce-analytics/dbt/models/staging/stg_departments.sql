-- Staging: 1:1 with RAW_DEPARTMENTS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_departments') }}

),

renamed as (

    select
        department_id,
        department_code,
        department_name,
        division,
        cost_center

    from source

)

select * from renamed
