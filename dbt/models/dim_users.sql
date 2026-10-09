SELECT
    user_pseudo_id,

    MIN(event_timestamp) AS first_seen_at,
    MAX(event_timestamp) AS last_seen_at,

    COUNT(*) AS total_events,

    COUNTIF(event_name = 'purchase') AS total_purchases

FROM {{ ref('stg_ga4_events') }}

WHERE user_pseudo_id IS NOT NULL

GROUP BY user_pseudo_id