-- fct_project_monthly: Monthly project-level fact table.
-- Joins active projects, monthly hours, and employee attributes.
-- Replaces the final INSERT INTO dbo.FactProjectMonthly in the original SP.

{{ config(materialized='table') }}


with active_projects as (

    select * from {{ ref('int_active_projects') }}

),

monthly_hours as (

    select * from {{ ref('int_monthly_hours') }}

),

employee_snapshot as (

    select * from {{ ref('int_employee_snapshot') }}

),

fact as (

    select
        {{ var('snapshot_month') }}  as snapshot_month,
        ap.project_id,
        mh.employee_id,
        ap.client_id,
        ap.office_id,
        es.department,
        es.role,
        mh.billable_hours,
        mh.non_billable_hours,
        mh.revenue_usd,
        ap.budget_usd / 12.0       as monthly_budget_usd

    from active_projects ap
    inner join monthly_hours mh
        on ap.project_id = mh.project_id
    left join employee_snapshot es
        on mh.employee_id = es.employee_id

)

select * from fact