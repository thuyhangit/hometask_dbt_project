-- Custom business-rule test: No employee should log more than 24 hours
-- on a single day. This catches data quality issues in timesheet entries.
-- If this query returns any rows, the test fails.

select
    employee_id,
    entry_date,
    sum(hours) as total_daily_hours

from {{ ref('stg_src_timesheet_entries') }}

group by employee_id, entry_date

having sum(hours) > 24
