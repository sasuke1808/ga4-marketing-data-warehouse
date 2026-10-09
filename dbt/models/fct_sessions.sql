SELECT
    CONCAT(
        user_pseudo_id,
        '-',
        CAST(ga_session_id AS STRING)
    ) AS session_id,

    user_pseudo_id,
    ga_session_id,

    MIN(event_timestamp) AS session_start_at,
    MAX(event_timestamp) AS session_end_at,

    COUNT(*) AS total_events,

    COUNTIF(event_name = 'page_view') AS page_views,
    COUNTIF(event_name = 'purchase') AS purchases

FROM {{ ref('stg_ga4_events') }}

WHERE ga_session_id IS NOT NULL

GROUP BY
    user_pseudo_id,
    ga_session_id