-- =====================================================
-- Blinkit Grocery Sales Analysis (SQL only)
-- Dialect: MySQL 8+  (PostgreSQL notes at the bottom)
-- =====================================================

-- -----------------------------------------------------
-- 1. CREATE DATABASE AND IMPORT DATA
-- -----------------------------------------------------
CREATE DATABASE IF NOT EXISTS blinkit;
USE blinkit;

DROP TABLE IF EXISTS grocery_sales_raw;
CREATE TABLE grocery_sales_raw (
    Item_Identifier            VARCHAR(10),
    Item_Weight                VARCHAR(20),   -- VARCHAR so blanks import safely
    Item_Fat_Content           VARCHAR(20),
    Item_Visibility            DECIMAL(10,6),
    Item_Type                  VARCHAR(50),
    Item_MRP                   DECIMAL(10,4),
    Outlet_Identifier          VARCHAR(10),
    Outlet_Establishment_Year  INT,
    Outlet_Size                VARCHAR(20),
    Outlet_Location_Type       VARCHAR(20),
    Outlet_Type                VARCHAR(30),
    Item_Outlet_Sales          DECIMAL(12,4)
);

-- Save your Excel sheet as CSV, then import it.
-- Option A: MySQL Workbench -> right-click table -> Table Data Import Wizard
-- Option B:
-- LOAD DATA LOCAL INFILE 'C:/path/grocery_sales.csv'
-- INTO TABLE grocery_sales_raw
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

SELECT COUNT(*) AS total_rows FROM grocery_sales_raw;   -- expect 8523

-- -----------------------------------------------------
-- 2. DATA QUALITY CHECKS
-- -----------------------------------------------------
-- Messy fat content labels (LF, low fat, reg ...)
SELECT Item_Fat_Content, COUNT(*) AS cnt
FROM grocery_sales_raw
GROUP BY Item_Fat_Content;

-- Missing weights
SELECT COUNT(*) AS missing_weight
FROM grocery_sales_raw
WHERE Item_Weight IS NULL OR TRIM(Item_Weight) = '';

-- Missing outlet size
SELECT COUNT(*) AS missing_outlet_size
FROM grocery_sales_raw
WHERE Outlet_Size IS NULL OR TRIM(Outlet_Size) = '';

-- Zero visibility rows
SELECT COUNT(*) AS zero_visibility
FROM grocery_sales_raw
WHERE Item_Visibility = 0;

-- -----------------------------------------------------
-- 3. DATA CLEANING  (creates grocery_sales)
-- -----------------------------------------------------
DROP TABLE IF EXISTS grocery_sales;

CREATE TABLE grocery_sales AS
WITH base AS (
    SELECT
        Item_Identifier,
        NULLIF(TRIM(Item_Weight), '') + 0 AS Item_Weight,
        CASE
            WHEN LOWER(TRIM(Item_Fat_Content)) IN ('lf', 'low fat') THEN 'Low Fat'
            WHEN LOWER(TRIM(Item_Fat_Content)) IN ('reg', 'regular') THEN 'Regular'
            ELSE Item_Fat_Content
        END AS Item_Fat_Content,
        NULLIF(Item_Visibility, 0) AS Item_Visibility,
        Item_Type,
        Item_MRP,
        Outlet_Identifier,
        Outlet_Establishment_Year,
        COALESCE(NULLIF(TRIM(Outlet_Size), ''), 'Unknown') AS Outlet_Size,
        Outlet_Location_Type,
        Outlet_Type,
        Item_Outlet_Sales
    FROM grocery_sales_raw
)
SELECT
    Item_Identifier,
    -- fill missing weight with the average weight of the same item
    COALESCE(Item_Weight, AVG(Item_Weight) OVER (PARTITION BY Item_Identifier)) AS Item_Weight,
    Item_Fat_Content,
    -- zero visibility treated as missing, then filled with the item's average
    COALESCE(Item_Visibility, AVG(Item_Visibility) OVER (PARTITION BY Item_Identifier)) AS Item_Visibility,
    Item_Type,
    Item_MRP,
    Outlet_Identifier,
    Outlet_Establishment_Year,
    (YEAR(CURDATE()) - Outlet_Establishment_Year) AS Outlet_Age,
    Outlet_Size,
    Outlet_Location_Type,
    Outlet_Type,
    Item_Outlet_Sales
FROM base;

-- Verify the cleaning
SELECT Item_Fat_Content, COUNT(*) AS cnt FROM grocery_sales GROUP BY Item_Fat_Content;
SELECT COUNT(*) AS still_missing_weight FROM grocery_sales WHERE Item_Weight IS NULL;

-- -----------------------------------------------------
-- 4. KPIs  (Q9)
-- -----------------------------------------------------
SELECT
    ROUND(SUM(Item_Outlet_Sales), 2)        AS total_sales,
    ROUND(AVG(Item_MRP), 2)                 AS avg_mrp,
    COUNT(DISTINCT Item_Identifier)         AS number_of_items,
    COUNT(DISTINCT Outlet_Identifier)       AS number_of_outlets
FROM grocery_sales;

-- -----------------------------------------------------
-- 5. BUSINESS QUESTIONS
-- -----------------------------------------------------

