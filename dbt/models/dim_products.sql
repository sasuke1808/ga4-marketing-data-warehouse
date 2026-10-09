WITH product_records AS (

    SELECT
        item.item_id,
        item.item_name,
        item.item_brand,
        item.item_category,
        item.price_in_usd,
        event_timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY item.item_id
            ORDER BY event_timestamp DESC
        ) AS row_num

    FROM {{ ref('stg_ga4_events') }},
    UNNEST(items) AS item

    WHERE item.item_id IS NOT NULL
)

SELECT
    item_id,
    item_name,
    item_brand,
    item_category,
    price_in_usd

FROM product_records

WHERE row_num = 1