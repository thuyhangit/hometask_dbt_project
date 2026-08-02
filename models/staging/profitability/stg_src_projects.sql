-- stg_src_projects: Staging wrapper for raw.src_projects.
-- Columns are already snake_case; coalesce budget to 0.

with source as (

    select * from {{ source('raw_profitability', 'src_projects') }}

)

select
    project_id,
    project_code,
    project_name,
    client_id,
    project_manager_id,
    office_id,
    start_date,
    planned_end_date,
    actual_end_date,
    coalesce(budget_usd, 0) as budget_usd,
    status,
    updated_at

from source
