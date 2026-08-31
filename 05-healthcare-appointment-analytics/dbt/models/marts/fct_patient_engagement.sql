{{ config(materialized='table') }}

-- Grain: one row per patient (BRIEF.md deliverable #2). Built entirely on
-- top of fct_appointments' logical-visit grain, so every rate here is
-- already reschedule-chain-safe and misflag-corrected.

with visits as (

    select * from {{ ref('fct_appointments') }}

),

per_patient as (

    select
        patient_id,

        count(*)                                                     as total_logical_visits,
        count(case when is_kept_intent_visit then 1 end)              as kept_intent_visit_count,

        count(case when is_true_no_show then 1 end)                   as true_no_show_count,
        count(case when is_attended then 1 end)                       as attended_count,
        count(case when is_cancelled then 1 end)                      as cancelled_count,
        count(case when was_rescheduled then 1 end)                   as visits_with_reschedule_count,
        sum(reschedule_count)                                          as total_reschedule_hops,

        max(final_scheduled_for)                                       as most_recent_visit_date

    from visits
    group by 1

),

final as (

    select
        patient_id,
        total_logical_visits,
        kept_intent_visit_count,
        true_no_show_count,
        attended_count,
        cancelled_count,
        visits_with_reschedule_count,
        total_reschedule_hops,
        most_recent_visit_date,

        -- True no-show rate: genuine misses over KEPT-INTENT visits only
        -- (assumptions_log.md A3) — not over every logical visit, and
        -- never over raw booked slots.
        div0(true_no_show_count, nullif(kept_intent_visit_count, 0))    as true_no_show_rate,

        div0(attended_count, nullif(kept_intent_visit_count, 0))        as attended_rate,

        -- Reschedule/cancellation rates use ALL logical visits as the
        -- denominator — these describe scheduling behavior, not attendance.
        div0(visits_with_reschedule_count, nullif(total_logical_visits, 0)) as reschedule_rate,
        div0(cancelled_count, nullif(total_logical_visits, 0))          as cancellation_rate,

        -- Actionable risk signal for the COO's no-show reduction initiative.
        case
            when kept_intent_visit_count = 0 then 'no_kept_intent_history'
            when true_no_show_count >= 2 or div0(true_no_show_count, kept_intent_visit_count) >= 0.34
                then 'high_risk'
            when true_no_show_count = 1
                then 'moderate_risk'
            else 'low_risk'
        end                                                             as no_show_risk_segment

    from per_patient

)

select * from final
