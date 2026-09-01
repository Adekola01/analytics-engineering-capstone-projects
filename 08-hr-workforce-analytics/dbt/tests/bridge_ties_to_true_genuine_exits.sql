{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE: fct_attrition_tenure_reconciliation_bridge's
-- bridged_true_genuine_exits (naive − duplicates − transfer closures) must
-- equal true_genuine_exit_count EXACTLY. This is the "the bridge is
-- mathematically the same number, not just a nice story" check —
-- non-negotiable per RUBRIC.md ("an attrition number with no
-- reconciliation to the raw record-based view" is an auto-deduction).
--
-- Fails in prod: the CPO's board deck (built from the bridge) and what
-- Talent/Finance would each independently recompute from
-- int_employment_records_resolved have silently diverged. Hard stop.

select
    bridged_true_genuine_exits,
    true_genuine_exit_count
from {{ ref('fct_attrition_tenure_reconciliation_bridge') }}
where bridged_true_genuine_exits != true_genuine_exit_count
