-- dim_date: Monthly date dimension.
-- Generated date spine at monthly grain using PostgreSQL generate_series.
-- Covers 10 years (2020–2030) — extend as needed.

{{ config(materialized='table') }}

with date_spine as (

    select
        generate_series(
            '2020-01-01'::date,
            '2030-12-01'::date,
            '1 month'::interval
        )::date as date_month

)

select
    date_month                                          as date_key,
    date_month                                          as report_month,
    extract(year from date_month)::int                  as year,
    extract(month from date_month)::int                 as month_number,
    to_char(date_month, 'Month')                        as month_name,
    to_char(date_month, 'Mon')                          as month_short,
    extract(quarter from date_month)::int               as quarter,
    'Q' || extract(quarter from date_month)::int        as quarter_name,
    (extract(year from date_month)::int * 100
     + extract(month from date_month)::int)             as year_month_int,
    to_char(date_month, 'YYYY-MM')                      as year_month_str

from date_spine
