-- Ensure that the time from page hit to order is never negative.
select
        customer_id

from {{ref('fct_customer_funnel')}}

where time_to_place_order < 0