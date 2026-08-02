-- dim_employee: SCD Type 2 employee dimension.
-- One row per employee VERSION. The source already provides change history
-- (valid_from / valid_to), so we consume it directly rather than capturing it.
-- The employee_key (= employee_version_id) is the surrogate key used by the fact.

{{ config(materialized='table') }}

with employees as (

    select * from {{ ref('stg_src_employees') }}

)

select
    employee_version_id  as employee_key,
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
    valid_to,
    is_current

from employees
