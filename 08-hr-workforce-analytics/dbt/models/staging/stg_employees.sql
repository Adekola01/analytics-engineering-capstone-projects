-- Staging: 1:1 with RAW_EMPLOYEES (one row per employment RECORD, not per
-- person). Light renaming/casting only — no dedup, no status/date conflict
-- resolution, no chain stitching. Those are business decisions and belong
-- in intermediate (see int_employees_deduped, int_employment_records_resolved,
-- int_person_chains).

with source as (

    select * from {{ source('raw', 'raw_employees') }}

),

renamed as (

    select
        employee_id,
        person_id,
        full_name,
        department_id,
        job_level,
        lower(trim(employment_type))       as employment_type,
        location,
        hire_date,
        termination_date,

        -- Raw status, only whitespace/case normalized — NOT reconciled
        -- against termination_date here (see int_employment_records_resolved).
        lower(trim(employment_status))     as raw_employment_status,

        prior_employee_id

    from source

)

select * from renamed
