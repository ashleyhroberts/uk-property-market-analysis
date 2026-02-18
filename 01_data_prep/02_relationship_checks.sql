-- Price records without a matching property: 0
SELECT 
	COUNT(*) AS orphan_price_rows
FROM price_history ph
LEFT JOIN properties_main pm 
	ON ph.property_id = pm.property_id
WHERE pm.property_id IS NULL;

-- Properties with no price history: 0
SELECT 
	COUNT(*) AS orhpan_properties
FROM properties_main pm 
LEFT JOIN price_history ph 
	ON pm.property_id = ph.property_id 
WHERE ph.property_id IS NULL;

-- Cardinality: Count average # of transactions per property: 2
SELECT 
	COUNT(*) AS total_rows,
	COUNT(DISTINCT property_id) AS total_properties,
	COUNT(*) / COUNT(DISTINCT property_id) AS avg_prices_per_property
FROM price_history;

-- Possible duplicate sale records: 98 properties have >1 price record on same sale date
SELECT 
	property_id,
	"deedDate" AS sale_date,
	COUNT(*)
FROM price_history
GROUP BY property_id, "deedDate"
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC

