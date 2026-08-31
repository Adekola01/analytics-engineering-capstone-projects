-- Staging: 1:1 with RAW_REPAYMENTS. Light renaming/casting only.
-- Deliberately NOT deduping gateway double-posts here — that decision
-- belongs in intermediate, same pattern as int_payments_deduped in Eng. 01.

with source as (

    select * from {{ source('raw', 'raw_repayments') }}

),

renamed as (

    select
        repayment_id,
        loan_id,
        instalment_no,
        scheduled_amount,
        amount_paid,
        upper(trim(currency))          as currency_code,
        lower(trim(payment_status))    as payment_status,
        due_date,
        paid_at

    from source

)

select * from renamed
