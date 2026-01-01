/* 1. product name, category, subcategory, and cost
2. segments products by revenue to identify High-Perfomrer, mid, and low
3. aggregate product-level metric: total orders, total sales, total quant sold, total custs (unique), lifespan (in months)
4. Calc valuable KPIs: recency (months since last sale), avg order revenue (AOR), avg monthly rev
then upload to views. */
create view gold.report_products as
 --1.
with cte_base as(
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

 --3.
, cte_aggregation as(
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

 --2. & 4. Final Report
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
