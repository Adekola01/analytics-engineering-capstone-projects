-- Staging: 1:1 with RAW_BILLING. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_billing') }}

),

renamed as (

    select
        billing_id,
        appointment_id,
        patient_id,
        lower(trim(line_type))         as line_type,
        billed_amount,
        insurance_covered,
        patient_responsibility,
        service_at,
        posted_at

    from source

)

select * from renamed
