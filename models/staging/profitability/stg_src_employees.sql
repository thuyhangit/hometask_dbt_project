-- stg_src_employees: Staging wrapper for raw.src_employees.
-- Preserves SCD Type 2 history. Fills valid_to sentinel for easier joins.

with source as (

    select * from {{ source('raw_profitability', 'src_employees') }}

)

select
    employee_version_id,
    employee_id,
    employee_code,
    full_name,
    email,
    department,
    role,
    team_code,
    hire_date,
    termination_date,
    valid_from,
    -- Replace NULL valid_to with far-future sentinel for range joins
    coalesce(valid_to, '9999-12-31'::timestamp) as valid_to,
    is_current

from source
