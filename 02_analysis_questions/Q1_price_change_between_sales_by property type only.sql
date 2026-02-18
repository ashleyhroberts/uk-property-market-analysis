-- =============================================================================================================
-- Q1: Median % change between consecutive sales (resales)
-- - For each property, find the prior sale price (chronological by sale_date).
-- - Compute the percent change from the prior sale to the current sale.
-- - Aggregate those resale events to the median % change by PROPERTY TYPE ONLY.
-- =============================================================================================================

-- Step 1: For each property, pull the previous sale price using LAG()
WITH previous_price AS (
SELECT
	property_id,
	property_type,
	postcode_area,
	postcode_area_name,
	region,
	sale_date,
	sale_price,
	LAG(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date ASC) AS previous_sale_price
FROM v_sales_enriched_v2
-- Remove rows that can't participate in a valid sale-to-sale comparison
WHERE sale_price >=10000 
	AND sale_date IS NOT NULL
),
percent_price_change AS (
-- Step 2: Compute % change from previous sale to current sale (avoid divide-by-zero)
	SELECT 
		property_id,
		property_type,
		postcode_area,
		postcode_area_name,
		region,
		sale_date,
		sale_price,
		previous_sale_price,
		100 * (sale_price - previous_sale_price) / NULLIF(previous_sale_price,0) AS percent_price_change
	FROM previous_price
	-- Keep only true resale events (where a prior sale exists)
	WHERE previous_sale_price IS NOT NULL
)

-- Step 3: Summarize resale events: median % change per property type + postcode area
SELECT 
	property_type,
	--postcode_area,
	--postcode_area_name,
	--region,
	ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY percent_price_change) AS NUMERIC),1) AS median_percent_price_change,
	COUNT(*) AS resale_events_used
FROM percent_price_change
GROUP BY
	property_type
	--postcode_area,
	--postcode_area_name,
	--region
ORDER BY median_percent_price_change DESC

