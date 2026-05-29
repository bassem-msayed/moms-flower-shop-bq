-- Testing that all customer with orders are present in the customer table, and that there are no customers with orders that are not in the customer table.
select
    customer_id

from {{ref('fct_customer_funnel')}}

where customer_id 
    not in (
        select distinct customer_id 
        from {{ref('stg_mfs__customers')}}
        where customer_id is not null
    )
