-- Questions by platform:
-- 1. Customer who reach the checkout page
-- 2. Customer who complete the purchase
-- 3. Conversion rate & average time to order

with funnel as(
    select
        platform,
        reached_checkout,
        placed_order,
        time_to_place_order
    
    from {{ ref ('fct_customer_funnel') }}
),
final as(
    select
        coalesce(platform, 'Unknown') as platform,
        count(reached_checkout) as reached_checkout,
        count(placed_order) as placed_order,
        
        round(
            safe_divide(
                countif(placed_order),
                nullif(
                    countif(reached_checkout),
                    0
                )
            ), 
        2) as conversion_rate,

        round(
            avg(
                if(
                    placed_order, 
                    time_to_place_order, 
                    null)
            ),
        2) as avg_time_to_order_seconds
    
    from funnel
    group by 1
)

select * from final