{{ config(materialized='table') }}

-- Grain: one row per loan on the ACTIVE BOOK (loan_status != 'closed').
-- This is the single mart both Credit Risk and Collections pull their
-- number from (per BRIEF.md definition-of-done #1).
--
-- Definitions applied here (see docs/default_definition.md for full
-- rationale):
--   * Active book      -> loan_status != 'closed' (servicer's closure flag
--                          is administrative/mechanical, not contested).
--   * True DPD          -> from int_loan_delinquency, computed off the
--                          ORIGINAL instalment schedule via the ledger.
--                          Restructuring's clock-reset is NOT honoured.
--   * Reported default  -> presence in the defaults register (Collections'
--                          number, as currently reported to the board).
--   * Outstanding value -> principal minus cumulative deduped cash received.

with loans as (

    select * from {{ ref('stg_loans') }}
    where loan_status != 'closed'          -- active book (A4)

),

delinquency as (

    select * from {{ ref('int_loan_delinquency') }}

),

register as (

    select * from {{ ref('int_loan_register_status') }}

),

joined as (

    select
        l.loan_id,
        l.application_id,
        l.customer_id,
        l.product_type,
        l.principal_amount,
        l.currency_code,
        l.interest_rate_apr,
        l.term_months,
        l.loan_status,
        l.originated_at,
        l.current_schedule_first_due_date,
        l.restructured_at,
        l.is_restructured,

        coalesce(d.instalments_due_count, 0)           as instalments_due_count,
        coalesce(d.instalments_missed_count, 0)        as instalments_missed_count,
        coalesce(d.instalments_partial_count, 0)       as instalments_partial_count,
        coalesce(d.cumulative_amount_paid, 0)          as cumulative_amount_paid,
        coalesce(d.cumulative_partial_shortfall, 0)    as cumulative_partial_shortfall,
        d.oldest_missed_due_date,
        coalesce(d.true_dpd, 0)                        as true_dpd,
        coalesce(d.partial_rate, 0)                    as partial_rate,

        greatest(l.principal_amount - coalesce(d.cumulative_amount_paid, 0), 0) as outstanding_balance_estimate,

        coalesce(r.is_reported_defaulted, false)       as is_reported_defaulted,
        r.most_recent_default_status,
        r.most_recent_default_reason,
        r.outstanding_at_default,
        r.register_entry_count

    from loans l
    left join delinquency d on l.loan_id = d.loan_id
    left join register    r on l.loan_id = r.loan_id

),

final as (

    select
        *,

        (true_dpd >= {{ var('par30_dpd_threshold') }})  as is_true_par30,
        (true_dpd >= {{ var('par90_dpd_threshold') }})  as is_true_par90,

        case
            when true_dpd = 0 then 'current'
            when true_dpd < {{ var('par30_dpd_threshold') }} then '1-29_dpd'
            when true_dpd < {{ var('par90_dpd_threshold') }} then '30-89_dpd'
            else '90_plus_dpd'
        end                                              as risk_bucket,

        -- The headline finding: restructured, ledger-shows-delinquent again,
        -- and NOT in the register. This is the risk the reported number hides.
        (is_restructured
            and true_dpd >= {{ var('par30_dpd_threshold') }}
            and coalesce(is_reported_defaulted, false) = false)   as is_hidden_restructure_risk

    from joined

)

select * from final
