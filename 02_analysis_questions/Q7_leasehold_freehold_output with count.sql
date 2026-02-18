--Q7: For each postcode area, compare median sale price across Leasehold, Freehold, and Unknown tenure.

SELECT
	postcode_area,
	postcode_area_name,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sale_price) AS median_sale_price,
	CASE 
		WHEN tenure = 'Freehold' THEN 'Freehold'
		WHEN tenure = 'Leasehold' THEN 'Leasehold'
		ELSE 'Unknown'
	END AS tenure_category,
	COUNT(*) AS sales_count
FROM v_sales_enriched_v2
WHERE sale_price IS NOT NULL
	AND postcode_area IS NOT NULL
GROUP BY 
	postcode_area, 
	postcode_area_name, 
	tenure
ORDER BY
	postcode_area,
	tenure

