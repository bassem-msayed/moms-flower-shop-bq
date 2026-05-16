# Develop checkpoint

## Model requirements (minimum)

### `stg_flower_orders`

### `fct_customer_funnel`
**Grain:** one row per `customer_id`.

Must include first timestamps (per customer):
- `first_page_hit_time`
- `first_add_to_cart_time`
- `first_go_to_checkout_time`
- `first_place_order_time`

Must include:
- `reached_checkout` (true when checkout timestamp exists)
- `placed_order` (true when place order timestamp exists)
- `time_to_order_seconds` (difference between first page hit and first place order)
- `platform` (platform at `place_order` if present, else from latest event)

*(Optional)* Join `stg_flower_orders` to validate `place_order` events 
roughly match orders, and to pull `order_value` if desired.

### *(Optional)* `mart_platform_funnel_metrics`
Aggregate `fct_customer_funnel` by `platform`:
- `customers_reached_checkout`
- `customers_placed_order`
- `conversion_rate` = placed / reached_checkout
- `avg_time_to_order_seconds` (only for customers who placed an order)