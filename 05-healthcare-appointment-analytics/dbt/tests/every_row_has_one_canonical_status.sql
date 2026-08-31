{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md correctness dimension + non-negotiables): every
-- row must resolve to exactly one canonical status, and it must be a known
-- value — no row should silently fall through to null or an unexpected
-- label. 'unresolved' is an allowed, FLAGGED outcome (an orphaned
-- reschedule status with no link at all) — it is not the same as failing
-- to classify a row.
--
-- Fails in prod: hard stop. A row with no canonical status can't be counted
-- in either the naive or the true no-show number, silently shrinking both
-- denominators in a way nobody would notice without this test.

select
    appointment_id,
    raw_status,
    canonical_status
from {{ ref('int_appointments_canonical') }}
where canonical_status is null
   or canonical_status not in ('attended', 'no_show', 'cancelled', 'rescheduled', 'unresolved')
