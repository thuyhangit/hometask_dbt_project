-- stg_src_timesheet_entries: Staging wrapper for raw.src_timesheet_entries.
-- Filters to approved entries only — unapproved work never reaches the fact.

with source as (

    select * from {{ source('raw_profitability', 'src_timesheet_entries') }}

)

select
    entry_id,
    project_id,
    employee_id,
    entry_date,
    hours,
    is_billable,
    hourly_rate_usd,
    is_approved,
    approved_at,
    created_at

from source

where is_approved = true
