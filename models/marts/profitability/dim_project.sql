-- dim_project: Type 1 project dimension.
-- One row per project. Uses project_id as natural key.

{{ config(materialized='table') }}

with projects as (

    select * from {{ ref('stg_src_projects') }}

)

select
    project_id      as project_key,
    project_id,
    project_code,
    project_name,
    client_id,
    project_manager_id,
    office_id,
    start_date,
    planned_end_date,
    actual_end_date,
    budget_usd,
    status,
    updated_at

from projects
