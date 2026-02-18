-- How many rows in each dataset? properties_main: price_history: 
SELECT 
	'properties_main' AS table_name, 
	COUNT(*) AS rows
FROM public.properties_main
UNION ALL
SELECT 
	'price_history', 
	COUNT(*)
FROM public.price_history;
	
-- Price history date range: Jan 3, 1995 to Feb 28, 2025
SELECT
	MIN(CAST (price_history."deedDate" AS DATE)) AS earliest_deedDate,
	MAX(CAST (price_history."deedDate" AS DATE)) AS latest_deedDate
FROM price_history;

-- Number of price records per year
SELECT
	EXTRACT (YEAR FROM CAST ("deedDate" AS DATE)) AS sale_year,
	COUNT("displayPrice") AS sale_price
FROM price_history
GROUP BY EXTRACT (YEAR FROM CAST ("deedDate" AS DATE))
ORDER BY sale_year;

-- Check for missing dates: 0 non-null dates
SELECT 
	COUNT(*) AS total_rows,
	COUNT("deedDate") AS nonnull_dates 
FROM price_history;
