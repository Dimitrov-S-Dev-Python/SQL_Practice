/*
In question 21 part a we wrote the script below:
    Select
		Title
	,Advance
	,Price
	,Advance/Price as AdvanceQty
    From Titles
    Order by Advance desc
a. Add the column below to the script above: Sum(Sales.Qty) as QtySold
*Include all 18 titles (not 16).
b. Create an additional flag column. When the QtySold is greater than AdvanceQty then flag the column as 1. If    the QtySold is less than AdvanceQty the mark as 0. Name the Column "BreakEvenFlag".
c. Based on the results in part b how many titles have yet to generate enough revenue to payoff the authors advance? Write a query to return to results.*/






=====================================================================================

--a

SELECT t.Title,
       t.Advance,
       t.Price,
       t.Advance / t.Price AS AdvanceQty,
       SUM(s.Qty) AS QtySold
  FROM Titles AS t
  LEFT JOIN Sales AS s
    ON t.Title_id = s.Title_id
 GROUP BY Title,
          Advance,
          Price
 ORDER BY AdvanceQty DESC


--b

SELECT t.Title,
       t.Advance,
       t.Price,
       t.Advance / t.Price AS AdvanceQty,
       SUM(s.Qty) AS QtySold,
       CASE
            WHEN Advance / Price < SUM(Qty) THEN 1
            ELSE 0 END AS BreakEvenFlag
  FROM Titles AS t
  LEFT JOIN Sales AS s
    ON t.Title_id = s.Title_id
 GROUP BY Title,
          Advance,
          Price
 ORDER BY AdvanceQty DESC

--c

SELECT *
  FROM (   SELECT t.Title,
                  t.Advance,
                  t.Price,
                  t.Advance / t.Price AS AdvanceQty,
                  SUM(s.Qty) AS QtySold,
                  CASE
                       WHEN Advance / Price < SUM(Qty) THEN 1
                       ELSE 0 END AS BreakEvenFlag
             FROM Titles AS t
             LEFT JOIN Sales AS s
               ON t.Title_id = s.Title_id
            GROUP BY Title,
                     Advance,
                     Price) AS SubQ
 WHERE BreakEvenFlag = 0
   AND QtySold IS NOT NULL
 ORDER BY AdvanceQty DESC
