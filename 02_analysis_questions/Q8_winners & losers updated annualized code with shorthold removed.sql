-- Identify first and last recorded sale per property
WITH property_first_last_cte as (
   SELECT 
       property_id,
       property_type,
       tenure,
       postcode_area_name,
       region,

       -- First recorded sale (chronological)
       first_value(sale_price) OVER (
           PARTITION BY property_id 
           ORDER BY sale_date
       ) AS first_recorded_price,

       first_value(sale_date) OVER (
           PARTITION BY property_id 
           ORDER BY sale_date
       ) AS first_recorded_date,

       -- Most recent recorded sale
       first_value(sale_price) OVER (
           PARTITION BY property_id 
           ORDER BY sale_date desc
       ) AS last_recorded_price,

       first_value(sale_date) OVER (
           PARTITION BY property_id 
           ORDER BY sale_date desc
       ) AS last_recorded_date,

       -- Total number of recorded sales per property
       COUNT(*) OVER (PARTITION BY property_id) AS count_recorded_sales,

       -- Used to isolate one row per property
       ROW_NUMBER() OVER (
           PARTITION BY property_id 
           ORDER BY sale_date DESC
       ) AS rn

   FROM v_sales_enriched_v2
),

-- Calculate performance metrics
property_metrics_cte as (
   SELECT
       property_id,
       property_type,
       tenure,
       postcode_area_name,
       region,
       first_recorded_price,
       first_recorded_date,
       last_recorded_price,
       last_recorded_date,
       count_recorded_sales,

       -- Total percent gain/loss from first to last sale
       round(
           ((last_recorded_price / NULLIF(first_recorded_price, 0)) - 1) * 100,
           2
       ) AS pct_gain,

       -- Holding period in years (year + fractional month)
       ROUND(
           (last_recorded_date - first_recorded_date) / 365.25,
           3
       ) AS years_tracked,
       
       -- compute exact days held (used for the 90-day threshold)
       (last_recorded_date - first_recorded_date) AS days_held,


      -- annualized return only when hold >= 90 days (otherwise NULL = "Short hold")
     -- Annualized return (calculated for ALL holds; short holds are labeled)
	ROUND(
	  CASE
	    WHEN (last_recorded_date - first_recorded_date) < 90 THEN NULL
	    WHEN NULLIF(CAST(first_recorded_price AS NUMERIC), 0) IS NULL THEN NULL
	    WHEN (last_recorded_date - first_recorded_date) <= 0 THEN NULL
	    ELSE
	      (
	        POWER(
	          CAST(last_recorded_price AS NUMERIC)
	          / NULLIF(CAST(first_recorded_price AS NUMERIC), 0),
	          365.25 / NULLIF(CAST((last_recorded_date - first_recorded_date) AS NUMERIC), 0)
	        ) - 1
	      ) * 100
	  END,
	  2
	) AS annualized_return,
	      
       -- label short holds for tooltips
     CASE
	  	WHEN (last_recorded_date - first_recorded_date) < 90 THEN 'Short hold (<90 days)'
	  	ELSE 'Normal hold (90+ days)'
	END AS hold_flag

   FROM property_first_last_cte
   WHERE rn = 1                         -- Keep one row per property
     AND count_recorded_sales >= 2      -- Require at least two sales
     AND first_recorded_date < last_recorded_date
),

-- Apply data quality and realism filters
filtered_metrics AS (
   SELECT *
   FROM property_metrics_cte
   WHERE first_recorded_price >= 10000     -- Remove distressed / extreme low prices
     -- CHANGE #4: don't let NULL annualized_return get filtered out by the <= 25 cap
     -- (short holds remain in the dataset but won't rank as winners/losers)
    	AND (
	  	annualized_return <= 25
	  	OR (last_recorded_date - first_recorded_date) < 90
		)
),

-- Top 10 annualized return winners
pct_winner_cte as (
	SELECT *,
       'Winner' as category
	FROM filtered_metrics
	WHERE annualized_return IS NOT NULL     -- exclude short holds from ranking
	ORDER BY annualized_return DESC
	LIMIT 10
),

-- Top 10 annualized return losers
pct_loser_cte as (
	SELECT *,
       'Loser' as category
	FROM filtered_metrics
	WHERE annualized_return IS NOT NULL     -- exclude short holds from ranking
	ORDER BY annualized_return
	LIMIT 10
),

-- Combine winners and losers
pct_winner_loser_cte AS (
	SELECT * FROM pct_winner_cte
	UNION
	SELECT * FROM pct_loser_cte
)

-- Final ordered result
SELECT *
FROM pct_winner_loser_cte
ORDER BY annualized_return DESC;


