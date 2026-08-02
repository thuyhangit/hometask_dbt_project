-- fct_timesheet_monthly: Monthly project profitability fact table.
-- Grain: one row per (project_key, employee_key, report_month).
--
-- Role-at-time-of-work: each timesheet entry is joined to dim_employee
-- using the entry_date against the employee version's valid_from/valid_to
-- range. This ensures the employee's role and team at the time of work
-- is captured, not their current attributes.

{{ config(materialized='table') }}

with timesheets as (

    select * from {{ ref('stg_src_timesheet_entries') }}

),

dim_emp as (

    select * from {{ ref('dim_employee') }}

),

dim_proj as (

    select * from {{ ref('dim_project') }}

),

-- Join each timesheet entry to the correct employee version
-- based on the entry_date falling within the version's validity window.
entries_with_employee_version as (

    select
        ts.entry_id,
        ts.project_id,
        ts.employee_id,
        ts.entry_date,
        ts.hours,
        ts.is_billable,
        ts.hourly_rate_usd,

        -- SCD2 join: pick the employee version active on the entry date
        de.employee_key

    from timesheets ts
    inner join dim_emp de
        on  ts.employee_id = de.employee_id
        and ts.entry_date >= de.valid_from::date
        and ts.entry_date <  de.valid_to::date

),

-- Aggregate to monthly grain
monthly_agg as (

    select
        e.project_id                                            as project_key,
        e.employee_key,
        date_trunc('month', e.entry_date)::date                 as report_month,

        sum(case when e.is_billable then e.hours else 0 end)    as billable_hours,
        sum(case when not e.is_billable then e.hours else 0 end) as non_billable_hours,
        sum(e.hours)                                            as total_hours,
        sum(case when e.is_billable
            then e.hours * e.hourly_rate_usd else 0 end)        as revenue_usd

    from entries_with_employee_version e

    group by
        e.project_id,
        e.employee_key,
        date_trunc('month', e.entry_date)::date

),

-- Enrich with project-level FKs for direct slicing
enriched as (

    select
        ma.project_key,
        ma.employee_key,
        ma.report_month,
        dp.client_id        as client_key,
        dp.office_id        as office_key,
        ma.billable_hours,
        ma.non_billable_hours,
        ma.total_hours,
        ma.revenue_usd

    from monthly_agg ma
    inner join dim_proj dp
        on ma.project_key = dp.project_key

)

select * from enriched
