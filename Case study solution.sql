CREATE SCHEMA dannys_diner;

CREATE TABLE sales (
  `customer_id` VARCHAR(1),
  `order_date` DATE,
  `product_id` INTEGER
);

INSERT INTO sales
  (`customer_id`, `order_date`, `product_id`)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  `product_id` INTEGER,
  `product_name` VARCHAR(5),
  `price` INTEGER
);

INSERT INTO menu
  (`product_id`, `product_name`, `price`)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  `customer_id` VARCHAR(1),
  `join_date` DATE
);

INSERT INTO members
  (`customer_id`, `join_date`)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
 -- 1. What is the total amount each customer spent at the restaurant?
  
SELECT
	a.customer_id,
  	sum(b.price) as amount_spent
FROM menu as b inner join sales as a on b.product_id = a.product_id
group by a.customer_id
ORDER BY a.customer_id;

-- 2. How many days has each customer visited the restaurant?
select 
	customer_id,
	count(distinct order_date) as 'No of days'
from sales
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
select t.customer_id,m.product_name
from (select *,
	row_number() over(partition by customer_id order by order_date) as r
	from sales) 
    as t inner join menu as m on t.product_id=m.product_id
where t.r=1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select s.product_id,m.product_name,count(s.product_id) as cnt
from sales as s inner join menu as m on s.product_id=m.product_id
group by s.product_id
order by cnt desc
limit 1;
select customer_id,count(product_id)
from sales
where 
	product_id = (
					select product_id
					from sales 
					group by product_id
					order by count(product_id) desc
					limit 1)
group by customer_id;

-- 5. Which item was the most popular for each customer?
select t.customer_id,t.product_id,m.product_name
from (select customer_id,product_id,
	row_number() over(partition by customer_id order by count(product_id) desc) as r
	from sales
	group by customer_id,product_id) as t inner join menu as m on m.product_id=t.product_id
where t.r=1
order by t.customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
select t.customer_id,m.product_name
from (select 
	s.customer_id,
    order_date,
    product_id,
    row_number() over(partition by customer_id) as r
from members as m inner join sales as s on s.customer_id=m.customer_id
where order_date>join_date
order by s.customer_id,order_date) as t inner join menu as m on m.product_id=t.product_id
where t.r=1
order by 1;

-- 7. Which item was purchased just before the customer became a member?
select t.customer_id,m.product_name
from (select 
	s.customer_id,
    order_date,
    product_id,
    rank() over(partition by s.customer_id order by s.customer_id,order_date desc) as r
from members as m inner join sales as s on s.customer_id=m.customer_id
where order_date<join_date) as t inner join menu as m on m.product_id=t.product_id
where t.r=1
order by 1;

-- 8. What is the total items and amount spent for each member before they became a member?
select 
	t.customer_id,
    count(t.product_id) as 'total items',
    sum(m.price) as 'amount spent'
from (select 
	s.customer_id,
    order_date,
    product_id
    #row_number() over(partition by s.customer_id order by s.customer_id,order_date desc) as r
from members as m inner join sales as s on s.customer_id=m.customer_id
where order_date<join_date) as t inner join menu as m on t.product_id=m.product_id
group by t.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select 
	t.customer_id,
    sum(if (m.product_name='sushi',m.price*20,m.price*10)) as points
    #sum(m.price) as 'amount spent'
from sales as t inner join menu as m on t.product_id=m.product_id
group by t.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
-- Considering this query is in continuation with conditions of query 9
select 
	t.customer_id,
    sum(
		if((t.customer_id,t.order_date) in (select s.customer_id,order_date
											from members as m inner join sales as s 
                                            on s.customer_id=m.customer_id
											where order_date>=join_date and order_date<join_date+6)
        ,m.price*20,if (m.product_name='sushi',m.price*20,m.price*10))
		) as points
from sales as t inner join menu as m on t.product_id=m.product_id
where MONTH(t.order_date)=1
group by t.customer_id;

-- Detailed compiled table
select s.customer_id,s.order_date,m.product_name,m.price,
if((s.customer_id,s.order_date) in (select s.customer_id ,s.order_date
					from members as m inner join sales as s on s.customer_id=m.customer_id
                    where order_date>=join_date),
'Y','N') as 'member'
from sales as s inner join menu as m on s.product_id = m.product_id; 

-- Ranking of orders for members only in case of non member NULL

select *,null as ranking 
from (select s.customer_id,s.order_date,m.product_name,m.price,
if((s.customer_id,s.order_date) in (select s.customer_id ,s.order_date
					from members as m inner join sales as s on s.customer_id=m.customer_id
                    where order_date>=join_date),'Y','N') as 'member'
from sales as s inner join menu as m on s.product_id = m.product_id) as t
where t.member='N'
union all
select *,dense_rank() over(partition by t.customer_id 
											order by order_date,product_name) as ranking 
from (select s.customer_id,s.order_date,m.product_name,m.price,
if((s.customer_id,s.order_date) in (select s.customer_id ,s.order_date
					from members as m inner join sales as s on s.customer_id=m.customer_id
                    where order_date>=join_date),'Y','N') as 'member'
from sales as s inner join menu as m on s.product_id = m.product_id) as t
where t.member='Y'
order by customer_id,order_date,product_name
; 





