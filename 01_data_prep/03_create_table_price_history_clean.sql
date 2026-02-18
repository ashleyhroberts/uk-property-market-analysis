-- Build a new clean price_history (sales events) table including sale-level new build
DROP TABLE IF EXISTS price_history_clean_v2;

CREATE TABLE price_history_clean_v2 AS
WITH parsed AS (
    SELECT
        property_id,
        CAST("deedDate" AS DATE) AS sale_date,
        CAST(
            NULLIF(regexp_replace("displayPrice", '[^0-9.]', '', 'g'), '')
            AS NUMERIC
        ) AS sale_price,
        "newBuild" AS new_build_at_sale
    FROM price_history
    WHERE "deedDate" IS NOT NULL
),
deduped AS (
    SELECT
        property_id,
        sale_date,
        sale_price,
        new_build_at_sale,
        ROW_NUMBER() OVER (
            PARTITION BY property_id, sale_date
            ORDER BY sale_price DESC NULLS LAST,
                     new_build_at_sale DESC
        ) AS rn
    FROM parsed
)
SELECT
    property_id,
    sale_date,
    sale_price,
    new_build_at_sale
FROM deduped
WHERE rn = 1;
