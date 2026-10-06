Markdown
# 🛒 E-Commerce Customer Segmentation & RFM Analytics Pipeline

An advanced SQL-driven data pipeline built in **PostgreSQL** that transforms raw transactional data into actionable behavioral customer segments using **Recency, Frequency, and Monetary (RFM) analysis**.

---

## 📌 Project Overview
In modern e-commerce, understanding customer lifetime value and retention risk is vital. This project models an online retail store's data ecosystem to identify high-value "Champions" and flag churning "At-Risk" customers. 

Instead of basic filtering, this project leverages **Multi-Stage Common Table Expressions (CTEs)** and **Window Functions (`NTILE`)** to dynamically score and segment customers objectively across quintiles.

---

## 🗄️ Database Architecture
The project is built on a relational schema consisting of two core tables:
1. **`customers`**: Stores customer profile details and account signup dates.
2. **`transactions`**: Stores order-level granular data linked to customer accounts via foreign keys.

---

## ⚙️ The SQL Pipeline Breakdown
The core logic flows through a 4-stage pipeline designed for modularity and performance:

1. **Aggregation (`RawRFM`)**: Computes raw behavioral metrics per customer:
   * **Recency:** Days since the customer's last purchase (`CURRENT_DATE - MAX(order_date)`).
   * **Frequency:** Total unique orders placed (`COUNT(DISTINCT transaction_id)`).
   * **Monetary:** Total revenue generated (`SUM(order_amount)`).
2. **Scoring (`ScoredRFM`)**: Utilizes PostgreSQL window functions (`NTILE(5)`) to assign objective quintile grades from 1 to 5.
   * *Note:* Recency uses `ORDER BY ASC` (fewer days = higher score), while Frequency and Monetary use `ORDER BY DESC` (higher value = higher score).
3. **Concatenation & Mapping (`RFM_Segments`)**: Combines individual scores into an RFM cell string and applies conditional business rules (`CASE WHEN`) to categorize users into tiers (*Champions*, *Loyal Customers*, *New Customers*, *At-Risk*, *Lost*).
4. **Business Intelligence Reporting**: Aggregates segments to evaluate revenue concentration and average customer spend.

---

## 💻 Code Snippet: The RFM Pipeline
```sql
WITH RawRFM AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        CURRENT_DATE - MAX(t.order_date) AS Recency,
        COUNT(DISTINCT t.transaction_id) AS Frequency,
        SUM(t.order_amount) AS Monetary
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.customer_name
),
ScoredRFM AS (
    SELECT 
        customer_id,
        customer_name,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency ASC) AS R_Score,     
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score, 
        NTILE(5) OVER (ORDER BY Monetary DESC) AS M_Score   
    FROM RawRFM
),
RFM_Segments AS (
    SELECT 
        customer_id,
        customer_name,
        Recency,
        Frequency,
        Monetary,
        R_Score,
        F_Score,
        M_Score,
        CONCAT(R_Score, F_Score, M_Score) AS RFM_Cell,
        CASE 
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
            WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
            WHEN R_Score <= 2 AND F_Score >= 4 THEN 'At-Risk'
            WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalist'
        END AS Customer_Segment
    FROM ScoredRFM
)
-- Business Summary Report Output
SELECT 
    Customer_Segment,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(Monetary), 2) AS avg_monetary_spend,
    SUM(Monetary) AS total_segment_revenue
FROM RFM_Segments
GROUP BY Customer_Segment
ORDER BY total_segment_revenue DESC;
