-- int_monthly_hours: Aggregated approved timesheet hours for a given snapshot month.
-- Replaces the #MonthlyHours temp table in the original SP.
-- The snapshot month is passed via dbt variable: --vars '{"snapshot_month": 202410}'

{% set snapshot_month = var('snapshot_month') %}

{% set year_part  = snapshot_month // 100 %}
{% set month_part = snapshot_month % 100 %}

with timesheet_entries as (

    select * from {{ ref('stg_timesheet_entries') }}

),

month_boundaries as (

    select
        make_date({{ year_part }}, {{ month_part }}, 1) as month_start,
        (make_date({{ year_part }}, {{ month_part }}, 1)
            + interval '1 month' - interval '1 day')::date as month_end

),

filtered as (

    select
        ts.project_id,
        ts.employee_id,
        ts.hours,
        ts.hourly_rate,
        ts.is_billable

    from timesheet_entries ts
    cross join month_boundaries mb

    where ts.entry_date between mb.month_start and mb.month_end
      and ts.is_approved = 1

),

aggregated as (

    select
        project_id,
        employee_id,
        sum(case when is_billable = 1 then hours else 0 end) as billable_hours,
        sum(case when is_billable = 0 then hours else 0 end) as non_billable_hours,
        sum(hours * hourly_rate) as revenue_usd

    from filtered
    group by project_id, employee_id

)

select * from aggregated
