-- int_employee_snapshot: Current active employees with their attributes.
-- Replaces the #EmployeeSnapshot temp table in the original SP.

with employees as (

    select * from {{ ref('stg_employees') }}

)

select
    employee_id,
    employee_name,
    department,
    role,
    team_code

from employees

where is_active = 1
