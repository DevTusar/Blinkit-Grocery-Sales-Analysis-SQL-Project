# 🛒 Blinkit Grocery Sales Analysis | SQL Project

End-to-end data cleaning and business analysis of grocery sales across 10 outlets, done entirely in **SQL (MySQL)**.

---

## 📌 Business Problem
Blinkit wants to know which products, outlet types and locations drive sales so it can focus on the areas that need improvement. This project answers:
- Which items and item categories sell the most?
- How do sales differ across outlet types and location tiers?
- Does the age of an outlet affect its sales?
- Do item price and shelf visibility relate to sales?

## 🗂️ Dataset
- **Rows:** 8,523 | **Columns:** 12 | **Items:** 1,559 | **Outlets:** 10
- **Key columns:** Item_Identifier, Item_Type, Item_Fat_Content, Item_MRP, Item_Visibility, Outlet_Type, Outlet_Location_Type, Outlet_Establishment_Year, Item_Outlet_Sales

## 🛠️ Tools & SQL Concepts
- **Tool:** MySQL 8 (Workbench)
- **Concepts used:** `CREATE TABLE AS`, CTEs, `CASE WHEN`, `COALESCE`, `NULLIF`, aggregations, `GROUP BY`, window functions (`SUM() OVER`, `AVG() OVER (PARTITION BY)`, `RANK()`), views, bucketing/binning

## 🧹 Data Cleaning (in SQL)
| Issue found | Fix |
|---|---|
| Fat content labels inconsistent (`LF`, `low fat`, `reg`) | Standardised to **Low Fat** and **Regular** using `CASE` |
| 1,463 missing `Item_Weight` | Filled with the average weight of the same item (`AVG() OVER (PARTITION BY Item_Identifier)`) |
| 2,410 missing `Outlet_Size` | Marked as **Unknown** |
| 526 rows with `Item_Visibility = 0` | Treated as missing and filled with the item's average |
| No outlet age column | Created `Outlet_Age` from the establishment year |

## 🔍 Analysis Performed
| # | Question | SQL technique |
|---|---|---|
| 1 | KPIs: total sales, average MRP, number of items | Aggregations |
| 2 | Top 10 items by sales | `GROUP BY`, `ORDER BY`, `LIMIT` |
| 3 | Average sales by outlet type | `AVG` |
| 4 | Sales by location with % share | Window function `SUM() OVER ()` |
| 5 | Fat content distribution | `COUNT` with percentage |
| 6 | Outlet age vs sales | Aggregation by establishment year |
| 7 | Top item types by sales | `SUM`, `ORDER BY` |
| 8 | Average MRP by item type | `AVG` |
| 9 | Top item type within each outlet type | `RANK() OVER (PARTITION BY)` |
| 10 | Sales by visibility bucket and price band | `CASE WHEN` binning |
| 11 | Year filter | Reusable **view** |

Full script: [`blinkit_analysis.sql`](blinkit_analysis.sql)

**Sample query**
```sql
SELECT Outlet_Location_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales,
       ROUND(100 * SUM(Item_Outlet_Sales) / SUM(SUM(Item_Outlet_Sales)) OVER (), 1) AS pct_share
FROM grocery_sales
GROUP BY Outlet_Location_Type
ORDER BY total_sales DESC;
```

## 💡 Key Insights
- **Total sales** are about ₹18.59M, with an **average MRP** of about ₹141.
- **Outlet type matters most:** Supermarket Type3 averages about ₹3,694 per record, versus about ₹340 for Grocery Stores.
- **Tier 3 locations** generate the highest total sales (about ₹7.6M), ahead of Tier 2 (about ₹6.5M) and Tier 1 (about ₹4.5M).
- **Fruits & Vegetables** (about ₹2.82M) and **Snack Foods** (about ₹2.73M) are the top two categories.
- *(Add 1-2 insights from your own visibility and price band queries.)*

## 💼 Recommendations
- Focus expansion and stock investment on **Supermarket Type3** style outlets, which earn far more per record than Grocery Stores.
- Prioritise inventory for the top categories (Fruits & Vegetables, Snack Foods).
- Review Tier 1 outlets for underperformance relative to Tier 2 and Tier 3.

## 📁 Project Structure
```
blinkit-sql-analysis/
├── data/                   # grocery_sales.csv
├── blinkit_analysis.sql    # cleaning + all queries
├── screenshots/            # query result screenshots
└── README.md
```

## ▶️ How to Run
1. Install MySQL 8 and open MySQL Workbench.
2. Run the table creation part of `blinkit_analysis.sql`.
3. Import `data/grocery_sales.csv` into `grocery_sales_raw` (Table Data Import Wizard).
4. Run the rest of the script from top to bottom.

## 📝 Note
The dataset has no sales date column, so the year filter uses **Outlet_Establishment_Year**. This is an educational case study with fictional data.


