-- ===============================================================================================================
-- Q4: Fastest growing postcode areas over the last decade
-- Compare median sale prices in 2013 vs 2023
-- Output is reshaped to long format for Tableau (one row per postcode + year)
-- ===============================================================================================================
WITH area_year AS (
    -- Step 1: Median price and sales count per postcode per year
    SELECT
        postcode_area,
        postcode_area_name,
        region,
        country,
        EXTRACT(YEAR FROM sale_date) AS sale_year,
        PERCENTILE_CONT(0.5) 
            WITHIN GROUP (ORDER BY sale_price) AS median_price,
        COUNT(*) AS sales_count
    FROM v_sales_enriched_v2
    WHERE EXTRACT(YEAR FROM sale_date) IN (2013, 2023)
    GROUP BY postcode_area, postcode_area_name, region, country, EXTRACT(YEAR FROM sale_date)
),
medians AS (
    -- Step 2: Pivot years into columns (wide format)
    SELECT
        postcode_area,
        postcode_area_name,
        region,
        country,
        MAX(CASE WHEN sale_year = 2013 THEN median_price END) AS median_price_2013,
        MAX(CASE WHEN sale_year = 2023 THEN median_price END) AS median_price_2023,
        MAX(CASE WHEN sale_year = 2013 THEN sales_count END)  AS sales_count_2013,
        MAX(CASE WHEN sale_year = 2023 THEN sales_count END)  AS sales_count_2023
    FROM area_year
    GROUP BY postcode_area,postcode_area_name, region, country
),
growth AS (
    -- Step 3: Calculate percent change
    SELECT
        postcode_area,
        postcode_area_name,
        region,
        country,
        median_price_2013,
        median_price_2023,
        sales_count_2013,
        sales_count_2023,
        ROUND(
            CAST(
                (median_price_2023 - median_price_2013)
                / NULLIF(median_price_2013, 0)
                AS NUMERIC
            ),
            3
        ) AS percent_change
    FROM medians
    WHERE median_price_2013 IS NOT NULL
      AND median_price_2023 IS NOT NULL
      AND sales_count_2013 >=10
      AND sales_count_2023 >=10
)

-- Step 4: Reshape to long format for Tableau
SELECT
    postcode_area,
    postcode_area_name,
    region,
    country,
    2013 AS sale_year,
    median_price_2013 AS median_price,
    sales_count_2013  AS sales_count,
    percent_change
FROM growth

UNION ALL

SELECT
    postcode_area,
    postcode_area_name,
    region,
    country,
    2023 AS sale_year,
    median_price_2023 AS median_price,
    sales_count_2023  AS sales_count,
    percent_change
FROM growth
ORDER BY percent_change DESC, postcode_area, sale_year
;