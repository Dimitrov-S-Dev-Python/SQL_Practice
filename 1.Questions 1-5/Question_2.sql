--a. How many unique Title_id's are in the TitleAuthor Table?

--b. Show Title_id by a count of Authors_id. Order by count of Authors_id descending






====================================================================================

SELECT
	*
FROM
	TitleAuthor

--a

SELECT COUNT(Title_id) AS CNT,
       COUNT(DISTINCT Title_id) AS DistinctCNT
  FROM TitleAuthor

--b

SELECT Title_id,
       COUNT(Authors_id) AS CNT
  FROM TitleAuthor
 GROUP BY Title_id
 ORDER BY CNT DESC
