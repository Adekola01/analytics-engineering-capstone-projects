-- ASSUMPTION: the review cycle occasionally re-submits, producing a
-- duplicate REVIEW_ID for an identical review. Dedupe to the earliest
-- REVIEW_ID per (employee_id, review_period, rating, review_score), flag
-- the dropped duplicate. Reviews tied to a deduped-away employee_id (the
-- migration double-load) are flagged (is_orphaned_review) and excluded
-- from performance-history rollups.

with reviews as (

    select * from {{ ref('stg_performance_reviews') }}

),

employees as (

    select employee_id, is_duplicate_record
    from {{ ref('int_employees_deduped') }}

),

ranked as (

    select
        r.*,
        row_number() over (
            partition by r.employee_id, r.review_period, r.rating, r.review_score
            order by r.review_id asc
        )                                               as dedup_rank,
        coalesce(e.is_duplicate_record, true)            as is_orphaned_review
    from reviews r
    left join employees e on r.employee_id = e.employee_id

)

select
    review_id, employee_id, person_id, review_period, rating, review_score,
    reviewer_id, review_date,
    (dedup_rank > 1)      as is_duplicate_review,
    is_orphaned_review,
    (review_date is null) as is_missing_review_date
from ranked
