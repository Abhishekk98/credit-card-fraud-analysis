# Credit Card Fraud Analysis (Excel + SQL Server + Python + Power BI)

An end-to-end analytics project on a **simulated** credit card dataset: clean a messy dataset, measure fraud, find where and when it happens, test simple detection rules, and present the result in a dashboard.

> **Note:** the data is synthetic (generated for practice) and the patterns are cleaner than real life. Built as a learning project with AI-assisted guidance; every step is documented in the cleaning log.

## Business question
Where, when and how does card fraud happen, and which simple rules can reduce fraud **without** disturbing genuine customers?

## Data
| File | Rows | Description |
|---|---|---|
| `data/raw/credit_card_messy_data.xlsx` | 8,080 transactions, 1,023 customers | Raw data with deliberate quality problems |
| `data/clean/txn_final.csv` | 8,000 | Clean unique transactions |
| `data/clean/cust_final.csv` | 1,000 | Clean unique customers |

## Workflow
1. **Excel** - audit and clean: duplicates, text-stored dates and amounts, impossible dates, placeholder amounts (9,999,999), `N/A` / `-` as missing, inconsistent labels. Every issue is in the Cleaning Log with action and reason, plus before/after reconciliation. Feature columns (hour, amount band, time bucket, city mismatch), hypotheses, pivot analysis and rule simulation.
2. **SQL Server** - load tables, reconcile counts, 15 analysis queries (aggregation, joins, CTEs, window functions, view for BI).
3. **Python** - supporting EDA notebook (charts, chi-square test, customer segmentation, rule evaluation) in `python/fraud_eda.ipynb`.
4. **Power BI** - star schema, date table, DAX measures, 2-page dashboard.

## Key findings
| Finding | Evidence |
|---|---|
| Overall fraud rate | 2.28% (182 of 8,000 transactions) |
| Night (00:00-04:59) is riskiest | 9.7% vs 2.0% in other hours (4.9x) |
| Online is riskier than POS | 3.5% vs 1.3% (2.7x) |
| Large tickets | 20K+ INR: 18.1% vs 1.2% below 5K (15x) |
| Risky categories | Travel, Electronics, Jewellery: 4.2% vs 1.4% for others |
| Location mismatch | 4.0% vs 2.1% when transaction city differs from home city |
| Age and credit limit | Little difference - not useful as fraud rules |
| Top 10 customers | hold about 34% of total fraud amount (1.04M of 3.07M) |
| Outliers kept | 930 high-value transactions hold 45% of all fraud |

## Recommendation
Use a layered rule: step-up authentication for online transactions of 5,000 INR or more (catches about 35% of fraud while touching about 8% of genuine transactions), with a stricter check at night (far more precise, but catches only about 4% of fraud on its own). Monitor Travel, Electronics and Jewellery merchants.

## Dashboard
**Page 1 - Overview:** KPIs, monthly trend, channel, category, ticket size, hour of day, city mismatch, key insights and recommended actions.

![Overview](powerbi/dashboard_overview.png)
**Page 2 - Risk & Action:** top 10 high-risk customers (ranked by fraud amount), and age / credit-limit checks that show no clear fraud signal.

![Risk and action](powerbi/dashboard_risk_action.png)

## Repository structure
```
data/raw/      messy source data
data/clean/    txn_final.csv, cust_final.csv
excel/         Credit_Card_Fraud_Project.xlsx (cleaning log, pivots, charts)
sql/           fraud_analysis.sql
python/        fraud_eda.ipynb
powerbi/       CardFraud.pbix and screenshots
```

## How to reproduce
1. SQL Server: run `sql/fraud_analysis.sql` (edit the CSV folder path).
2. Python: `pip install pandas matplotlib scipy`, put the two CSV files next to the notebook, run all cells.
3. Power BI: open `CardFraud.pbix` (or follow the connect steps) and refresh.

## Limitations
- The Power BI map visual was disabled by the tenant admin, so no geographic map is included; the city view uses a bar chart instead.
- Simulated data; only 182 fraud cases, so rates for small segments are unstable.
- Rules were tested on the same data they were found in (no train/test split).
- 640 transactions have a date but no time, so hour analysis excludes them.

## Tools
Excel (formulas, mapping tables, COUNTIFS, charts), SQL Server (T-SQL), Power BI (data model, DAX, 2-page dashboard), Python (pandas, matplotlib, scipy) for supporting EDA.
