-- Count of rows in price_history_clean = 51,171
SELECT COUNT(*) FROM price_history_clean;

-- Confirm grain - no duplicates remain: 0
SELECT COUNT(*) 
FROM (
	SELECT property_id, sale_date, COUNT(*) AS cnt
	FROM price_history_clean 
	GROUP BY 1,2
	HAVING COUNT(*) >1
) t