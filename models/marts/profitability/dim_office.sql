-- dim_office: Office dimension derived from projects.
-- One row per distinct office_id. In a production system this would
-- reference a dedicated offices source table with name, location, etc.

{{ config(materialized='table') }}

with projects as (

    select * from {{ ref('stg_src_projects') }}

)

select distinct
    office_id   as office_key,
    office_id,
    null::varchar(200) as office_name  -- placeholder; populate from a dedicated offices source

from projects

where office_id is not null
