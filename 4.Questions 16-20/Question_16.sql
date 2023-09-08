--a. Assume that Sales.Qty multipled by Titles.Price
--(Qty * Price) will give you all the Gross Revenue (not including discounts).
--Using an Inner query, how much revenue has been generated in total (Again, not including discounts)?






====================================================================================

--a

SELECT FORMAT(SUM(Total), 'C0') AS Revenue
  FROM (   SELECT s.Qty,
                  t.Price,
                  s.Qty * t.Price AS Total
             FROM Titles AS t
             JOIN Sales AS s
               ON t.Title_id = s.Title_id) AS SubQ
