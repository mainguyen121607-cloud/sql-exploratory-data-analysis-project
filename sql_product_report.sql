/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO
create view gold.report_products as
with cte_base as(
/*---------------------------------------------------------------------------
1. Base Query: Retrieves core columns from fact_sales and dim_products
---------------------------------------------------------------------------*/
select 
	s.order_number,
	s.order_date,
	s.customer_key,
	s.sales_amount,
	s.quantity, 
	s.product_key,
	p.product_name,
	p.category,
	p.subcategory, 
	p.cost
from gold.fact_sales s
left join gold.dim_products p on s.product_key=p.product_key
where order_date is not null
)
, cte_aggregation as(
/*---------------------------------------------------------------------------
3. Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
select
	product_key,
	product_name,
	category,
	subcategory, 
	cost,
	sum(sales_amount) total_sales,
	sum(quantity) as total_quantity,
	count(distinct order_number) total_orders,
	count(distinct customer_key) total_customers,
	max(order_date) last_sale_date,
	datediff(month, min(order_date), max(order_date)) life_span,
	round(avg(cast(sales_amount as float) / nullif(quantity,0)),1) avg_selling_price
from cte_base
group by product_key, 
	product_name,
	category,
	subcategory, 
	cost
)
 /*---------------------------------------------------------------------------
  2. & 4. Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
select
	product_key, 
	product_name,
	category,
	subcategory, 
	cost,
	last_sale_date,
	datediff(month, last_sale_date, getdate()) recency_in_months,
	case	
		when total_sales >100000 then 'High'
		when total_sales >50000 then 'Mid-Range'
		else 'Low'
	end product_segmentation,
	total_quantity,
	total_orders,
	total_sales,
	total_customers,
	life_span,
	avg_selling_price,
	--AOR
	case when total_orders=0 then 0
	else total_sales / total_orders
	end avg_order_rev,
	--avg monthly rev
	case when life_span=0 then total_sales
	else total_sales / life_span
	end avg_monthly_rev
from cte_aggregation
