-- Staging: 1:1 with RAW_DEFAULTS. Light renaming/casting only.
-- This is Collections' hand-maintained register — what Finance currently
-- reports PAR from. We carry it through untouched; the engagement is about
-- comparing it to ledger-truth, not editing it.

with source as (

    select * from {{ source('raw', 'raw_defaults') }}

),

renamed as (

    select
        default_id,
        loan_id,
        default_reason,
        outstanding_at_default,
        upper(trim(currency))          as currency_code,
        lower(trim(default_status))    as default_status,
        flagged_at

    from source

)

select * from renamed
