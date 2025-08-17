/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables!
We tell them, no problem! We can produce a list with all of the appropriate details.

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values).
Find the NULLs and then using COALESCE, replace the NULL with a
blank for the first problem, and 'unit' for the second problem.

HINT: keep the syntax the same, but edited the correct components with the string.
The `||` values concatenate the columns into strings.
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed.
All the other rows will remain the same.) */

-- product_size and product_qty_type could be NULL, so applying coalesce on these:
select
	product_name || ', ' ||
	coalesce(product_size, '') || ' (' ||
	coalesce(product_qty_type, 'unit') || ')'
	as product_details
from product;



--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s
visits to the farmer’s market (labeling each market date with a different number).
Each customer’s first visit is labeled 1, second visit is labeled 2, etc.

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer
(without purchase details) and number those visits.
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

-- ### APPROACH 1, using row_number(): ###
-- Purchases by a customer on the same market date are treated as seperate visits to that market
-- E.g., customer_id=1 made 246 purchases on 107 market dates (multiple purchases on some market dates),
-- visits numbered as 1-246
select
	customer_id, market_date,
	-- partition all rows by customer_id and order each partition by market_date, apply row numbers
	row_number() over (partition by customer_id order by market_date) as visit_number
from customer_purchases
order by customer_id, market_date;

-- ### APPROACH 2, using select distinct and dense_rank(): ###
-- Purchases by a customer on the same market date are treated as a single visit to that market
-- E.g., customer_id=1 made 246 purchases on 107 market dates (multiple purchases on some market dates),
-- visits numbered as 1-107
select distinct -- multiple visits by customer to same market (having same dense rank) are collapesed into one row (distinct)
	customer_id, market_date,
	-- partition all rows by customer_id and order each partition by market_date, apply dense ranks
	dense_rank() over (partition by customer_id order by market_date) as visit_number
from customer_purchases
order by customer_id, market_date;

/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1,
then write another query that uses this one as a subquery (or temp table) and filters the results to
only the customer’s most recent visit. */
select *
from
	(
		select
		customer_id,
		market_date,
		-- partition all rows by customer_id and order each partition by market_date DESC, apply row numbers
		row_number() over (partition by customer_id order by market_date desc) as recent_visit_number
		from customer_purchases
	) as temp
where recent_visit_number = 1 -- filter by the most recent visit number
order by customer_id;


/* 3. Using a COUNT() window function, include a value along with each row of the
customer_purchases table that indicates how many different times that customer has purchased that product_id. */
select distinct
	customer_id, product_id,
	count(*) over (partition by customer_id, product_id) as purchase_count
from customer_purchases
order by customer_id, product_id;


-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic".
These are separated from the product name with a hyphen.
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL.
Remove any trailing or leading whitespaces. Don't just use a case statement for each product!

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

select
	product_name,
	trim(									-- 5. trim leading and trailing white space from substring
		substr(								-- 4. extract the substring after '-' in product_name
			product_name,
			nullif(							-- 2. return null if instr() returns 0 (i.e., '-' not found)
				instr(product_name, '-'), 0	-- 1. return first index of '-' in product_name
			) + 1							-- 3. add 1 to index of '-' so substring starts from the next character
		)
	) as description
from product;



-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following:
1) Create a CTE/Temp Table to find sales values grouped dates;
2) Create another CTE/Temp table with a rank windowed function on the previous query to create
"best day" and "worst day";
3) Query the second temp table twice, once for the best day, once for the worst day,
with a UNION binding them. */


-- APPROACH 1: Using CTE and dense_rank window function; potential ties (if any) for highest and lowest total sales are properly handled
with market_sales as (
	select market_date, sum(quantity * cost_to_customer_per_qty) as total_market_sale 
	from customer_purchases 
	group by market_date
)
select * from (
	-- markets ranked by highest total sales; there can be ties for highest total sales 
	select market_date, total_market_sale, dense_rank() over (order by total_market_sale desc) as sale_rank, 'highest' as rank_label
	from market_sales

	union 

	-- markets ranked by lowest total sales; there can be ties for lowest total sales 
	select market_date, total_market_sale, dense_rank() over (order by total_market_sale) as sale_rank, 'lowest' as rank_label 
	from market_sales
)
where sale_rank = 1;


-- APPROACH 2: Using CTE and subqueries with order by and limit 1; only 1 highest and 1 lowest inspite of ties
-- create the CTE for market total sales 
with market_total_sales as (
	select market_date, sum(quantity * cost_to_customer_per_qty) as total_market_sale 
	from customer_purchases 
	group by market_date
)
-- 1 market with higest total sale
select market_date, total_market_sale, 'highest' as rank_label 
from (select * from market_total_sales order by total_market_sale desc limit 1)

union 

-- 1 market with lowest total sale
select market_date, total_market_sale, 'lowest' as rank_label  
from (select * from market_total_sales order by total_market_sale limit 1); 



/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every**
customer on record. How much money would each vendor make per product?
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows.
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery.
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y).
Before your final group by you should have the product of those two queries (x*y).  */



-- INSERT
/*1.  Create a new table "product_units".
This table will contain only products where the `product_qty_type = 'unit'`.
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.
Name the timestamp column `snapshot_timestamp`. */



/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp).
This can be any product you desire (e.g. add another record for Apple Pie). */



-- DELETE
/* 1. Delete the older record for the whatever product you added.

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/



-- UPDATE
/* 1.We want to add the current_quantity to the product_units table.
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard.
First, determine how to get the "last" quantity per product.
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.)
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column.
Finally, make sure you have a WHERE statement to update the right row,
	you'll need to use product_units.product_id to refer to the correct row within the product_units table.
When you have all of these components, you can run the update statement. */




