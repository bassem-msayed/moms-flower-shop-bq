{{config(severity='warn')}}

/* Ensure that the first page hit time is not after the first place order time.
 There's a known issue where ~15 lines have a first page hit time that is after the first place order time
 This is resolved in marts by a case statement, and the severity of this test is set to warn accordingly.
 */
select
    customer_id

from {{ref('fct_customer_funnel')}}

where
    first_place_order_time is not null
    and first_page_hit_time > first_place_order_time