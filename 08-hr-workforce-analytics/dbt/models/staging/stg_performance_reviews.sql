-- Staging: 1:1 with RAW_PERFORMANCE_REVIEWS. Light renaming/casting only.

with source as (

    select * from {{ source('raw', 'raw_performance_reviews') }}

),

renamed as (

    select
        review_id,
        employee_id,
        person_id,
        review_period,
        lower(trim(rating))        as rating,
        review_score,
        reviewer_id,
        review_date

    from source

)

select * from renamed
