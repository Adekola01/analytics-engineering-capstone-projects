{{ config(materialized='table') }}

-- Finance-ready monthly metrics. Each metric has a single, written definition
-- (see docs/business_metric_definitions.md for the full contract). This is
-- the table that goes on the board deck.

with revenue as (

    select * from {{ ref('fct_revenue') }}

),

monthly as (

    select
        revenue_recognition_month                              as report_month,

        -- Gross revenue: sum of deduped settled payments recognized this month.
        sum(gross_revenue)                                      as gross_revenue,

        -- Refunds processed in-month, regardless of which month the original
        -- order/payment happened in (cash-basis netting, per Finance's own logic).
        sum(case when date_trunc('month', last_refund_processed_at) = revenue_recognition_month
                 then total_refunded else 0 end)                as refunds_same_month,

        -- Net revenue: gross minus ALL refunds ever tied to a payment recognized
        -- this month (i.e. lifetime refund against the order, not just same-month).
        -- This is the number that ties out to the raw ledger (see reconciliation test).
        sum(net_revenue)                                        as net_revenue,

        -- Refund rate: refunds as a share of gross revenue this month.
        div0(sum(total_refunded), nullif(sum(gross_revenue), 0)) as refund_rate,

        -- Cancellation leakage: cash collected on cancelled orders that was
        -- never refunded back to the customer. Actionable finding, not hidden
        -- inside net revenue.
        sum(cancellation_leakage_amount)                        as cancellation_leakage,

        -- Duplicate payments excluded (visibility metric — should be ~0 revenue
        -- impact because int_payments_deduped already excludes them from
        -- gross/net above; this shows *how much* would have been overcounted
        -- had we not deduped).
        sum(duplicate_payment_amount)                           as duplicate_payment_amount_excluded,

        count(*)                                                as orders_with_payment_activity,
        sum(case when is_unrefunded_cancellation_leakage then 1 else 0 end) as leakage_order_count

    from revenue
    where revenue_recognition_month is not null   -- unpaid orders have no recognition month
    group by 1

)

select * from monthly
order by report_month
