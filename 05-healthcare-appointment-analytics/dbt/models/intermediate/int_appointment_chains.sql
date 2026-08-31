-- THE reschedule-chain resolver (BRIEF.md §3 Q3, RUBRIC.md correctness
-- dimension: "reschedule chains resolved... no double-counting one patient
-- intent as two missed visits"). Walks forward from every chain ROOT
-- (a non-duplicate slot that is not itself the target of another
-- reschedule) through validated RESCHEDULED_TO_ID links until it reaches a
-- terminal slot (canonical_status != 'rescheduled'), and collapses the
-- whole chain to one logical visit owned by the root.
--
-- This generator only ever produces single-hop chains, but the walk is
-- written to handle N hops defensively (capped at 10 — see the recursion
-- guard) because nothing about the schema guarantees chains stay short,
-- and the defense question ("rescheduled twice then attended") deserves a
-- model that actually handles it, not one that happens to work by luck.

with recursive appointments as (

    select * from {{ ref('int_appointments_canonical') }}
    where is_duplicate_booking = false

),

roots as (

    -- A root is a slot nobody rescheduled INTO (not the target of a link).
    select appointment_id as root_appointment_id
    from appointments
    where rescheduled_from_id is null
       or rescheduled_from_id not in (select appointment_id from appointments)  -- orphaned FROM link -> still a root

),

chain as (

    select
        r.root_appointment_id,
        a.appointment_id                       as current_appointment_id,
        a.canonical_status                     as current_canonical_status,
        a.has_validated_reschedule_link,
        a.rescheduled_to_id,
        1                                        as hop_number
    from roots r
    join appointments a on r.root_appointment_id = a.appointment_id

    union all

    select
        c.root_appointment_id,
        a.appointment_id,
        a.canonical_status,
        a.has_validated_reschedule_link,
        a.rescheduled_to_id,
        c.hop_number + 1
    from chain c
    join appointments a on c.rescheduled_to_id = a.appointment_id
    where c.has_validated_reschedule_link = true
      and c.hop_number < 10   -- recursion guard; generator only ever produces 1 hop

),

terminal_per_chain as (

    select
        root_appointment_id,
        current_appointment_id      as final_appointment_id,
        current_canonical_status    as final_canonical_status,
        hop_number                  as chain_length,
        row_number() over (
            partition by root_appointment_id order by hop_number desc
        ) as rn
    from chain

)

select
    root_appointment_id                as logical_visit_id,
    final_appointment_id,
    final_canonical_status,
    chain_length - 1                   as reschedule_count   -- hops beyond the root = actual reschedules
from terminal_per_chain
where rn = 1
