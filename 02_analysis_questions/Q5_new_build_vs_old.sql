-- =============================================================================================
-- Question 5: 5. New build premium, like for like    
-- For each postcode area and year, compare the median sale price for new build vs not new build.
-- =============================================================================================

-- Compute median sale price by postcode, year, and build status
WITH medians AS (
	SELECT 
		postcode_area,	
		postcode_area_name,
		EXTRACT (YEAR FROM sale_date) AS sale_year,
		new_build_at_sale,
		property_type,
		COUNT(*) AS sales_count,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sale_price) AS median_sale_price
	FROM v_sales_enriched_v2
	-- Exclude rows that cannot contribute to a valid comparison
	WHERE sale_price IS NOT NULL
		AND new_build_at_sale IS NOT NULL
	GROUP BY postcode_area, postcode_area_name,property_type, EXTRACT (YEAR FROM sale_date), new_build_at_sale
	
	-- Pivot medians so new build and not-new build appear side by side
), pivoted AS (
	SELECT 
		postcode_area,
		postcode_area_name,
		sale_year,
		property_type,
		-- medians
		MAX(CASE WHEN new_build_at_sale IS TRUE THEN median_sale_price END) AS median_price_new,
		MAX(CASE WHEN new_build_at_sale IS FALSE THEN median_sale_price END) AS median_price_not_new,
		
		--counts
		SUM(CASE WHEN new_build_at_sale IS TRUE  THEN sales_count ELSE 0 END) AS sales_count_new,
        SUM(CASE WHEN new_build_at_sale IS FALSE THEN sales_count ELSE 0 END) AS sales_count_not_new
		
	FROM medians
	GROUP BY postcode_area, postcode_area_name, property_type, sale_year
)

-- Keep only years where both medians exist and compute the difference
SELECT
	postcode_area,
	postcode_area_name,
	sale_year,
	property_type,
	median_price_not_new,
	median_price_new,
	median_price_new - median_price_not_new AS median_price_diff,
	sales_count_not_new,
    sales_count_new,
    sales_count_new + sales_count_not_new AS sales_count_total
FROM pivoted	
WHERE median_price_not_new IS NOT NULL
	AND median_price_new IS NOT NULL
	AND postcode_area_name = 'Swindon'
ORDER BY postcode_area, postcode_area_name, sale_year

