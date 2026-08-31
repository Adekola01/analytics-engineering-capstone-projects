-- THE repayment pipeline (BRIEF.md deliverable #4). Turns the deduped posting
-- feed into one row per loan with its TRUE days-past-due, computed entirely
-- from the ledger — never from RAW_LOANS.FIRST_DUE_DATE/LOAN_STATUS, which
-- reflect the servicer's post-restructure "current schedule" and are exactly
-- what hides risk (see assumptions_log.md A1/A2).
--
-- Definition: DPD = AS_OF_DATE minus the due_date of the OLDEST instalment
-- still showing payment_status = 'missed'. A loan with no missed instalments
-- has DPD = 0 (current). Partial postings are NOT missed instalments — a
-- short-paid instalment still clears that instalment's due_date for DPD
-- purposes (assumptions_log.md A3); its shortfall is tracked separately.

with repayments as (

    select * from {{ ref('int_repayments_deduped') }}
    where is_duplicate_posting = false   -- duplicates never feed cash totals or DPD

),

per_loan as (

    select
        loan_id,

        min(case when payment_status = 'missed' then due_date end)       as oldest_missed_due_date,
        count(distinct instalment_no)                                    as instalments_due_count,
        count(distinct case when payment_status = 'missed'
                             then instalment_no end)                     as instalments_missed_count,
        count(distinct case when payment_status = 'partial'
                             then instalment_no end)                     as instalments_partial_count,

        sum(case when payment_status in ('posted', 'partial')
                 then amount_paid else 0 end)                            as cumulative_amount_paid,
        sum(scheduled_amount)                                            as cumulative_scheduled_amount,

        sum(case when payment_status = 'partial'
                 then scheduled_amount - amount_paid else 0 end)         as cumulative_partial_shortfall,

        max(due_date)                                                    as most_recent_due_date

    from repayments
    group by 1

),

final as (

    select
        loan_id,
        instalments_due_count,
        instalments_missed_count,
        instalments_partial_count,
        cumulative_amount_paid,
        cumulative_scheduled_amount,
        cumulative_partial_shortfall,
        oldest_missed_due_date,
        most_recent_due_date,

        case
            when oldest_missed_due_date is null then 0
            else datediff('day', oldest_missed_due_date, cast('{{ var("as_of_date") }}' as date))
        end                                                              as true_dpd,

        div0(instalments_partial_count, nullif(instalments_due_count, 0)) as partial_rate

    from per_loan

)

select * from final
