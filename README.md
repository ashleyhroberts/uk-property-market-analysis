# 🏠 UK Property Market Analysis (1995–2025)

A structured analysis of 30 years of UK residential property transactions using **PostgreSQL** and **Tableau**.
This project explores how property prices behave across postcode areas, property types, tenure structures, holding periods, and major market shock years.

💼 Deliverables

• [Tableau Public Dashboard](https://public.tableau.com/app/profile/ashley.roberts5700/viz/DAA_InternshipFinal/Q1_Dashboard?publish=yes)  
• [Full Written Report (PDF)](https://github.com/ashleyhroberts/uk-property-market-analysis/blob/main/Snow%20Data%20Science%20Internship%20-%20Team%205_%20UK%20Properties%20Analysis%20Writeup.pdf)  
• All SQL queries used in this analysis are organized by question in the /02_analysis_questions/ folder, with data preparation scripts in /01_data_prep/.

🎯 Project Focus

The analysis answers nine core questions, including:
- How much do properties typically gain between resales?
- Which property types appreciate the most?
- Where are the fastest-growing postcode areas?
- Do new builds command a premium?
- How do leasehold vs freehold properties compare?
- Which individual properties were the biggest winners and losers?
- How did prices behave during 2008 and 2020?

🧠 Methodology Highlights
- Window functions to identify first and last sale per property
- Median-based metrics to reduce skew from outliers
- Annualized return (CAGR-style) calculations
- Minimum price threshold (£10,000) to remove distorted transactions
- 25% annualized cap to exclude mathematically inflated short-hold outliers
- Minimum transaction thresholds for stable postcode comparisons

📊 Tools Used
- PostgreSQL (CTEs, window functions, percentile functions)
- Tableau (interactive dashboards, dynamic filtering)
- GitHub for version control and documentation

🔍 What This Project Demonstrates
- Structured SQL problem-solving
- Thoughtful data cleaning decisions
- Handling of extreme values and edge cases
- Analytical storytelling with business context
- Data Visualization in Tableau
- Clear separation between structural trends and short-term volatility

