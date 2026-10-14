WITH session_performance AS (

    SELECT
        session_id,
        user_pseudo_id,
        ga_session_id,
        first_user_source,
        first_user_medium,
        first_user_campaign,
        session_start_at

    FROM {{ ref('fct_marketing_sessions') }}

),

purchase_performance AS (

    SELECT
        user_pseudo_id,
        ga_session_id,
        COUNT(*) AS purchased_items,
        COUNT(DISTINCT ga_session_id) AS purchasing_sessions,
        SUM(item_revenue) AS revenue

    FROM {{ ref('fct_ecommerce_items') }}

    GROUP BY
        user_pseudo_id,
        ga_session_id

),

acquisition_metrics AS (

    SELECT
        s.first_user_source,
        s.first_user_medium,
        s.first_user_campaign,

        COUNT(DISTINCT s.user_pseudo_id) AS users,
        COUNT(DISTINCT s.session_id) AS sessions,

        COALESCE(SUM(p.purchased_items), 0) AS purchased_items,
        COALESCE(SUM(p.purchasing_sessions), 0) AS purchasing_sessions,
        COALESCE(SUM(p.revenue), 0) AS revenue

    FROM session_performance s

    LEFT JOIN purchase_performance p
        ON s.user_pseudo_id = p.user_pseudo_id
        AND s.ga_session_id = p.ga_session_id

    GROUP BY
        s.first_user_source,
        s.first_user_medium,
        s.first_user_campaign

)

SELECT
    first_user_source,
    first_user_medium,
    first_user_campaign,

    users,
    sessions,
    purchasing_sessions,
    purchased_items,
    revenue,

    SAFE_DIVIDE(purchasing_sessions, sessions) AS conversion_rate,

    SAFE_DIVIDE(revenue, users) AS revenue_per_user,

    SAFE_DIVIDE(revenue, sessions) AS revenue_per_session

FROM acquisition_metrics