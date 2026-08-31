-- Defensive dedup: the register is hand-maintained (per the Data Lead), so
-- rather than assume one row per loan, collapse defensively to one row per
-- loan_id, keeping the most recent flag. A uniqueness test on stg_defaults
-- will still catch this if/when it happens, but the mart shouldn't fan out
-- silently if it does.

with defaults as (

    select * from {{ ref('stg_defaults') }}

),

collapsed as (

    select
        loan_id,
        count(*)                                           as register_entry_count,
        max(flagged_at)                                    as most_recent_flagged_at,
        max_by(default_status, flagged_at)                 as most_recent_default_status,
        max_by(default_reason, flagged_at)                 as most_recent_default_reason,
        max_by(outstanding_at_default, flagged_at)          as outstanding_at_default
    from defaults
    group by 1

)

select
    loan_id,
    register_entry_count,
    true                            as is_reported_defaulted,
    most_recent_flagged_at,
    most_recent_default_status,
    most_recent_default_reason,
    outstanding_at_default
from collapsed
