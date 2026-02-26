-- Identify first and last recorded sale per property
with property_first_last_cte as (
   select 
       property_id,
       property_type,
       tenure,
       postcode_area_name,
       region,

       -- First recorded sale (chronological)
       first_value(sale_price) over (
           partition by property_id 
           order by sale_date
       ) as first_recorded_price,

       first_value(sale_date) over (
           partition by property_id 
           order by sale_date
       ) as first_recorded_date,

       -- Most recent recorded sale
       first_value(sale_price) over (
           partition by property_id 
           order by sale_date desc
       ) as last_recorded_price,

       first_value(sale_date) over (
           partition by property_id 
           order by sale_date desc
       ) as last_recorded_date,

       -- Total number of recorded sales per property
       count(*) over (partition by property_id) as count_recorded_sales,

       -- Used to isolate one row per property
       row_number() over (
           partition by property_id 
           order by sale_date desc
       ) as rn

   from v_sales_enriched_v2
),

-- Calculate performance metrics
property_metrics_cte as (
   select 
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
           ((last_recorded_price / nullif(first_recorded_price, 0)) - 1) * 100,
           2
       ) as pct_gain,

       -- Holding period in years (year + fractional month)
       round(
           extract(year from age(last_recorded_date, first_recorded_date)) +
           extract(month from age(last_recorded_date, first_recorded_date)) / 12,
           2
       ) as years_tracked,

       -- Annualized return (CAGR-style)
       round(
          (
              power(
                  last_recorded_price / nullif(first_recorded_price, 0),
                  1.0 / GREATEST(
                      extract(year from age(last_recorded_date, first_recorded_date)) +
                      extract(month from age(last_recorded_date, first_recorded_date)) / 12,
                      0.001   -- Prevent division by zero
                  )
              ) - 1
          ) * 100,
          2
      ) as annualized_return

   from property_first_last_cte
   where rn = 1                         -- Keep one row per property
     and count_recorded_sales >= 2      -- Require at least two sales
     and first_recorded_date < last_recorded_date
),

-- Apply data quality and realism filters
filtered_metrics AS (
   SELECT *
   FROM property_metrics_cte
   WHERE first_recorded_price >= 10000     -- Remove distressed / extreme low prices
     AND last_recorded_price >= 10000
     AND annualized_return <= 25           -- Cap unrealistic annual gains
),

-- Top 10 annualized return winners
pct_winner_cte as (
	select *,
       'Winner' as category
	from filtered_metrics
	order by annualized_return desc
	LIMIT 10
),

-- Top 10 annualized return losers
pct_loser_cte as (
	select *,
       'Loser' as category
	from filtered_metrics
	order by annualized_return
	limit 10
),

-- Combine winners and losers
pct_winner_loser_cte as (
	select * from pct_winner_cte
	union
	select * from pct_loser_cte
)

-- Final ordered result
select *
from pct_winner_loser_cte
order by annualized_return desc;
