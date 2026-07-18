CREATE DATABASE ecommerce_analysis;
USE ecommerce_analysis;
CREATE TABLE retail_data (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description TEXT,
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice FLOAT,
    CustomerID FLOAT,
    Country VARCHAR(50),
    Revenue FLOAT,
    `Month` VARCHAR(10)
);
SHOW TABLES;
SELECT * FROM retail_data LIMIT 10;


-- Monthly Revenue Trend
SELECT `Month`, 
SUM(Revenue) AS monthly_revenue
FROM retail_data
GROUP BY `Month`
ORDER BY `Month`;

-- Top 10 Revenue Generating Customers
SELECT CustomerID,
SUM(Revenue) AS total_spent
FROM retail_data
GROUP BY CustomerID
ORDER BY total_spent DESC
LIMIT 10;

-- Average Order Value
SELECT 
SUM(Revenue)/COUNT(DISTINCT InvoiceNo) 
AS avg_order_value
FROM retail_data;

-- Repeat Customers
SELECT CustomerID,
COUNT(DISTINCT InvoiceNo) AS total_orders
FROM retail_data
GROUP BY CustomerID
HAVING total_orders > 1;

-- One-time Customers
SELECT CustomerID,
COUNT(DISTINCT InvoiceNo) AS total_orders
FROM retail_data
GROUP BY CustomerID
HAVING total_orders = 1;

-- Customer Segmentation
SELECT CustomerID,
SUM(Revenue) AS total_spent,
CASE
    WHEN SUM(Revenue) >= 5000 THEN 'High Value'
    WHEN SUM(Revenue) BETWEEN 1000 AND 4999 THEN 'Medium Value'
    ELSE 'Low Value'
END AS customer_segment
FROM retail_data
GROUP BY CustomerID;

-- Monthly Active Customers
SELECT `Month`,
COUNT(DISTINCT CustomerID) 
AS active_customers
FROM retail_data
GROUP BY `Month`;

-- Revenue Contribution by Country
SELECT Country,
SUM(Revenue) AS total_revenue
FROM retail_data
GROUP BY Country
ORDER BY total_revenue DESC;

-- Revenue Per Customer
SELECT CustomerID,
ROUND(SUM(Revenue),2) 
AS revenue_per_customer
FROM retail_data
GROUP BY CustomerID;

-- Customer Lifetime Value
SELECT CustomerID,
SUM(Revenue) AS lifetime_value
FROM retail_data
GROUP BY CustomerID
ORDER BY lifetime_value DESC;
