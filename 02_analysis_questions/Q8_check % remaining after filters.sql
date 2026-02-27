-- Retention stats for annualized analysis filters (90-day rule + 25% cap)

WITH property_first_last_cte AS (
    SELECT 
        property_id,
        property_type,
        tenure,
        postcode_area_name,
        region,
        first_value(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date) AS first_recorded_price,
        first_value(sale_date)  OVER (PARTITION BY property_id ORDER BY sale_date) AS first_recorded_date,
        first_value(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date DESC) AS last_recorded_price,
        first_value(sale_date)  OVER (PARTITION BY property_id ORDER BY sale_date DESC) AS last_recorded_date,
        count(*) OVER (PARTITION BY property_id) AS count_recorded_sales,
        row_number() OVER (PARTITION BY property_id ORDER BY sale_date DESC) AS rn
    FROM v_sales_enriched_v2
),

property_metrics_cte AS (
    SELECT 
        property_id,
        property_type,
        tenure,
        postcode_area_name,
        region,
        first_recorded_price,
        first_recorded_date,
        last_recorded_price,
        last_recorded_date,
        count_recorded_sales,

        (last_recorded_date - first_recorded_date) AS days_held,

        ROUND(
          CASE
            WHEN (last_recorded_date - first_recorded_date) < 90 THEN NULL
            WHEN NULLIF(CAST(first_recorded_price AS NUMERIC), 0) IS NULL THEN NULL
            WHEN (last_recorded_date - first_recorded_date) <= 0 THEN NULL
            ELSE
              (
                POWER(
                  CAST(last_recorded_price AS NUMERIC)
                  / NULLIF(CAST(first_recorded_price AS NUMERIC), 0),
                  365.25 / NULLIF(CAST((last_recorded_date - first_recorded_date) AS NUMERIC), 0)
                ) - 1
              ) * 100
          END,
          2
        ) AS annualized_return

    FROM property_first_last_cte
    WHERE rn = 1
      AND count_recorded_sales >= 2
      AND first_recorded_date < last_recorded_date
),

base_eligible AS (
    -- This matches your scope BEFORE the two annualized filters
    SELECT *
    FROM property_metrics_cte
    WHERE first_recorded_price >= 10000
      AND last_recorded_price  >= 10000
),

after_90_day_rule AS (
    SELECT *
    FROM base_eligible
    WHERE days_held >= 90
),

after_90_and_cap AS (
    SELECT *
    FROM after_90_day_rule
    WHERE annualized_return <= 25
)

SELECT
    (SELECT COUNT(*) FROM base_eligible)      AS total_eligible,
    (SELECT COUNT(*) FROM after_90_day_rule)  AS after_90_day_rule,
    (SELECT COUNT(*) FROM after_90_and_cap)   AS after_90_day_and_25_cap,

    ROUND(
      100.0 * (SELECT COUNT(*) FROM after_90_day_rule)
      / NULLIF((SELECT COUNT(*) FROM base_eligible), 0),
      2
    ) AS pct_remaining_after_90_day_rule,

    ROUND(
      100.0 * (SELECT COUNT(*) FROM after_90_and_cap)
      / NULLIF((SELECT COUNT(*) FROM after_90_day_rule), 0),
      2
    ) AS pct_remaining_after_25_cap_of_90plus,

    ROUND(
      100.0 * (SELECT COUNT(*) FROM after_90_and_cap)
      / NULLIF((SELECT COUNT(*) FROM base_eligible), 0),
      2
    ) AS pct_remaining_after_both_filters;