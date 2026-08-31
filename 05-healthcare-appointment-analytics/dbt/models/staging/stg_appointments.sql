-- Staging: 1:1 with RAW_APPOINTMENTS. Light renaming/casting only — no
-- status canonicalization, no dedup, no chain resolution. Those are
-- business decisions and belong in intermediate (see int_appointments_deduped
-- and int_appointments_canonical).

with source as (

    select * from {{ source('raw', 'raw_appointments') }}

),

renamed as (

    select
        appointment_id,
        patient_id,
        doctor_id,
        lower(trim(location))          as location,
        lower(trim(appointment_type))  as appointment_type,

        -- Raw status, only whitespace/case normalized — synonyms
        -- ('no_show'/'missed'/'no-show') are NOT collapsed here.
        lower(trim(status))            as raw_status,

        scheduled_for,
        booked_at,
        checked_in_at,
        checkout_at,
        lower(trim(cancel_reason))     as cancel_reason,
        rescheduled_to_id,
        rescheduled_from_id

    from source

)

select * from renamed
