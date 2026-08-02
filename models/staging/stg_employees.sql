-- stg_employees: Thin staging wrapper over the raw employees table.
-- Renames columns to snake_case.

with source as (

    select * from {{ source('raw', 'employees') }}

),

renamed as (

    select
        employeeid    as employee_id,
        employeename  as employee_name,
        department,
        role,
        teamcode      as team_code,
        isactive      as is_active

    from source

)

select * from renamed
