-- Fails if total revenue differs between the two marts
WITH daily AS (
    SELECT SUM(revenue) AS daily_revenue
    FROM {{ ref('mart_marketing_daily') }}
),

acquisition AS (
    SELECT SUM(revenue) AS acquisition_revenue
    FROM {{ ref('mart_acquisition_performance') }}
)

SELECT
    daily_revenue,
    acquisition_revenue
FROM daily
CROSS JOIN acquisition
WHERE ABS(daily_revenue - acquisition_revenue) > 0.01