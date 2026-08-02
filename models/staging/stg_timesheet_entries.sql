-- stg_timesheet_entries: Thin staging wrapper over the raw timesheet_entries table.
-- Renames columns to snake_case and casts boolean flags.

with source as (

    select * from {{ source('raw', 'timesheet_entries') }}

),

renamed as (

    select
        projectid    as project_id,
        employeeid   as employee_id,
        entrydate    as entry_date,
        hours,
        hourlyrate   as hourly_rate,
        isbillable   as is_billable,
        isapproved   as is_approved

    from source

)

select * from renamed
