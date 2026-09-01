{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md correctness dimension, explicit: "transfers net
-- to zero across departments"). A transfer moves one person from one
-- department to another — it must never create or destroy headcount at the
-- company level. sum(transfers_in) across all departments must equal
-- sum(transfers_out) across all departments, exactly.
--
-- Fails in prod: hard stop. A mismatch means a transfer is being counted on
-- one side of the move but not the other — e.g. a transfer whose
-- destination department fell outside the window while its source didn't,
-- or a bug in int_employment_chain_classified's transfer detection. This is
-- the direct, mechanical check on "don't count a transfer as a net change
-- in headcount."

select
    sum(transfers_in)  as total_transfers_in,
    sum(transfers_out) as total_transfers_out
from {{ ref('fct_department_workforce') }}
where department_name != 'ALL'
having sum(transfers_in) != sum(transfers_out)
