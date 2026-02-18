-- ================================================================================================
-- Q3: Quick resales
-- Share of properties with at least one resale within 2 years and within 5 years.
-- Also median % gain for those QUICK resale events only (event-level).
--
-- Notes / choices:
-- 1) Dataset already de-duped upstream (v_sales_enriched_v2).
-- 2) "Quick" events exclude gaps < 7 days to reduce admin-transfer noise.
-- 3) Median gain excludes events where starting price < 10,000 to avoid fake giant gains.
-- 4) Two denominators:
--      - All properties with >= 1 sale
--      - Only properties with >= 2 sales (i.e., have a next sale at least once)
-- ================================================================================================

WITH base_properties AS (
    -- One row per property: denominator "all properties"
    SELECT DISTINCT
        property_id,
        COALESCE(NULLIF(TRIM(property_type), ''), 'Unknown') AS property_type,
        postcode_area,
        postcode_area_name,
        COALESCE(NULLIF(TRIM(tenure), ''), 'Unknown') AS tenure
    FROM v_sales_enriched_v2
    WHERE property_id IS NOT NULL
      AND sale_date IS NOT NULL
      AND sale_price IS NOT NULL
      AND postcode_area IS NOT NULL
      AND postcode_area_name IS NOT NULL
),

sales_with_next AS (
    -- One row per sale with its next sale (per property)
    SELECT
        property_id,
        COALESCE(NULLIF(TRIM(property_type), ''), 'Unknown') AS property_type,
        postcode_area,
        postcode_area_name,
        COALESCE(NULLIF(TRIM(tenure), ''), 'Unknown') AS tenure,
        sale_date,
        sale_price,
        LEAD(sale_date)  OVER (PARTITION BY property_id ORDER BY sale_date) AS next_sale_date,
        LEAD(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date) AS next_sale_price
    FROM v_sales_enriched_v2
    WHERE property_id IS NOT NULL
      AND sale_date IS NOT NULL
      AND sale_price IS NOT NULL
      AND postcode_area IS NOT NULL
      AND postcode_area_name IS NOT NULL
),

resale_properties AS (
    -- Properties that have at least one next sale (>= 2 sales). This is the "2+ sales denominator"
    SELECT DISTINCT
        property_id
    FROM sales_with_next
    WHERE next_sale_date IS NOT NULL
      AND next_sale_price IS NOT NULL
),

event_metrics AS (
    -- Event-level metrics for sale -> next sale
    SELECT
        property_id,
        property_type,
        postcode_area,
        postcode_area_name,
        tenure,
        sale_date,
        sale_price,
        next_sale_date,
        next_sale_price,
        ((next_sale_date - sale_date) * 1.0 / 365.25) AS years_to_next_sale,
        (next_sale_date - sale_date) AS days_to_next_sale,
        ROUND((next_sale_price - sale_price) * 100.0 / NULLIF(sale_price, 0), 1) AS pct_gain
    FROM sales_with_next
    WHERE next_sale_date IS NOT NULL
      AND next_sale_price IS NOT NULL
),

quick_events AS (
    -- Quick resale events only (choice: exclude gaps < 7 days)
    SELECT *
    FROM event_metrics
    WHERE days_to_next_sale >= 7
),

property_flags AS (
    -- Property-level flags: does the property have ANY quick event within 2y / 5y?
    SELECT
        property_id,
        MAX(CASE WHEN years_to_next_sale <= 2 THEN 1 ELSE 0 END) AS has_quick_2y,
        MAX(CASE WHEN years_to_next_sale <= 5 THEN 1 ELSE 0 END) AS has_quick_5y
    FROM quick_events
    GROUP BY property_id
),

