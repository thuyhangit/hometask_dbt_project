-- dim_client: Client dimension derived from projects.
-- One row per distinct client_id. In a production system this would
-- reference a dedicated clients source table with name, industry, etc.

{{ config(materialized='table') }}

with projects as (

    select * from {{ ref('stg_src_projects') }}

)

select distinct
    client_id   as client_key,
    client_id,
    null::varchar(200) as client_name  -- placeholder; populate from a dedicated clients source

from projects

where client_id is not null
