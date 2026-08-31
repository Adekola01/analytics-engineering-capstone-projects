{{ config(materialized='table') }}

-- Risk-ready portfolio metrics (BRIEF.md deliverable #2). One row per
-- product_type, plus one 'ALL' row for the whole book. The book is a single
-- as-of snapshot (see var('as_of_date')) rather than a time series, so this
-- is the segmentation cut Credit Risk and Collections actually want: "how
-- does PAR break down by product."

with base as (

    select * from {{ ref('fct_loan_performance') }}

),

by_product as (

    select
        product_type,
        count(*)                                                            as active_loan_count,
        sum(outstanding_balance_estimate)                                   as active_outstanding_value,

        count(case when is_true_par30 then 1 end)                           as par30_loan_count,
        sum(case when is_true_par30 then outstanding_balance_estimate else 0 end) as par30_outstanding_value,

        count(case when is_true_par90 then 1 end)                           as par90_loan_count,
        sum(case when is_true_par90 then outstanding_balance_estimate else 0 end) as par90_outstanding_value,

        count(case when is_reported_defaulted then 1 end)                   as reported_default_loan_count,
        count(case when is_restructured then 1 end)                        as restructured_loan_count,
        count(case when is_hidden_restructure_risk then 1 end)              as hidden_restructure_risk_count,

        sum(instalments_partial_count)                                      as total_partial_instalments,
        sum(instalments_due_count)                                          as total_instalments_due

    from base
    group by 1

),

total as (

    select
        'ALL' as product_type,
        count(*)                                                            as active_loan_count,
        sum(outstanding_balance_estimate)                                   as active_outstanding_value,

        count(case when is_true_par30 then 1 end)                           as par30_loan_count,
        sum(case when is_true_par30 then outstanding_balance_estimate else 0 end) as par30_outstanding_value,

        count(case when is_true_par90 then 1 end)                           as par90_loan_count,
        sum(case when is_true_par90 then outstanding_balance_estimate else 0 end) as par90_outstanding_value,

        count(case when is_reported_defaulted then 1 end)                   as reported_default_loan_count,
        count(case when is_restructured then 1 end)                        as restructured_loan_count,
        count(case when is_hidden_restructure_risk then 1 end)              as hidden_restructure_risk_count,

        sum(instalments_partial_count)                                      as total_partial_instalments,
        sum(instalments_due_count)                                          as total_instalments_due

    from base

),

unioned as (

    select * from by_product
    union all
    select * from total

)

select
    product_type,
    active_loan_count,
    active_outstanding_value,

    par30_loan_count,
    div0(par30_loan_count, nullif(active_loan_count, 0))          as par30_rate_by_count,
    par30_outstanding_value,
    div0(par30_outstanding_value, nullif(active_outstanding_value, 0)) as par30_rate_by_value,

    par90_loan_count,
    div0(par90_loan_count, nullif(active_loan_count, 0))          as par90_rate_by_count,
    par90_outstanding_value,
    div0(par90_outstanding_value, nullif(active_outstanding_value, 0)) as par90_rate_by_value,

    reported_default_loan_count,
    div0(reported_default_loan_count, nullif(active_loan_count, 0)) as reported_default_rate,

    restructured_loan_count,
    div0(restructured_loan_count, nullif(active_loan_count, 0))   as restructure_rate,

    hidden_restructure_risk_count,

    div0(total_partial_instalments, nullif(total_instalments_due, 0)) as partial_payment_rate

from unioned
order by (product_type = 'ALL'), product_type
