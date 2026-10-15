-- Fails if any date + source + medium appears more than once
SELECT
    session_date,
    source,
    medium,
    COUNT(*) AS row_count
FROM {{ ref('mart_marketing_daily') }}
GROUP BY session_date, source, medium
HAVING COUNT(*) > 1