-- One row per product: units sold, revenue and number of purchase sessions
SELECT
    i.item_id,
    p.item_name,
    p.item_category,

    SUM(i.quantity)     AS units_sold,
    SUM(i.item_revenue) AS revenue,

    COUNT(DISTINCT CONCAT(i.user_pseudo_id, '-', CAST(i.ga_session_id AS STRING)))
        AS purchase_sessions

FROM {{ ref('fct_ecommerce_items') }} AS i
LEFT JOIN {{ ref('dim_products') }} AS p
    ON i.item_id = p.item_id

WHERE i.item_id IS NOT NULL

GROUP BY
    i.item_id,
    p.item_name,
    p.item_category