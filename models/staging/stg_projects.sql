-- stg_projects: Thin staging wrapper over the raw projects table.
-- Renames columns to snake_case and coalesces budget to 0.


with source as (

    select * from {{ source('raw', 'projects') }}

),

renamed as (

    select
        projectid       as project_id,
        projectcode     as project_code,
        projectname     as project_name,
        clientid        as client_id,
        pmuserid        as pm_user_id,
        officeid        as office_id,
        coalesce(budgetusd, 0) as budget_usd,
        status,
        closeddate      as closed_date

    from source

)

select * from renamed