-- Piece 1: one row per session, with funnel flags (1 = did it, 0 = didn't)
WITH session_funnel AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        DATE(MIN(event_timestamp)) AS session_date,

        MAX(IF(event_name = 'view_item', 1, 0))      AS viewed_item,
        MAX(IF(event_name = 'add_to_cart', 1, 0))    AS added_to_cart,
        MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
        MAX(IF(event_name = 'purchase', 1, 0))       AS purchased

    FROM {{ ref('stg_ga4_events') }}
    WHERE ga_session_id IS NOT NULL
    GROUP BY user_pseudo_id, ga_session_id

),

-- Piece 2: revenue per session
session_revenue AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        SUM(item_revenue) AS revenue

    FROM {{ ref('fct_ecommerce_items') }}
    GROUP BY user_pseudo_id, ga_session_id

),

-- Piece 3: marketing source per session
session_source AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        COALESCE(first_user_source, '(not set)') AS source,
        COALESCE(first_user_medium, '(not set)') AS medium

    FROM {{ ref('fct_marketing_sessions') }}

)

-- Final: one row per day + source + medium
SELECT
    f.session_date,
    s.source,
    s.medium,

    COUNT(DISTINCT f.user_pseudo_id) AS users,
    COUNT(*)                         AS sessions,

    SUM(f.viewed_item)    AS view_item_sessions,
    SUM(f.added_to_cart)  AS add_to_cart_sessions,
    SUM(f.began_checkout) AS checkout_sessions,
    SUM(f.purchased)      AS purchase_sessions,

    COALESCE(SUM(r.revenue), 0) AS revenue,

    SAFE_DIVIDE(SUM(f.purchased), COUNT(*)) AS conversion_rate

FROM session_funnel AS f
LEFT JOIN session_revenue AS r
    ON  f.user_pseudo_id = r.user_pseudo_id
    AND f.ga_session_id  = r.ga_session_id
LEFT JOIN session_source AS s
    ON  f.user_pseudo_id = s.user_pseudo_id
    AND f.ga_session_id  = s.ga_session_id

GROUP BY
    f.session_date,
    s.source,
    s.medium