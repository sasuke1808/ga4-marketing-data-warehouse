SELECT
    event_date,
    event_timestamp,
    event_name,
    user_pseudo_id,
    ga_session_id,

    item.item_id,
    item.item_name,
    item.item_brand,
    item.item_category,
    item.price_in_usd,
    item.quantity,
    item.item_revenue

FROM {{ ref('stg_ga4_events') }},
UNNEST(items) AS item

WHERE event_name = 'purchase'