{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (assumptions_log.md A6 — billing corroborates, never
-- overrides, but it should never flatly CONTRADICT the canonical status
-- either): a logical visit whose final canonical status is 'no_show' must
-- never carry an office_visit charge (you cannot bill a normal office
-- visit for a patient who never arrived), and a visit whose status is
-- 'attended' must never carry a no_show_fee.
--
-- This does not test billing timing/lag (out of scope, see assumptions_log
-- A6) — only this specific, unambiguous contradiction, which would mean
-- either our canonicalization is wrong or the billing feed has a real
-- keying error worth flagging to Revenue Cycle.
--
-- Fails in prod: hard stop. If this fires at volume, re-check
-- int_appointments_canonical's priority order before assuming it's a
-- billing-side bug — a contradiction here undermines the "billing
-- corroborates attendance" narrative in the exec summary.

select
    final_appointment_id,
    final_canonical_status,
    has_office_visit_charge,
    has_no_show_fee_charge
from {{ ref('fct_appointments') }}
where (final_canonical_status = 'no_show' and has_office_visit_charge = true)
   or (final_canonical_status = 'attended' and has_no_show_fee_charge = true)
