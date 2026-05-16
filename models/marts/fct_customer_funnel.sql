with events as(
    select
        customer_id,
        event_name,
        platform,
        event_time_utc,
        event_date
    from {{ ref('stg_mfs__website_events') }}
),

firsts as (
    select
        customer_id,
        min(event_time_utc) as earliest_event_time,
        -- ↓ This was found to have nulls, not acceptable, need to invetigate, a workaround introduced below
        min(if(event_name = 'page_hit', event_time_utc, null)) as first_page_hit_time_raw, 
        min(if(event_name = 'add_to_cart', event_time_utc, null)) as first_add_to_cart_time,
        min(if(event_name = 'go_to_checkout', event_time_utc, null)) as first_go_to_checkout_time,
        min(if(event_name = 'place_order', event_time_utc, null)) as first_place_order_time
    from events
    group by customer_id
),

avg_seconds_from_page_hit_to_cart as (
    select
        avg(
            timestamp_diff(
                first_add_to_cart_time,
                first_page_hit_time_raw,
                second)
        ) as avg_seconds_to_cart
    from firsts
    where 
        first_page_hit_time_raw is not null 
        and 
        first_add_to_cart_time is not null
),

firsts_with_fallback as (
    select
        f.customer_id,
        f.first_page_hit_time_raw,
        
        -- ↓ If first_page_hit_time_raw is null, assume the average gap between page hit and add to cart.
        coalesce(
            f.first_page_hit_time_raw,
            timestamp_sub(f.first_add_to_cart_time, interval cast(a.avg_seconds_to_cart as int64) second),
            f.earliest_event_time  -- ← final safety net
        ) as first_page_hit_time,
        f.first_add_to_cart_time,
        f.first_go_to_checkout_time,
        f.first_place_order_time
    from firsts f
    cross join avg_seconds_from_page_hit_to_cart a
),

latest_platform as (
    select
        customer_id,
        platform as latest_platform
    from (
        select
            customer_id,
            platform,
            row_number() over (
                partition by customer_id 
                order by event_time_utc desc
                ) as rn
        from events
    )
    where rn = 1
),
platform_at_order as (
    select
        customer_id,
        platform as platform_at_order
    from (
        select
            customer_id,
            platform,
            row_number() over (
                partition by customer_id 
                order by event_time_utc desc
                ) as rn
        from events
        where event_name = 'place_order' and platform is not null
    )
    where rn = 1
),

final as(
    select
        -- ↓ Defining the final table grain, one row per customer
        f.customer_id,

        -- ↓ Timestamps for each funnel stage
        --f.earliest_event_time,
        f2.first_page_hit_time,
        f2.first_add_to_cart_time,
        f2.first_go_to_checkout_time,
        f2.first_place_order_time,
        
        -- ↓ Platform information
        cast(coalesce(l.latest_platform, p.platform_at_order) as string) as platform,

        /* ↓ Timedfference from page hit to place order, only for those who placed an order, otherwise null
        It would also consider the negative time in seconds & put a zero instead*/
        --cast(timestamp_diff(f2.first_place_order_time,f2.first_page_hit_time,second) as int64) as raw_time_to_place_order,
        case
            when cast(timestamp_diff(f2.first_place_order_time,f2.first_page_hit_time,second) as int64) < 0 then 0
            else cast(timestamp_diff(f2.first_place_order_time,f2.first_page_hit_time,second) as int64)
        end as time_to_place_order,

         -- ↓ Boolean flags for funnel progression
        cast(f2.first_go_to_checkout_time is not null as bool) as reached_checkout,
        cast(f2.first_place_order_time is not null as bool) as placed_order

    from firsts f
    left join firsts_with_fallback f2 using (customer_id)
    left join latest_platform l using (customer_id) 
    left join platform_at_order p using (customer_id)
)

select * from final