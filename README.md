# Pharmaceutical Sales Analysis & Forecasting

End-to-end analytics project on pharmaceutical sales volume: data cleaning and EDA in **Python**, aggregate analysis in **SQL**, baseline time-series **forecasting**, and an interactive one-page **Power BI** dashboard.


---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Tools & Technologies](#2-tools--technologies)
3. [Dataset](#3-dataset)
4. [Data Cleaning (Python)](#4-data-cleaning-python)
5. [Exploratory Data Analysis](#5-exploratory-data-analysis)
6. [SQL Analysis](#6-sql-analysis)
7. [Sales Forecasting](#7-sales-forecasting)
8. [Power BI Dashboard](#8-power-bi-dashboard)
9. [Key Insights](#9-key-insights)
10. [Data Quality Notes & Limitations](#10-data-quality-notes--limitations)
11. [Repository Structure](#11-repository-structure)
12. [How to Reproduce](#12-how-to-reproduce)
13. [Future Improvements](#13-future-improvements)

---

## 1. Project Overview

**Business questions answered**
- Which drug categories drive the most sales volume?
- How does total sales volume change over time, and is there a seasonal pattern?
- Are there unusual spikes, drops, or data issues in daily sales?
- How accurately can near-term monthly sales be forecast with simple baseline models?

**Workflow:** Raw CSVs → Python cleaning & EDA → SQL aggregation (unpivoted view + window functions) → Forecasting (Naive vs Seasonal Naive) → Power BI dashboard.

## 2. Tools & Technologies

| Stage | Tools |
|---|---|
| Cleaning & EDA | Python, pandas, NumPy, Matplotlib (Jupyter) |
| Forecasting | Python, scikit-learn (MAE / RMSE) |
| Querying | SQL (views, CTEs, `LAG` window functions) |
| Visualization | Power BI Desktop (Power Query, DAX) |

## 3. Dataset

Sales **volume** (units) for eight drug categories identified by ATC codes, at daily and monthly granularity.

| File | Grain | Rows | Period |
|---|---|---|---|
| `pharma_sales_daily_cleaned.csv` | Daily | 2,106 | 2 Jan 2014 – 8 Oct 2019 |
| `pharma_sales_monthly_cleaned.csv` | Monthly | 70 | Jan 2014 – Oct 2019 |

| ATC code | Drug class (grouping) |
|---|---|
| M01AB, M01AE | Anti-inflammatory (pain & inflammation) |
| N02BA, N02BE | Analgesics, aspirin-type / paracetamol-type (pain & inflammation) |
| N05B, N05C | Anxiolytics, hypnotics & sedatives (psycholeptics) |
| R03, R06 | Airway disease drugs, antihistamines (respiratory) |

> Source: _add dataset link here_. The data contains **volume only** (no price/revenue), so all analysis is about demand, not monetary value.

## 4. Data Cleaning (Python)

Notebook: [`notebooks/Pharma_sales_data_cleaning.ipynb`](notebooks/Pharma_sales_data_cleaning.ipynb)

- Renamed raw columns to consistent names (`datum` → `sales_date`, `M01AB` → `m01ab_sales`, …)
- Converted `sales_date` to `datetime`
- Checked missing values and duplicate rows / duplicate dates
- Sorted records chronologically and reset the index
- Created `total_sales_volume` as the sum of the eight category columns
- Exported cleaned daily and monthly files

## 5. Exploratory Data Analysis

Same notebook as above. Questions explored: category contribution, monthly trend, daily spikes/drops, highest and lowest sales days.

**Total sales volume by category (Jan 2014 – Oct 2019, total 126,586 units)**

| Category | Volume | Share |
|---|---|---|
| N02BE | 62,478 | 49.4% |
| N05B | 18,348 | 14.5% |
| R03 | 11,737 | 9.3% |
| M01AB | 10,499 | 8.3% |
| M01AE | 8,156 | 6.4% |
| N02BA | 8,052 | 6.4% |
| R06 | 6,066 | 4.8% |
| N05C | 1,249 | 1.0% |

**Highlights**
- Highest sales day: **30 Dec 2016** (≈199 units). Lowest: 7 Jan 2014 (0 units).
- 26 days recorded zero sales, many of them on public holidays (e.g. 1 Jan, 1 May), so these look like genuine no-trading days rather than errors.
- Weekend days average slightly higher daily volume than weekdays (~61–66 vs ~57–60 units/day), a real but modest effect.

## 6. SQL Analysis

The wide monthly table is unpivoted into a long view with `UNION ALL`, making category-level analysis simple:

```sql
CREATE OR REPLACE VIEW monthly_sales_long AS
SELECT sales_date, 'M01AB' AS drug_category, m01ab_sales AS sales_volume FROM sales_monthly
UNION ALL
SELECT sales_date, 'M01AE', m01ae_sales FROM sales_monthly
-- ... repeated for N02BA, N02BE, N05B, N05C, R03, R06
```

Queries written:

| Question | Technique |
|---|---|
| Which category has the highest total volume? | `GROUP BY`, `ORDER BY`, `LIMIT` |
| How does total volume change month by month? | Aggregation by month |
| Month-over-month % change in total volume | CTE + `LAG()` |
| Which categories show the largest MoM swings? | `LAG()` with `PARTITION BY drug_category` |
| Which days had the highest daily sales? | Top-N on the daily table |

Example (month-over-month growth):

```sql
WITH monthly_totals AS (
    SELECT sales_date, SUM(sales_volume) AS total_sales_volume
    FROM monthly_sales_long
    GROUP BY sales_date
),
growth AS (
    SELECT sales_date, total_sales_volume,
           LAG(total_sales_volume) OVER (ORDER BY sales_date) AS previous_month
    FROM monthly_totals
)
SELECT sales_date, total_sales_volume, previous_month,
       ROUND(100.0 * (total_sales_volume - previous_month)
             / NULLIF(previous_month, 0), 2) AS growth_pct
FROM growth
ORDER BY sales_date;
```

## 7. Sales Forecasting

Notebook: [`notebooks/pharma_sales_forecasting.ipynb`](notebooks/pharma_sales_forecasting.ipynb) · Output: [`data/forecast_results.csv`](data/forecast_results.csv)

**Setup:** monthly `total_sales_volume`, last **12 months held out** as a test set (58 train / 12 test months). Two baseline models were compared:

- **Naive:** next month equals the last observed month.
- **Seasonal Naive:** each month equals the same month one year earlier.

| Model | MAE | RMSE |
|---|---|---|
| Naive | 550.3 | 690.2 |
| **Seasonal Naive** | **372.1** | **587.1** |

Seasonal Naive cut MAE by about **32%** and RMSE by about **15%**, which indicates a repeatable yearly seasonal pattern. It was then used to produce a 3-month forward forecast (Nov 2019 – Jan 2020).

> The test window includes October 2019, which is a partial month (see Data Quality Notes). This inflates the error of both models, so the true accuracy gap is likely larger than shown.

## 8. Power BI Dashboard

**Data model:** monthly data unpivoted in Power Query into a long `Sales (Long)` table, joined to a `Drug Categories` lookup and a dedicated `Date` table (marked as date table); the forecast and daily tables relate to the same `Date` table.

**Dashboard contents (single page)**
- **Slicers:** Year, Category Code, Date range
- **KPI cards:** Total Volume, Avg Monthly Sales, YoY %, Top Category
- **Sales by Category:** sorted horizontal bar chart
- **Monthly Sales Trend:** continuous date axis line chart
- **Actual vs Forecast:** actual line vs dashed Seasonal Naive forecast
- **Model Comparison:** MAE / RMSE table with the better model highlighted
- **Avg Daily Sales by Weekday:** column chart sorted Monday → Sunday

**Sample DAX**

```dax
Total Sales = SUM('Sales (Long)'[Sales Volume])
Sales PY    = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Date'[Date]))
YoY %       = DIVIDE([Total Sales] - [Sales PY], [Sales PY])
Category Share % = DIVIDE([Total Sales], CALCULATE([Total Sales], ALL('Drug Categories')))
```

## 9. Key Insights

1. **One category dominates.** N02BE accounts for ~49% of all volume, so overall demand is highly sensitive to it.
2. **Clear seasonality.** Monthly volume is strongest around December and the autumn–winter months (~2.2K/month in December) and weakest in summer (~1.5K/month in July), which is why Seasonal Naive beats Naive.
3. **Weekly pattern is mild.** Weekends run slightly higher than weekdays.
4. **Forecast outlook.** The Seasonal Naive model projects roughly 2.0K–2.9K units/month for Nov 2019 – Jan 2020.
5. **Annual totals:** 2016 was the peak year (~25.5K units); 2017 is depressed by a data anomaly (below) and 2019 covers only Jan–Oct.

## 10. Data Quality Notes & Limitations

- **October 2019 is a partial month.** Daily data ends on 8 Oct 2019, so the final monthly value (538.6 vs ~1,800 average) is not a real demand collapse. It makes the last point on the trend line and the "latest month" look artificially low.
- **January 2017 total is 1.0 unit**, versus ~2,600 in the surrounding months. This looks like a data gap, and it is the main reason 2017 appears as a low year. It should be confirmed with the data source.
- **The raw daily file had an `hour` column with almost no variance**, so it was dropped from the analysis and dashboard as it carries no real time-of-day signal.
- **Volume only.** No pricing/revenue data is available, so revenue conclusions cannot be drawn.
- **Simple baselines.** Naive and Seasonal Naive are benchmarks, not tuned models, and the test set is only 12 months.

## 11. Repository Structure

```
├── dataset/
│   ├── pharma_sales_daily_cleaned.csv
│   ├── pharma_sales_monthly_cleaned.csv
│   └── forecast_results.csv
├── python/
│   ├── Pharma_sales_data_cleaning.ipynb
│   └── pharma_sales_forecasting.ipynb
├── sql/
│   └── pharma_sales_sql.sql
├── powerbi/
│   └── Pharma_Sales_Overview_Dashboard.pbix
│   └── Pharma_Sales_Dashboard.png
└── README.md
```

## 12. How to Reproduce

1. Clone the repo and install dependencies: `pip install pandas numpy matplotlib scikit-learn jupyter`
2. Run `Pharma_sales_data_cleaning.ipynb` (update the input/output file paths to your local folders).
3. Run `pharma_sales_forecasting.ipynb` to regenerate `forecast_results.csv`.
4. Load the monthly table into a SQL database as `sales_monthly` (and the daily table as `sales_daily`), then run `pharma_sales_sql.sql`.
5. Open the `.pbix` in Power BI Desktop and refresh/repoint the data sources to the files in `data/`.

## 13. Future Improvements

- Add a statistical model (SARIMA / ETS) or Prophet and benchmark it against Seasonal Naive.
- Forecast at the category level, not just total volume.
- Join public drug-pricing data to estimate revenue.
- Investigate and treat the January 2017 anomaly and the partial October 2019 month.
- Publish the dashboard to Power BI Service and link it here.

---

**Author:** Supriya Pote · www.linkedin.com/in/supriyapote21 / supriyapote5255@gmail.com