area_summary AS (
    -- Property-level shares (two denominators)
    SELECT
        bp.property_type,
        bp.postcode_area,
        bp.postcode_area_name,
        bp.tenure,

        COUNT(*) AS properties_total,

        -- Denominator: properties with >=2 sales (at least one next sale)
        SUM(CASE WHEN rp.property_id IS NOT NULL THEN 1 ELSE 0 END) AS properties_2plus_sales,

        -- Numerators: properties that have at least one quick resale event
        SUM(COALESCE(pf.has_quick_2y, 0)) AS properties_quick_2y,
        SUM(COALESCE(pf.has_quick_5y, 0)) AS properties_quick_5y,

        -- Shares among ALL properties
        ROUND(
            CAST(SUM(COALESCE(pf.has_quick_2y, 0)) AS NUMERIC)
            / CAST(NULLIF(COUNT(*), 0) AS NUMERIC)
        , 4) AS share_quick_2y_all,

        ROUND(
            CAST(SUM(COALESCE(pf.has_quick_5y, 0)) AS NUMERIC)
            / CAST(NULLIF(COUNT(*), 0) AS NUMERIC)
        , 4) AS share_quick_5y_all,

        -- Shares among properties with >=2 sales only
        ROUND(
            CAST(SUM(COALESCE(pf.has_quick_2y, 0)) AS NUMERIC)
            / CAST(NULLIF(SUM(CASE WHEN rp.property_id IS NOT NULL THEN 1 ELSE 0 END), 0) AS NUMERIC)
        , 4) AS share_quick_2y_2plus,

        ROUND(
            CAST(SUM(COALESCE(pf.has_quick_5y, 0)) AS NUMERIC)
            / CAST(NULLIF(SUM(CASE WHEN rp.property_id IS NOT NULL THEN 1 ELSE 0 END), 0) AS NUMERIC)
        , 4) AS share_quick_5y_2plus

    FROM base_properties bp
    LEFT JOIN resale_properties rp
        ON bp.property_id = rp.property_id
    LEFT JOIN property_flags pf
        ON bp.property_id = pf.property_id
    GROUP BY
        bp.property_type,
        bp.postcode_area,
        bp.postcode_area_name,
        bp.tenure
),

gain_2y AS (
    -- Event-level median gain for quick 2y events only (apply £10K floor)
    SELECT
        property_type,
        postcode_area,
        postcode_area_name,
        tenure,
        COUNT(*) AS quick_events_2y,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pct_gain) AS median_pct_gain_2y
    FROM quick_events
    WHERE years_to_next_sale <= 2
      AND sale_price >= 10000
    GROUP BY
        property_type,
        postcode_area,
        postcode_area_name,
        tenure
),

gain_5y AS (
    -- Event-level median gain for quick 5y events only (apply £10K floor)
    SELECT
        property_type,
        postcode_area,
        postcode_area_name,
        tenure,
        COUNT(*) AS quick_events_5y,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pct_gain) AS median_pct_gain_5y
    FROM quick_events
    WHERE years_to_next_sale <= 5
      AND sale_price >= 10000
    GROUP BY
        property_type,
        postcode_area,
        postcode_area_name,
        tenure
)

SELECT
    a.postcode_area,
    a.postcode_area_name,
    a.tenure,
    a.property_type,

    a.properties_total,
    a.properties_2plus_sales,
    a.properties_quick_2y,
    a.properties_quick_5y,

    a.share_quick_2y_all,
    a.share_quick_5y_all,
    a.share_quick_2y_2plus,
    a.share_quick_5y_2plus,

    COALESCE(g2.quick_events_2y, 0) AS quick_events_2y,
    ROUND(CAST(g2.median_pct_gain_2y AS NUMERIC), 1) AS median_pct_gain_2y,

    COALESCE(g5.quick_events_5y, 0) AS quick_events_5y,
    ROUND(CAST(g5.median_pct_gain_5y AS NUMERIC), 1) AS median_pct_gain_5y

FROM area_summary a
LEFT JOIN gain_2y g2
    ON a.property_type = g2.property_type
   AND a.postcode_area = g2.postcode_area
   AND a.postcode_area_name = g2.postcode_area_name
   AND a.tenure = g2.tenure
LEFT JOIN gain_5y g5
    ON a.property_type = g5.property_type
   AND a.postcode_area = g5.postcode_area
   AND a.postcode_area_name = g5.postcode_area_name
   AND a.tenure = g5.tenure
ORDER BY
    a.postcode_area, a.tenure, a.property_type;
