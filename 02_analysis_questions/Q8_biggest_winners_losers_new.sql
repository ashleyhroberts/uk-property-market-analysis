WITH params AS (
    SELECT
        CAST(10000 AS numeric) AS min_rank_first_price,
        CAST(25.0  AS numeric) AS annualized_flag_pct,
        CAST(1.0   AS numeric) AS short_hold_years
),

property_first_last AS (
    SELECT
        property_id,
        property_type,
        tenure,
        region,
        postcode_area,
        postcode_area_name,

        FIRST_VALUE(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date)      AS first_price,
        FIRST_VALUE(sale_date)  OVER (PARTITION BY property_id ORDER BY sale_date)      AS first_date,

        FIRST_VALUE(sale_price) OVER (PARTITION BY property_id ORDER BY sale_date DESC) AS last_price,
        FIRST_VALUE(sale_date)  OVER (PARTITION BY property_id ORDER BY sale_date DESC) AS last_date,

        COUNT(*) OVER (PARTITION BY property_id)                                        AS sales_count,
        ROW_NUMBER() OVER (PARTITION BY property_id ORDER BY sale_date DESC)            AS rn
    FROM v_sales_enriched_v2
    WHERE property_id IS NOT NULL
      AND sale_date   IS NOT NULL
      AND sale_price  IS NOT NULL
),

property_metrics AS (
    SELECT
        p.property_id,
        p.property_type,
        p.tenure,
        p.region,
        p.postcode_area,
        p.postcode_area_name,

        p.first_date,
        p.first_price,
        p.last_date,
        p.last_price,

        p.sales_count,

        -- Years between first and last recorded sale 
        ROUND(
            CAST((p.last_date - p.first_date) AS numeric) / CAST(365.25 AS numeric),
            2
        ) AS years_tracked,

        -- percent change from first to last
        ROUND(
            ((p.last_price / NULLIF(p.first_price, 0)) - 1) * 100,
            2
        ) AS pct_change,

        -- absolute change
        (p.last_price - p.first_price) AS absolute_gain,

        -- annualized return (CAGR) %
        ROUND(
            (
                POWER(
                    p.last_price / NULLIF(p.first_price, 0),
                    1.0 / NULLIF(
                        CAST((p.last_date - p.first_date) AS numeric) / CAST(365.25 AS numeric),
                        0
                    )
                ) - 1
            ) * 100,
            2
        ) AS annualized_return_raw

    FROM property_first_last p
    WHERE p.rn = 1
      AND p.sales_count >= 2
      AND p.first_date < p.last_date
),

flagged AS (
    SELECT
        m.*,

        -- Flag only 
        CASE
            WHEN m.first_price < (SELECT min_rank_first_price FROM params)
                THEN 'Below £10k first price (excluded from ranking)'
            WHEN m.years_tracked < (SELECT short_hold_years FROM params)
                THEN 'Short hold (<1 year)'
            WHEN m.annualized_return_raw >= (SELECT annualized_flag_pct FROM params)
                THEN 'Extreme annualized return (>=25%)'
            ELSE NULL
        END AS review_flag
    FROM property_metrics m
),

rankable AS (
    -- exclude first_price < 10k from the ranking list
    SELECT *
    FROM flagged
    WHERE first_price >= (SELECT min_rank_first_price FROM params)
      AND pct_change IS NOT NULL
),

ranked AS (
    SELECT
        r.*,
        DENSE_RANK() OVER (ORDER BY pct_change DESC) AS winner_rank,
        DENSE_RANK() OVER (ORDER BY pct_change ASC)  AS loser_rank
    FROM rankable r
)

SELECT
    property_id,
    property_type,
    tenure,
    region,
    postcode_area,
    postcode_area_name,

    first_date,
    first_price,
    last_date,
    last_price,

    sales_count,
    years_tracked,

    pct_change,
    absolute_gain,
    annualized_return_raw,

    review_flag,

    CASE
        WHEN winner_rank <= 10 THEN 'Winner'
        WHEN loser_rank  <= 10 THEN 'Loser'
    END AS bucket,

    CASE
        WHEN winner_rank <= 10 THEN winner_rank
        WHEN loser_rank  <= 10 THEN loser_rank
    END AS rank_in_bucket

FROM ranked
WHERE winner_rank <= 10
   OR loser_rank  <= 10
ORDER BY bucket, rank_in_bucket, pct_change DESC;

