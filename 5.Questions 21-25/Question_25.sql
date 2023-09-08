/*
a. Add two columns to the Sales table. The first column will be named: "Revenue" make the data type money. The second column will be named: "RevenueGroup" make the data type varchar(50)
b. Update the Revenue Column to be Titles.Price x Sales.Qty. For example, Order_id "89768" included 32 copies of the book titled "The Busy Executive's Database Guide" which cost $19.99. This means the Revenue will be (19.99 * 32) = $639.68
c. Check to see if Order_id "89768" has revenue of $639.68
d. What is the max revenue for a single Order_id
e. What is the min revenue for a single Order_id
f. What is the avg revenue for a single Order_id
g. Drop both columns - Revenue and RevenueGroup*/

====================================================================================
--a

ALTER TABLE Sales ADD Revenue Money, RevenueGroup VARCHAR(50)

--b

UPDATE Sales
   SET Revenue = (s.Qty * t.Price)
  FROM Sales AS s
  JOIN Titles AS t
    ON s.Title_id = t.Title_id

--d,e,f

SELECT MAX(Revenue) AS MaxRevenue,
       MIN(Revenue) AS MinRevenue,
       AVG(Revenue) AS AvgRevenue
  FROM Sales

--g

ALTER TABLE Employee DROP Revenue, RevenueGroup
