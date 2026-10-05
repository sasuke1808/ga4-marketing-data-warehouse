-- GA4 Marketing Data Warehouse
-- Step 01: Explore raw GA4 data


-- 01. Count total events in one daily GA4 table

SELECT
    COUNT(*) AS event_rows
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`;

-- Result: 31,272 events

-- 02. Inspect event parameters
-- event_params is a repeated nested field.
-- UNNEST() expands the parameter array into individual rows.

SELECT
    event_name,
    ep.key,
    ep.value.string_value,
    ep.value.int_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`,
UNNEST(event_params) AS ep
LIMIT 20;

/*
Query output:

+-----------------+-----------------------+-----------------------------------------------------------------------------+------------+
|   event_name    |          key          |                                string_value                                 | int_value  |
+-----------------+-----------------------+-----------------------------------------------------------------------------+------------+
| page_view       | page_title            | Drinkware | Lifestyle | Google Merchandise Store                            |       NULL |
| page_view       | all_data              | NULL                                                                        |       NULL |
| page_view       | page_location         | https://shop.googlemerchandisestore.com/Google+Redesign/Lifestyle/Drinkware |       NULL |
| page_view       | ga_session_number     | NULL                                                                        |          1 |
| page_view       | clean_event           | gtm.js                                                                      |       NULL |
| page_view       | engaged_session_event | NULL                                                                        |          1 |
| page_view       | dclid                 | NULL                                                                        |       NULL |
| page_view       | session_engaged       | 0                                                                           |       NULL |
| page_view       | ga_session_id         | NULL                                                                        | 4863244888 |
| page_view       | debug_mode            | NULL                                                                        |          1 |
| page_view       | entrances             | NULL                                                                        |          1 |
| first_visit     | session_engaged       | NULL                                                                        |          1 |
| first_visit     | ga_session_number     | NULL                                                                        |          1 |
| first_visit     | page_location         | https://shop.googlemerchandisestore.com/Google+Redesign/Lifestyle/Drinkware |       NULL |
| first_visit     | ga_session_id         | NULL                                                                        | 4863244888 |
| first_visit     | engaged_session_event | NULL                                                                        |          1 |
| first_visit     | page_title            | Drinkware | Lifestyle | Google Merchandise Store                            |       NULL |
| user_engagement | dclid                 | NULL                                                                        |       NULL |
| user_engagement | page_title            | Drinkware | Lifestyle | Google Merchandise Store                            |       NULL |
| user_engagement | engagement_time_msec  | NULL                                                                        |       9215 |
+-----------------+-----------------------+-----------------------------------------------------------------------------+------------+
*/

-- 03. Measure row multiplication after UNNEST()
-- The raw table is at event grain: 1 row = 1 event.
-- UNNEST(event_params) expands each event's parameters
-- into separate rows.

SELECT
    COUNT(*) AS unnested_rows
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`,
UNNEST(event_params) AS ep;

/*
Query output:

337,957 parameter rows

Observation:
31,272 event rows expanded to 337,957 parameter rows
after UNNEST(event_params).
*/

-- 04. Extract ga_session_id without changing event grain
-- A correlated subquery is used to retrieve one parameter
-- while keeping 1 row = 1 event.

SELECT
    event_name,
    user_pseudo_id,

    (
        SELECT value.int_value
        FROM UNNEST(event_params)
        WHERE key = 'ga_session_id'
    ) AS ga_session_id

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`
LIMIT 10;

/*
Query output:

+-----------------+--------------------+---------------+
|   event_name    |   user_pseudo_id   | ga_session_id |
+-----------------+--------------------+---------------+
| page_view       | 1005694.5834348403 | 4863244888    |
| first_visit     | 1005694.5834348403 | 4863244888    |
| user_engagement | 1005694.5834348403 | 4863244888    |
| session_start   | 1005694.5834348403 | 4863244888    |
...
+-----------------+--------------------+---------------+

Observation:
ga_session_id can be extracted from event_params while
preserving the event-level grain.
*/


-- 05. Count unique sessions
-- A session is identified using the combination of
-- user_pseudo_id and ga_session_id.

SELECT
    COUNT(DISTINCT CONCAT(
        user_pseudo_id,
        '-',
        CAST((
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS STRING)
    )) AS sessions

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`;

/*
Query output:

+----------+
| sessions |
+----------+
|     2625 |
+----------+

Observation:
The table contains 31,272 events but only 2,625 unique
user-session combinations.

This demonstrates that multiple events can belong to
the same session.
*/