-- Q2. Top 10 selling items by total sales
SELECT Item_Identifier, Item_Type,
       ROUND(SUM(Item_Outlet_Sales), 2) AS total_sales
FROM grocery_sales
GROUP BY Item_Identifier, Item_Type
ORDER BY total_sales DESC
LIMIT 10;

-- Q3. Average sales by outlet type
SELECT Outlet_Type,
       ROUND(AVG(Item_Outlet_Sales), 2) AS avg_sales,
       ROUND(SUM(Item_Outlet_Sales), 2) AS total_sales
FROM grocery_sales
GROUP BY Outlet_Type
ORDER BY avg_sales DESC;

-- Q4. Sales by outlet location, with % share
SELECT Outlet_Location_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales,
       ROUND(100 * SUM(Item_Outlet_Sales) / SUM(SUM(Item_Outlet_Sales)) OVER (), 1) AS pct_share
FROM grocery_sales
GROUP BY Outlet_Location_Type
ORDER BY total_sales DESC;

-- Q5. Fat content distribution
SELECT Item_Fat_Content,
       COUNT(*) AS item_count,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM grocery_sales
GROUP BY Item_Fat_Content;

-- Q6. Impact of outlet age / establishment year on sales
SELECT Outlet_Establishment_Year, Outlet_Age,
       COUNT(DISTINCT Outlet_Identifier) AS outlets,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales,
       ROUND(AVG(Item_Outlet_Sales), 2) AS avg_sales
FROM grocery_sales
GROUP BY Outlet_Establishment_Year, Outlet_Age
ORDER BY Outlet_Establishment_Year;

-- Q7. Top selling item types by total sales
SELECT Item_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales
FROM grocery_sales
GROUP BY Item_Type
ORDER BY total_sales DESC;

-- Q8. Average MRP by item type
SELECT Item_Type,
       ROUND(AVG(Item_MRP), 2) AS avg_mrp
FROM grocery_sales
GROUP BY Item_Type
ORDER BY avg_mrp DESC;

-- -----------------------------------------------------
-- 6. EXTRA INSIGHTS  (Q10)
-- -----------------------------------------------------

-- Top item type inside each outlet type (window function)
SELECT Outlet_Type, Item_Type, total_sales
FROM (
    SELECT Outlet_Type, Item_Type,
           ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales,
           RANK() OVER (PARTITION BY Outlet_Type
                        ORDER BY SUM(Item_Outlet_Sales) DESC) AS rnk
    FROM grocery_sales
    GROUP BY Outlet_Type, Item_Type
) t
WHERE rnk = 1;

-- Sales by outlet size and location (cross-analysis)
SELECT Outlet_Size, Outlet_Location_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales
FROM grocery_sales
GROUP BY Outlet_Size, Outlet_Location_Type
ORDER BY total_sales DESC;

-- Does display area (visibility) relate to sales? Bucket and compare.
SELECT
    CASE
        WHEN Item_Visibility < 0.03 THEN 'Low (<3%)'
        WHEN Item_Visibility < 0.08 THEN 'Medium (3-8%)'
        ELSE 'High (>8%)'
    END AS visibility_bucket,
    COUNT(*) AS records,
    ROUND(AVG(Item_Outlet_Sales), 2) AS avg_sales
FROM grocery_sales
GROUP BY visibility_bucket
ORDER BY avg_sales DESC;

-- Price band analysis
SELECT
    CASE
        WHEN Item_MRP < 70  THEN '1. Budget (<70)'
        WHEN Item_MRP < 140 THEN '2. Mid (70-140)'
        WHEN Item_MRP < 210 THEN '3. Premium (140-210)'
        ELSE '4. Luxury (210+)'
    END AS price_band,
    COUNT(*) AS records,
    ROUND(AVG(Item_Outlet_Sales), 2) AS avg_sales
FROM grocery_sales
GROUP BY price_band
ORDER BY price_band;

-- Best performing outlet
SELECT Outlet_Identifier, Outlet_Type, Outlet_Location_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales
FROM grocery_sales
GROUP BY Outlet_Identifier, Outlet_Type, Outlet_Location_Type
ORDER BY total_sales DESC;

-- -----------------------------------------------------
-- 7. "YEAR FILTER" AS A REUSABLE VIEW  (Q11)
-- Change the year to filter any analysis by establishment year.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_sales_by_year AS
SELECT Outlet_Establishment_Year,
       Item_Type,
       ROUND(SUM(Item_Outlet_Sales), 0) AS total_sales,
       ROUND(AVG(Item_MRP), 2) AS avg_mrp
FROM grocery_sales
GROUP BY Outlet_Establishment_Year, Item_Type;

SELECT * FROM v_sales_by_year
WHERE Outlet_Establishment_Year = 1999
ORDER BY total_sales DESC;

-- -----------------------------------------------------
-- PostgreSQL notes:
--  * Replace YEAR(CURDATE()) with EXTRACT(YEAR FROM CURRENT_DATE)
--  * Replace NULLIF(TRIM(x), '') + 0 with NULLIF(TRIM(x), '')::NUMERIC
--  * Replace CREATE OR REPLACE VIEW ... (same) and LIMIT (same)
--  * GROUP BY alias (visibility_bucket / price_band) works in both
-- -----------------------------------------------------
