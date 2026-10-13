CREATE OR REPLACE VIEW monthly_sales_long AS

SELECT
    sales_date,
    'M01AB' AS drug_category,
    m01ab_sales AS sales_volume
FROM sales_monthly

UNION ALL

SELECT sales_date, 'M01AE', m01ae_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'N02BA', n02ba_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'N02BE', n02be_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'N05B', n05b_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'N05C', n05c_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'R03', r03_sales
FROM sales_monthly

UNION ALL

SELECT sales_date, 'R06', r06_sales
FROM sales_monthly;

SELECT *
FROM monthly_sales_long
LIMIT 10;

--Which drug category has the highest total sales volume?
SELECT drug_category, SUM (sales_volume) total_sales_volume
FROM monthly_sales_long
GROUP BY drug_category
ORDER BY total_sales_volume desc
LIMIT 1;

--How does total sales volume change month by month?

SELECT sales_date, SUM (sales_volume) total_sales_volume
FROM monthly_sales_long
GROUP BY sales_date
ORDER BY total_sales_volume;

--What percentage did total sales volume increase or decrease compared with the previous month?

WITH monthly_totals AS (
    SELECT
        sales_date,
        SUM(sales_volume) AS total_sales_volume
    FROM monthly_sales_long
    GROUP BY sales_date
),
growth AS (
    SELECT
        sales_date,
        total_sales_volume,
        LAG(total_sales_volume) OVER (
            ORDER BY sales_date
        ) AS previous_month
    FROM monthly_totals
)
SELECT
    sales_date,
    total_sales_volume,
    previous_month,
    ROUND(
        100.0 * (
            total_sales_volume - previous_month
        ) / NULLIF(previous_month, 0),
        2
    ) AS growth_pct
FROM growth
ORDER BY sales_date;

--Which drug categories experience the largest month-over-month changes?

WITH category_growth AS (
    SELECT
        sales_date,
        drug_category,
        sales_volume,
        LAG(sales_volume) OVER (
            PARTITION BY drug_category
            ORDER BY sales_date
        ) AS previous_month
    FROM monthly_sales_long
)
SELECT
    sales_date,
    drug_category,
    sales_volume,
    ROUND(
        100.0 * (sales_volume - previous_month)
        / NULLIF(previous_month, 0),
        2
    ) AS growth_pct
FROM category_growth
ORDER BY sales_date, drug_category;

--Which dates recorded the highest daily sales volume?
SELECT
    sales_date,
    total_sales_volume
FROM sales_daily
ORDER BY total_sales_volume DESC
LIMIT 10;
