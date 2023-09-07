/*
a. How many Books were published between May 1, 2021 and August 31, 2021?
b. Using a case statement show the count of book titles published between May 1, 2021 and August 31, 2021 by month. In other words, recreate what you see below:
MonthName Title_CNT
  May          2
  June         4
  July         4
  August       2
c. Recreate the output (part b) above (without using a case statement).*/
=====================================================================================

--a

SELECT COUNT(Title_id) AS TitleCNT
  FROM Titles
 WHERE Publish_Date BETWEEN '2021-05-01' AND '2021-08-31'

--b

SELECT [Month] AS MonthName,
       COUNT(*) AS TitleCNT
  FROM (   SELECT Title_id,
                  [Month] = CASE
                                 WHEN MONTH(Publish_Date) = 5 THEN 'May'
                                 WHEN MONTH(Publish_Date) = 6 THEN 'June'
                                 WHEN MONTH(Publish_Date) = 7 THEN 'July'
                                 WHEN MONTH(Publish_Date) = 8 THEN 'August' END
             FROM Titles
            WHERE Publish_Date BETWEEN '2021-05-01' AND '2021-08-31') AS SubQ
 GROUP BY [Month]
 ORDER BY [Month] DESC

--c

SELECT DATENAME(MONTH, Publish_Date) AS MonthName,
       COUNT(Title_id) AS TitleCNT
  FROM Titles
 WHERE Publish_Date BETWEEN '2021-05-01' AND '2021-08-31'
 GROUP BY DATENAME(MONTH, Publish_Date)
 ORDER BY MonthName DESC
