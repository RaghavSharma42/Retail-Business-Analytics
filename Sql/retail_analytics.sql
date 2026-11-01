use retail_analytics;

select * from orders;

-- Q1 Which 10 products generate the highest sales?
with tp as (
select product_name , product_id , sum(sales) as total_sales,
row_number() over (
order by sum(sales) desc)as rnk
from orders
group by product_name , product_id)
select product_name, total_sales 
from tp 
where rnk<=10;

-- Q2 Which sub-categories generate the highest and lowest profit?
with ts as (
select sub_category , sum(profit) as total_profit ,
row_number() over (order by sum(profit) desc
)as rnk_high ,
row_number() over (order by sum(profit) asc
)as rnk_low
from orders 
group by sub_category )

select sub_category,
       total_profit,
CASE
        WHEN rnk_high = 1 THEN 'Highest Profit'
        WHEN rnk_low = 1 THEN 'Lowest Profit'
    END AS profit_status
FROM ts
WHERE rnk_high = 1 OR rnk_low = 1;

-- Q3 How do sales and profit change month by month over time?

WITH monthly_sales AS (
    SELECT
        YEAR(order_date) AS sales_year,
        MONTH(order_date) AS sales_month,
        SUM(sales) AS total_sales,
        SUM(profit) AS total_profit
    FROM orders
    GROUP BY
        YEAR(order_date),
        MONTH(order_date)
)
SELECT
    sales_year,
    sales_month,
    total_sales,
    total_profit,
    LAG(total_sales) OVER (
        ORDER BY sales_year, sales_month
    ) AS previous_month_sales,
    LAG(total_profit) OVER (
        ORDER BY sales_year, sales_month
    ) AS previous_month_profit
FROM monthly_sales
ORDER BY sales_year, sales_month;


-- Q4 Which regions generate the highest revenue, and how much does each region contribute to total sales?

with regions as (
select region , sum(sales) as total_sales_region ,
dense_rank() over (order by sum(sales) desc)as rnk
from orders 
group by region)
SELECT
    region,
    total_sales_region,
    ROUND(
        total_sales_region /
        (SELECT SUM(sales) FROM orders) * 100,
        2
    ) AS revenue_contribution,
    rnk
FROM regions;

-- Q5 Which customer segments generate the most profit, and how much revenue does each segment contribute?

WITH ranked AS (
    SELECT
        segment,
        SUM(profit) AS total_profit,
        SUM(sales) AS total_sales_segment,

        DENSE_RANK() OVER (
            ORDER BY SUM(profit) DESC
        ) AS rnk

    FROM orders
    GROUP BY segment
)

SELECT
    segment,
    total_profit,
    total_sales_segment,

    ROUND(
        total_sales_segment /
        (SELECT SUM(sales) FROM orders) * 100, 2
    ) AS revenue_contribution

FROM ranked
ORDER BY rnk;

-- Q6 Which products generate significant sales but operate at a loss?

with ranked as (
select product_name , sum(sales) as total_sales , sum(profit) as total_profit , 
dense_rank() over (order by sum(sales) desc) as rnk
from orders 
group by product_name)

select rnk , product_name , total_sales , total_profit , 
	round(total_profit /NULLIF(total_sales, 0), 2) as profit_margin
from ranked 
where total_sales > '5000' and total_profit < 0 
order by rnk;

-- Q7 Which 10 customers generate the highest revenue for the business?

with ranked as (
select customer_id , customer_name , sum(sales) as total_sales , 
dense_rank() over(order by sum(sales) desc)as rnk
from orders
group by customer_name , customer_id  )

select rnk,customer_id , customer_name , total_sales ,
round(total_sales / (select sum(sales) from orders)*100 , 2) as revenue_contribution
from ranked
where rnk<=10
order by rnk;

-- Q8 How much has the company's revenue grown or declined each year compared with the previous year?

WITH ranked AS (
    SELECT
        SUM(CASE WHEN YEAR(order_date) = 2014
            THEN sales ELSE 0 END) AS sales_2014,

        SUM(CASE WHEN YEAR(order_date) = 2015
            THEN sales ELSE 0 END) AS sales_2015,

        SUM(CASE WHEN YEAR(order_date) = 2016
            THEN sales ELSE 0 END) AS sales_2016,

        SUM(CASE WHEN YEAR(order_date) = 2017
            THEN sales ELSE 0 END) AS sales_2017

    FROM orders
),

