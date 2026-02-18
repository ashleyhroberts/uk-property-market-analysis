-- =====================================================================
-- Q9: Shock years (2008 and 2020) — prep dataset for Tableau small multiples
-- For a few big postcode areas, return median sale prices for:
--      - year before the shock
--      - shock year
--      - year after the shock
-- Output grain: one row per postcode_area per sale_year (within shock windows)
-- =====================================================================


WITH shock_sales AS (
  -- -----------------------------------------------------------------
    -- Step 1: Restrict to the 6 years needed for the two shock windows
    -- 2008 shock: 2007, 2008, 2009
    -- 2020 shock: 2019, 2020, 2021
    -- Keep only the fields needed for median calculations.
    -- -----------------------------------------------------------------
	SELECT
		postcode_area,
		postcode_area_name,
		postcode_district,		
		EXTRACT (YEAR FROM sale_date) AS sale_year,
		sale_price
	FROM v_sales_enriched_v2
	WHERE EXTRACT (YEAR FROM sale_date) IN (2007, 2008, 2009, 2019, 2020, 2021)
	AND postcode_area IS NOT NULL 
	AND sale_price IS NOT NULL
),
big_areas AS (
 -- -----------------------------------------------------------------
    -- Step 2: Choose "a few big areas"
    -- Definition: Top 5 postcode areas by number of sales within the
    -- shock windows. This keeps medians stable and comparable.
    -- -----------------------------------------------------------------
	SELECT 
		postcode_area
	FROM shock_sales
	GROUP BY postcode_area 
	ORDER BY COUNT(*) DESC 
	LIMIT 6
),
area_year AS (
-- -----------------------------------------------------------------
    -- Step 3: Compute median price and sales count per area-year
    -- Result grain: one row per postcode_area per sale_year.
    -- -----------------------------------------------------------------
SELECT
	ss.postcode_area,
	ss.postcode_area_name,
	ss.sale_year,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sale_price) AS median_price,
	COUNT(*) AS sales_count
FROM shock_sales ss 
INNER JOIN big_areas ba
	ON ss.postcode_area = ba.postcode_area
GROUP BY ss.postcode_area, ss.postcode_area_name, ss.sale_year
),
labeled AS (
-- Step 4: Add Tableau-friendly labels for shock window + year role

	SELECT 
		postcode_area,
		postcode_area_name,
		sale_year,
		median_price,
		sales_count,
		CASE 
			WHEN sale_year BETWEEN 2007 AND 2009 THEN 2008
			WHEN sale_year BETWEEN 2019 AND 2021 THEN 2020
		END AS shock_year,
		CASE 
			WHEN sale_year IN (2007, 2019) THEN 'Before'
			WHEN sale_year IN (2008, 2020) THEN 'Shock'
			WHEN sale_year IN (2009, 2021) THEN 'After'
		END AS year_role
	FROM area_year
),
windowed AS (
    SELECT
        *,
        MAX(CASE WHEN year_role = 'Before' THEN median_price END)
            OVER (PARTITION BY postcode_area, shock_year) AS median_price_before,
        MAX(CASE WHEN year_role = 'After' THEN median_price END)
            OVER (PARTITION BY postcode_area, shock_year) AS median_price_after
    FROM labeled
)
SELECT
    postcode_area,
    postcode_area_name,
    sale_year,
    median_price,
    sales_count,
    shock_year,
    year_role,
    median_price_before,
    median_price_after,
    ROUND(
        CAST(
            100 * (median_price_after - median_price_before)
            / NULLIF(median_price_before, 0)
            AS numeric
        ),
        1
    ) AS pct_change_before_to_after
FROM windowed
ORDER BY shock_year, postcode_area, sale_year;