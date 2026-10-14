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

-- 06. Explore traffic-source dimensions
-- Understand where users/events are attributed from.

SELECT
    traffic_source.source,
    traffic_source.medium,
    traffic_source.name,
    COUNT(*) AS event_count

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`

GROUP BY
    traffic_source.source,
    traffic_source.medium,
    traffic_source.name

ORDER BY
    event_count DESC;

/*
Query output:

+---------------------------------+----------------+----------------+-------------+
|             source              |     medium     |      name      | event_count |
+---------------------------------+----------------+----------------+-------------+
| google                          | organic        | (organic)      |        8672 |
| (direct)                        | (none)         | (direct)       |        7597 |
| <Other>                         | <Other>        | <Other>        |        4863 |
| shop.googlemerchandisestore.com | referral       | (referral)     |        3626 |
| <Other>                         | referral       | (referral)     |        2384 |
| google                          | cpc            | <Other>        |        1381 |
| (data deleted)                  | (data deleted) | (data deleted) |        1364 |
| <Other>                         | organic        | (organic)      |        1243 |
| <Other>                         | (data deleted) | (data deleted) |          73 |
| (data deleted)                  | (data deleted) | <Other>        |          69 |
+---------------------------------+----------------+----------------+-------------+

Observation:

The raw GA4 events contain traffic-source information in the
nested traffic_source record, including source, medium, and name.

The largest event-source combination in this daily table is
Google Organic with 8,672 events, followed by Direct traffic
with 7,597 events.

The result shows that traffic attribution can be used as a
marketing-analysis dimension. However, event_count measures
events, not users, sessions, conversions, or revenue, so it
should not be interpreted as channel performance by itself.
*/


-- 07. Explore event types and frequency
-- Understand which GA4 events occur most frequently
-- and how many unique users generated them.

SELECT
    event_name,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_pseudo_id) AS unique_users

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`

GROUP BY
    event_name

ORDER BY
    event_count DESC;

/*
Query output:

+---------------------+-------------+--------------+
|     event_name      | event_count | unique_users |
+---------------------+-------------+--------------+
| page_view           |        9767 |         2302 |
| user_engagement     |        8667 |         1844 |
| view_item           |        3380 |          516 |
| scroll              |        3040 |         1168 |
| session_start       |        2594 |         2339 |
| first_visit         |        1946 |         1946 |
| view_promotion      |        1263 |          779 |
| view_search_results |         194 |          105 |
| begin_checkout      |         127 |           91 |
| add_shipping_info   |         127 |           91 |
| add_payment_info    |          73 |           26 |
| select_promotion    |          57 |           51 |
| purchase            |          14 |           13 |
| click               |          11 |            9 |
| view_item_list      |            8 |            4 |
| add_to_cart         |            4 |            1 |
+---------------------+-------------+--------------+

Observation:

Observation:

page_view is the most frequent event, while purchase occurs
14 times across 13 users. add_to_cart is unusually low at
4 events across 1 user, so ecommerce tracking should be
investigated before building the funnel.
*/

-- 08. Explore ecommerce metrics
-- Inspect revenue and transaction-related fields.

SELECT
    event_name,
    ecommerce.transaction_id,
    ecommerce.purchase_revenue,
    ecommerce.total_item_quantity

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`

WHERE event_name IN ('purchase', 'begin_checkout', 'add_to_cart')

LIMIT 20;
/*
-- query output:
+----------------+----------------+------------------+---------------------+
|   event_name   | transaction_id | purchase_revenue | total_item_quantity |
+----------------+----------------+------------------+---------------------+
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
| begin_checkout | NULL           |             NULL |                NULL |
+----------------+----------------+------------------+---------------------+

/*
Observation:

The sampled begin_checkout events have NULL values for
transaction_id, purchase_revenue, and total_item_quantity.
The LIMIT returned only begin_checkout rows, so purchase and
add_to_cart still need separate inspection.
*/

-- 09. Explore purchase items
-- The items field is a repeated nested record.
-- UNNEST() expands each product within a purchase event
-- into a separate row.

SELECT
    event_name,
    item.item_id,
    item.item_name,
    item.price,
    item.quantity,
    item.item_revenue

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20201101`,
UNNEST(items) AS item

WHERE event_name = 'purchase'

LIMIT 20;

/*
Query output:

+------------+---------+-----------------------------------+-------+----------+--------------+
| event_name | item_id |             item_name             | price | quantity | item_revenue |
+------------+---------+-----------------------------------+-------+----------+--------------+
| purchase   | 9196843 | Android Iconic Backpack           |  25.0 |        1 |         25.0 |
| purchase   | 9196894 | Google Cork Card Holder           |  13.0 |        1 |         13.0 |
| purchase   | 9196647 | Google Sherpa Zip Hoodie Navy     |  55.0 |        1 |         55.0 |
| purchase   | 9199130 | Super G Unisex Joggers            |  30.0 |        2 |         59.0 |
| purchase   | 9195739 | Google Dino Game Tee              |  32.0 |        1 |         32.0 |
| purchase   | 9196658 | Google Raincoat Navy              | 120.0 |        1 |        120.0 |
| purchase   | 9196875 | Google KeepCup                    |  35.0 |        2 |         70.0 |
| purchase   | 919...  | ...                               |  ...  |      ... |         ... |
+------------+---------+-----------------------------------+-------+----------+--------------+

Observation:

The items field contains repeated product-level records.
UNNEST(items) changes the grain from event-level to
item-level, allowing product quantity and revenue to be
analyzed separately.
*/