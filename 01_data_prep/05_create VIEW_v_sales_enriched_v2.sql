CREATE OR REPLACE VIEW v_sales_enriched_v2 AS
SELECT
    -- Sale event fields
    phc.property_id,
    phc.sale_date,
    phc.sale_price,

    -- Sale-level new build flag (CORRECT)
    phc.new_build_at_sale,

    -- Property attributes
    pmc.address,
    pmc.postcode,
    pmc.postcode_area AS postcode_district,

    COALESCE(pmc.property_type, 'Unknown') AS property_type,
    COALESCE(pmc.property_subtype, 'Unknown') AS property_subtype,
    pmc.bedrooms,
    pmc.bathrooms,
    COALESCE(pmc.tenure, 'Unknown') AS tenure,

    -- Property-level new build (kept for transparency)
    pmc.new_build AS property_new_build_flag,

    -- Geography enrichment
    prm.postcode_area,
    prm.postcode_area_name,
    prm.region,
    prm.country

FROM price_history_clean_v2 phc
LEFT JOIN properties_main_clean pmc
    ON phc.property_id = pmc.property_id
LEFT JOIN postcode_region_map prm
    ON UPPER(TRIM(pmc.postcode_area)) = UPPER(TRIM(prm.postcode_district));


