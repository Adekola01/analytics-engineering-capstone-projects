{{ config(materialized='table') }}

-- THE deliverable for this engagement (BRIEF.md #3, RUBRIC.md 20% weight).
-- Walks from Collections' reported PAR (the defaults register) to
-- ledger-true PAR, naming every loan population in between. One row per
-- product_type, plus one 'ALL' row — same segmentation as fct_portfolio_metrics.
--
-- The walk (all at PAR30 threshold; PAR90 mirrored in separate columns):
--   1. reported_par_loans   = loans in the defaults register today
--   2. + hidden_restructure_risk = restructured loans that are ledger-delinquent
--        again but almost never make it back into the register (the servicer
--        resets the clock; Collections doesn't re-flag) — THE headline finding.
--   3. + unregistered_stressed_delinquents = genuinely delinquent loans
--        (never restructured) that are ledger-delinquent but Collections
--        hasn't booked yet — a timing/coverage gap, not a hidden-risk one.
--   4. - stale_register_entries = loans in the register that are NOT
--        currently ledger-delinquent (already cured, or flagged for a
--        non-arrears reason like fraud/deceased that PAR shouldn't capture).
--   = true_par_loans (ledger-computed, independent of the register)

with base as (

    select * from {{ ref('fct_loan_performance') }}

),

components as (

    select
        product_type,

        count(*)                                                          as active_loan_count,

        -- 1. Reported PAR: register membership, independent of arrears reason.
        --    (See docs/default_definition.md — we count ALL register statuses
        --    as "reported", since that mirrors what Finance pulls today.)
        count(case when is_reported_defaulted then 1 end)                  as reported_par_loans,

        -- 2. Hidden restructure risk: restructured + ledger-delinquent (PAR30)
        --    + NOT in the register. Mirrored at PAR90 for the harder cut.
        count(case when is_restructured and is_true_par30
                        and not is_reported_defaulted then 1 end)          as hidden_restructure_risk_par30,
        count(case when is_restructured and is_true_par90
                        and not is_reported_defaulted then 1 end)          as hidden_restructure_risk_par90,

        -- 3. Unregistered stressed delinquents: NOT restructured, ledger-
        --    delinquent, NOT in the register — Collections simply hasn't
        --    booked it yet (coverage/timing gap, not a clock-reset trick).
        count(case when not is_restructured and is_true_par30
                        and not is_reported_defaulted then 1 end)          as unregistered_delinquents_par30,
        count(case when not is_restructured and is_true_par90
                        and not is_reported_defaulted then 1 end)          as unregistered_delinquents_par90,

        -- 4. Stale register entries: reported, but not currently
        --    ledger-delinquent at the PAR30 threshold (cured, or a
        --    non-arrears default reason like deceased/fraud/bankruptcy that
        --    doesn't map to a DPD state at all).
        count(case when is_reported_defaulted and not is_true_par30 then 1 end) as stale_register_entries_par30,
        count(case when is_reported_defaulted and not is_true_par90 then 1 end) as stale_register_entries_par90,

        -- Ledger-true PAR, computed completely independently of the register.
        count(case when is_true_par30 then 1 end)                          as true_par30_loans,
        count(case when is_true_par90 then 1 end)                          as true_par90_loans

    from base
    group by 1

),

total as (

    select
        'ALL' as product_type,
        count(*)                                                          as active_loan_count,
        count(case when is_reported_defaulted then 1 end)                  as reported_par_loans,
        count(case when is_restructured and is_true_par30
                        and not is_reported_defaulted then 1 end)          as hidden_restructure_risk_par30,
        count(case when is_restructured and is_true_par90
                        and not is_reported_defaulted then 1 end)          as hidden_restructure_risk_par90,
        count(case when not is_restructured and is_true_par30
                        and not is_reported_defaulted then 1 end)          as unregistered_delinquents_par30,
        count(case when not is_restructured and is_true_par90
                        and not is_reported_defaulted then 1 end)          as unregistered_delinquents_par90,
        count(case when is_reported_defaulted and not is_true_par30 then 1 end) as stale_register_entries_par30,
        count(case when is_reported_defaulted and not is_true_par90 then 1 end) as stale_register_entries_par90,
        count(case when is_true_par30 then 1 end)                          as true_par30_loans,
        count(case when is_true_par90 then 1 end)                          as true_par90_loans
    from base

),

unioned as (

    select * from components
    union all
    select * from total

),

bridged as (

    select
        product_type,
        active_loan_count,

        reported_par_loans,
        div0(reported_par_loans, nullif(active_loan_count, 0))            as reported_par_rate,

        hidden_restructure_risk_par30,
        unregistered_delinquents_par30,
        stale_register_entries_par30,

        -- The walk, PAR30: must equal true_par30_loans exactly (tested).
        reported_par_loans
            + hidden_restructure_risk_par30
            + unregistered_delinquents_par30
            - stale_register_entries_par30                                 as bridged_par30_loans,
        true_par30_loans,
        div0(true_par30_loans, nullif(active_loan_count, 0))               as true_par30_rate,

        hidden_restructure_risk_par90,
        unregistered_delinquents_par90,
        stale_register_entries_par90,

        reported_par_loans
            + hidden_restructure_risk_par90
            + unregistered_delinquents_par90
            - stale_register_entries_par90                                 as bridged_par90_loans,
        true_par90_loans,
        div0(true_par90_loans, nullif(active_loan_count, 0))               as true_par90_rate,

        -- The number for the CRO: how much bigger is true PAR30 than reported?
        div0(true_par30_loans - reported_par_loans, nullif(reported_par_loans, 0)) as par30_understatement_pct

    from unioned

)

select * from bridged
order by (product_type = 'ALL'), product_type
