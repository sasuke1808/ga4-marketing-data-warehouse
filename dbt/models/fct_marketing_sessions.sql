WITH session_events AS (

    SELECT
        CONCAT(
            user_pseudo_id,
            '-',
            CAST(ga_session_id AS STRING)
        ) AS session_id,

        user_pseudo_id,
        ga_session_id,
        event_timestamp,

        traffic_source AS first_user_source,
        traffic_medium AS first_user_medium,
        traffic_campaign AS first_user_campaign,

        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, ga_session_id
            ORDER BY event_timestamp
        ) AS event_rank

    FROM {{ ref('stg_ga4_events') }}

    WHERE ga_session_id IS NOT NULL
)

SELECT
    session_id,
    user_pseudo_id,
    ga_session_id,
    first_user_source,
    first_user_medium,
    first_user_campaign,
    event_timestamp AS session_start_at

FROM session_events

WHERE event_rank = 1