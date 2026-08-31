{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: fct_noshow_reconciliation_bridge.bridged_true_no_show_count
-- (naive − duplicates − reschedule misflags − cancel misflags) must equal
-- true_no_show_count EXACTLY, for every location row including 'ALL'. This
-- is the "the bridge is mathematically the same number as the mart, not
-- just a nice story" check — non-negotiable per RUBRIC.md ("a no-show rate
-- with no reconciliation to the naive count" is an auto-deduction).
--
-- Fails in prod: the bridge (what goes in the COO's deck) and
-- fct_appointments (what Clinical Ops queries directly) have silently
-- diverged. Hard stop — never let two different "true" no-show numbers
-- coexist in front of stakeholders who already don't trust each other's
-- numbers.

select
    location,
    bridged_true_no_show_count,
    true_no_show_count
from {{ ref('fct_noshow_reconciliation_bridge') }}
where bridged_true_no_show_count != true_no_show_count
