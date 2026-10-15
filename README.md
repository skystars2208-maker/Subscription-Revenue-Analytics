# Subscription Revenue and Churn Analytics

SQL + Excel project that analyses a subscription business: monthly revenue (MRR), churn, customer lifetime value (LTV) and cohort retention.

## Tools
- MySQL (data cleaning check, metrics, cohort analysis)
- Excel (cleaning, pivot summaries, dashboard)

## Dataset
5,000 customers (Jan 2022 to Dec 2024). The data is sample data used for learning.
Columns: customer_id, signup_date, cancellation_date, plan_type, monthly_revenue, payment_status, acquisition_channel, region.

## Key findings
- MRR grew to about Rs 13.28 lakh by Dec 2024 (up 99% in 2023 and 52% in 2024).
- Average monthly churn is 4.77%, giving an estimated LTV of about Rs 9,784.
- Premium plan brings 48% of MRR and has the lowest churn.
- Paid Ads has the highest churn (about 58%); Referral has the lowest (about 32%).
- Churn is similar across regions (about 45% to 50%).

## Files
| File | What it is |
|---|---|
| Subscription_Revenue_data_set_Dashboards.xlsx | Cleaned data, metrics, cohort and segment tables, dashboard |
| Cleaned_data.csv | Cleaned dataset used for the SQL import |
| Subscription_Revenue_Project_clean.sql | SQL scripts for all metrics |
| Subscription_Revenue_Project_Report.docx | Full project report |

1. Import `Cleaned_data.csv` into the `subscriptions_raw` table (Table Data Import Wizard).
2. Run `Subscription_Revenue_Project_clean.sql` section by section.
