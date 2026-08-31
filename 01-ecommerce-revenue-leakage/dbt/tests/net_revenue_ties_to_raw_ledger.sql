{{ config(severity='error', tags=['business_rule']) }}

-- BUSINESS RULE (RUBRIC.md, non-negotiable): "The numbers must tie out."
-- sum(net_revenue) across all of fct_revenue must equal:
--     sum(deduped succeeded payments) - sum(all completed refunds)
-- computed directly from the (near-)raw staging ledger, independent of the
-- mart's own arithmetic. This is the check that catches a bug in fct_revenue
-- itself, not just a bridge/mart mismatch.
--
-- Fails in prod: hard stop. This is THE number that goes to the board; if it
-- doesn't tie to the ledger, nothing ships until it's fixed.

with ledger as (

    select
        (select sum(amount) from {{ ref('int_payments_deduped') }}
         where payment_status = 'succeeded' and is_duplicate_settlement = false)
        -
        (select sum(refund_amount) from {{ ref('stg_refunds') }}
         where refund_status = 'completed')                          as ledger_net_revenue

),

mart as (

    select sum(net_revenue) as mart_net_revenue
    from {{ ref('fct_revenue') }}

)

select
    ledger.ledger_net_revenue,
    mart.mart_net_revenue,
    abs(ledger.ledger_net_revenue - mart.mart_net_revenue) as diff
from ledger
cross join mart
where abs(ledger.ledger_net_revenue - mart.mart_net_revenue) > 1.00