growth AS (
    SELECT
        sales_2014,
        sales_2015,
        sales_2016,
        sales_2017,

        ROUND(
            (sales_2015 - sales_2014) /
            NULLIF(sales_2014, 0) * 100, 2
        ) AS yoy_growth_2015,

        ROUND(
            (sales_2016 - sales_2015) /
            NULLIF(sales_2015, 0) * 100, 2
        ) AS yoy_growth_2016,

        ROUND(
            (sales_2017 - sales_2016) /
            NULLIF(sales_2016, 0) * 100, 2
        ) AS yoy_growth_2017

    FROM ranked
)

SELECT
    *,
    CASE
        WHEN yoy_growth_2015 > 0 THEN 'Sales Increased'
        WHEN yoy_growth_2015 < 0 THEN 'Sales Decreased'
        ELSE 'No Change'
    END AS status_2015,

    CASE
        WHEN yoy_growth_2016 > 0 THEN 'Sales Increased'
        WHEN yoy_growth_2016 < 0 THEN 'Sales Decreased'
        ELSE 'No Change'
    END AS status_2016,

    CASE
        WHEN yoy_growth_2017 > 0 THEN 'Sales Increased'
        WHEN yoy_growth_2017 < 0 THEN 'Sales Decreased'
        ELSE 'No Change'
    END AS status_2017

FROM growth;

-- or 

WITH yearly_sales AS (
    SELECT
        YEAR(order_date) AS sales_year,
        SUM(sales) AS total_sales
    FROM orders
    GROUP BY YEAR(order_date)
),

growth AS (
    SELECT
        sales_year,
        total_sales,

        LAG(total_sales) OVER (
            ORDER BY sales_year
        ) AS previous_year_sales

    FROM yearly_sales
)

SELECT
    sales_year,
    total_sales,
    previous_year_sales,

    ROUND(
        (total_sales - previous_year_sales)
        / NULLIF(previous_year_sales, 0) * 100,
        2
    ) AS yoy_growth_percentage,

    CASE
        WHEN previous_year_sales IS NULL THEN 'No Previous Year'
        WHEN total_sales > previous_year_sales THEN 'Sales Increased'
        WHEN total_sales < previous_year_sales THEN 'Sales Decreased'
        ELSE 'No Change'
    END AS growth_status

FROM growth
ORDER BY sales_year;

-- Q9 Are higher discounts reducing the company's profitability?

SELECT
    CASE
        WHEN discount = 0 THEN '0%'
        WHEN discount <= 0.2 THEN '1-20%'
        WHEN discount <= 0.4 THEN '21-40%'
        WHEN discount <= 0.6 THEN '41-60%'
        ELSE 'Above 60%'
    END AS discount_range,

    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,

    ROUND(
        SUM(profit) / NULLIF(SUM(sales), 0) * 100, 2
    ) AS profit_margin

FROM orders

GROUP BY discount_range
ORDER BY MIN(discount);

-- Q10 Which regions generate the highest revenue, and how profitable is each region?

with ranked as  (
select region , sum(sales) as total_sales , sum(profit) as total_profit ,
dense_rank() over (order by sum(sales) desc ) as rnk
from orders 
group by region ),
pf_marg as (
select rnk , region , total_sales , total_profit , 
ROUND(
    (total_profit / NULLIF(total_sales, 0)) * 100, 2
) AS pf_margin
from ranked
)
select rnk , region , total_sales , total_profit , pf_margin
from pf_marg;

-- Q11. Product-Level Sales, Profit & Profit Margin Analysis

select product_name , sum(sales) as total_sales , sum(profit) as total_profit , 
round((sum(profit) / sum(sales))*100,2) as pf_margin
from orders 
where product_name = 'Cisco TelePresence System EX90 Videoconferencing Unit' or product_name = 'HON 5400 Series Task Chairs for Big and Tall'
group by product_name;









