--a. Show the Sum of YTD_Sales by Book Title. Order by the lowest sum to the highest sum.
--b. If the sum of YTD_Sales is null then have the value be zero.Order by the lowest sum to the highest sum..
--c. Which Type of Book Title has the highest average






=====================================================================================
--a

SELECT Title,
       SUM(YTD_Sales) AS YTD_Sales
  FROM Titles
 GROUP BY Title
 ORDER BY YTD_Sales

--b

SELECT Title,
       ISNULL(SUM(YTD_Sales), 0) AS YTD_Sales
  FROM Titles
 GROUP BY Title
 ORDER BY YTD_Sales

--c

SELECT [Type],
       ISNULL(AVG(YTD_Sales), 0) AS AVG_YTD
  FROM Titles
 GROUP BY [Type]
 ORDER BY AVG(YTD_Sales) DESC
