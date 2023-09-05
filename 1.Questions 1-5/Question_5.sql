--a. Show the minimum (min) YTD_Sales by Title Type.
--b. Add the maximum (max) YTD_Sales by Title Type.
--c. Add a count of Titles by Title Type
--d. Only show the Min, Max, and Count by Title Type for Title types that have more than 2 titles.





=====================================================================================

--a

SELECT [Type],
       MIN(YTD_Sales) AS MinYTDSales,
       MIN(ISNULL(YTD_Sales, 0)) AS MinYTDSales2
  FROM Titles
 GROUP BY [Type]

--b

SELECT [Type],
       MAX(YTD_Sales) AS MaxYTDSales,
       MAX(ISNULL(YTD_Sales, 0)) AS MaxYTDSales2
  FROM Titles
 GROUP BY [Type]

--c

SELECT [Type],
       MIN(YTD_Sales) AS MinYTDSales,
       MIN(ISNULL(YTD_Sales, 0)) AS MinYTDSales2,
       MAX(YTD_Sales) AS MaxYTDSales,
       MAX(ISNULL(YTD_Sales, 0)) AS MaxYTDSales2,
       COUNT(Title) AS CounTitle
  FROM Titles
 GROUP BY [Type]

--d

SELECT [Type],
       MIN(YTD_Sales) AS MinYTDSales,
       MIN(ISNULL(YTD_Sales, 0)) AS MinYTDSales2,
       MAX(YTD_Sales) AS MaxYTDSales,
       MAX(ISNULL(YTD_Sales, 0)) AS MaxYTDSales2,
       COUNT(Title) AS CounTitle
  FROM Titles
 GROUP BY [Type]
HAVING COUNT(Title) > 2