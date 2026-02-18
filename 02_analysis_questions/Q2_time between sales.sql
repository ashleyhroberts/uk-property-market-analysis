-- ===============================================================
-- Q2: 2. Typical time between sales    
-- Show the median time to the next recorded sale, in years.
-- Break it down by property type and postcode area.
-- ===============================================================

WITH sales_with_next AS (
	SELECT
        property_id,
        property_type,
        postcode_area,
        postcode_area_name,
        sale_date,
        LEAD(sale_date) OVER (
            PARTITION BY property_id
            ORDER BY sale_date
        ) AS next_sale_date
    FROM v_sales_enriched_v2
    WHERE sale_date IS NOT NULL
)
SELECT
    property_type,
    postcode_area,
    postcode_area_name,
    ROUND(
    	CAST(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY ((next_sale_date - sale_date) * 1.0) / 365.25
        ) AS NUMERIC
        ),1
    ) AS median_years_to_next_sale
FROM sales_with_next
WHERE next_sale_date IS NOT NULL
GROUP BY property_type, postcode_area, postcode_area_name
ORDER BY property_type, postcode_area, postcode_area_name;
