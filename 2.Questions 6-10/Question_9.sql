--a. Show all of the PublisherNames that are not from the USA.
--b. Which publisher has published the most Books? Show by PublishName and a count of Title_id
--c. Which publisher has the most YTD_Sales? Format the YTD_sales so it shows a dollar sign and comma - For example, $12,345.






=====================================================================================

--a

SELECT PublisherName
  FROM Publishers
 WHERE Country != 'USA'

--b

SELECT p.PublisherName,
       COUNT(t.Title_id) TitleCNT
  FROM Publishers AS p
  JOIN Titles AS t
    ON p.Pub_id = t.Pub_id
 GROUP BY p.PublisherName
 ORDER BY COUNT(t.Title_id) DESC

--c

SELECT p.PublisherName,
       FORMAT(SUM(t.YTD_Sales), 'C0') AS YTD_Sales
  FROM Publishers AS p
  JOIN Titles AS t
    ON p.Pub_id = t.Pub_id
 GROUP BY p.PublisherName
 ORDER BY SUM(t.YTD_Sales) DESC
