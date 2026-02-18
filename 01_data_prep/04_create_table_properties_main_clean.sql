-- =====================================================================
-- Create cleaned properties table
-- - Parses postcode from address
-- - Derives postcode_area for geographic analysis
-- - Converts latest sale price and date to usable types
-- =====================================================================

-- Drop existing clean table if it exists
-- CASCADE ensures dependent views (e.g. v_sales) are dropped if present

DROP TABLE IF EXISTS public.properties_main_clean CASCADE;

CREATE TABLE public.properties_main_clean AS

-- ---------------------------------------------------------------------
-- Base CTE:
-- - Extract postcode from full address using regex
-- - Preserve original columns for reference
-- ---------------------------------------------------------------------
WITH base AS (
	SELECT
		property_id,
		address,
		-- Extract UK postcode from address (case-insensitive)
		-- Regex captures the full postcode (e.g. SW7 1RH)
		(
			regexp_match(
				UPPER(address),
				'([A-Z]{1,2}[0-9][0-9A-Z]?\s?[0-9][A-Z]{2})'
			)
		)[1] AS postcode,
		property_type,
		property_subtype,
		bedrooms,
		bathrooms,
		tenure,
		latest_price,
		latest_date,
		new_build
	FROM properties_main
)
-- ---------------------------------------------------------------------
-- Final selection:
-- - Derive postcode_area (e.g. SW7)
-- - Preserve raw latest_price alongside cleaned numeric version
-- - Cast latest_date to DATE
-- ---------------------------------------------------------------------
SELECT
	property_id,
	address,
	postcode,
	-- Postcode area used for area-level aggregation
	split_part(postcode, ' ', 1) AS postcode_area,
	property_type,
	property_subtype,
	bedrooms,
	bathrooms,
	tenure,
	latest_price AS latest_price_raw,
	-- Convert latest_price from string to numeric
	CAST(
		NULLIF(
			regexp_replace(latest_price, '[^0-9.]', '', 'g'),'') AS NUMERIC) AS latest_sale_price,
	-- Convert latest sale date to DATE
	CAST(latest_date AS DATE) AS latest_sale_date,
	new_build
FROM base;


