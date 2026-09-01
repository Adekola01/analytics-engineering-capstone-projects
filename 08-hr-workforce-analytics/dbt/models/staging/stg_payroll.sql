-- Staging: 1:1 with RAW_PAYROLL. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_payroll') }}

),

renamed as (

    select
        payroll_id,
        employee_id,
        person_id,
        pay_period,
        gross_pay,
        upper(trim(currency))      as currency_code,
        is_partial_period,
        paid_at

    from source

)

select * from renamed
