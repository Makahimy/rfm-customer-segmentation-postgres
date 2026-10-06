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
