-- ASSUMPTION (see assumptions_log.md A5): the servicing gateway occasionally
-- double-posts a settled repayment (same loan, same instalment, same amount,
-- minutes apart). We treat this as a duplicate EVENT and keep the
-- earliest-settled posting per (loan_id, instalment_no) among non-missed
-- rows. The dropped duplicate is flagged, not deleted, so cash inflow is
-- never silently double-counted into a loan's cumulative-paid total (which
-- would understate outstanding balance and could wrongly clear a delinquent
-- instalment).
--
-- "missed" rows are never deduped against — a loan only gets one scheduler-
-- written missed row per instalment by construction, and missed rows carry
-- no cash, so there is nothing to double count.

with repayments as (

    select * from {{ ref('stg_repayments') }}

),

postings as (

    select
        *,
        row_number() over (
            partition by loan_id, instalment_no
            order by paid_at asc, repayment_id asc
        ) as settle_rank
    from repayments
    where payment_status in ('posted', 'partial')

),

deduped_postings as (

    select
        repayment_id, loan_id, instalment_no, scheduled_amount, amount_paid,
        currency_code, payment_status, due_date, paid_at,
        false as is_duplicate_posting
    from postings
    where settle_rank = 1

),

dropped_duplicates as (

    select
        repayment_id, loan_id, instalment_no, scheduled_amount, amount_paid,
        currency_code, payment_status, due_date, paid_at,
        true as is_duplicate_posting
    from postings
    where settle_rank > 1

),

missed as (

    select
        repayment_id, loan_id, instalment_no, scheduled_amount, amount_paid,
        currency_code, payment_status, due_date, paid_at,
        false as is_duplicate_posting
    from repayments
    where payment_status = 'missed'

)

select * from deduped_postings
union all
select * from dropped_duplicates   -- kept, flagged true, excluded downstream by filter
union all
select * from missed
