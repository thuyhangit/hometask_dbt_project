-- int_active_projects: Projects that are active, on hold,
-- or closed within 3 months of the snapshot month.
-- Replaces the #ActiveProjects temp table in the original SP.

{% set snapshot_month = var('snapshot_month') %}
{% set year_part  = snapshot_month // 100 %}
{% set month_part = snapshot_month % 100 %}


with projects as (

    select * from {{ ref('stg_projects') }}

)

select
    project_id,
    project_code,
    project_name,
    client_id,
    pm_user_id,
    office_id,
    budget_usd,
    status

from projects

where status in ('Active', 'OnHold')
   or (status = 'Closed'
       and closed_date >= make_date({{ year_part }}, {{ month_part }}, 1) - interval '3 months')