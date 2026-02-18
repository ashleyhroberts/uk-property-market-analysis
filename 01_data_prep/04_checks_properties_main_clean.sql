-- Check properties_main_clean

-- Compare row count in clean vs raw tables.  Same: 22,258
SELECT COUNT(*) FROM properties_main_clean;
SELECT COUNT(*) FROM properties_main;

--  Any missing postcodes? No: 0 returned
SELECT COUNT(*) AS cnt
FROM properties_main_clean 
WHERE postcode IS NULL;

-- Any null parsed prices? No: 0 returned
SELECT COUNT(*) AS cnt
FROM properties_main_clean 
WHERE latest_sale_price IS NULL;



-- Any missing latest_sale_date? No: 0 returned
SELECT COUNT(*) AS missing_latest_sale_date
FROM properties_main_clean
WHERE latest_sale_date IS NULL;


-- Check how many addresses successfully produced a postcode: 22,258
SELECT
  COUNT(*) AS total_rows,
  COUNT(postcode) AS postcode_found
FROM (
  SELECT
    (
      regexp_match(
        UPPER(address),
        '([A-Z]{1,2}[0-9][0-9A-Z]?\s?[0-9][A-Z]{2})'
      )
    )[1] AS postcode
  FROM properties_main
) x;
