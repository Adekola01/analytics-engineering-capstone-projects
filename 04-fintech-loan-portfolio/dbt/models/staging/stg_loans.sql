-- Staging: 1:1 with RAW_LOANS. Light renaming/casting only.
-- IMPORTANT: we surface FIRST_DUE_DATE and RESTRUCTURED_AT as-is, but do NOT
-- treat them as ground truth for delinquency anywhere downstream — see
-- assumptions_log.md A2. The servicer's "current schedule" view is exactly
-- what resets the visible arrears clock; true delinquency is computed from
-- the repayment ledger against instalment cadence, not this field.

with source as (

    select * from {{ source('raw', 'raw_loans') }}

),

renamed as (

    select
        loan_id,
        application_id,
        customer_id,
        product_type,
        principal_amount,
        upper(trim(currency))              as currency_code,
        interest_rate_apr,
        term_months,
        lower(trim(loan_status))           as loan_status,
        originated_at,
        first_due_date                     as current_schedule_first_due_date,
        restructured_at,
        (restructured_at is not null)      as is_restructured

    from source

)

select * from renamed
