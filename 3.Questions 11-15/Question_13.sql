--a. Show all the Book Titles that only have one author. Try answering this question multiple ways.
--b. Show all the Book Titles that only have one author. And the Author has an expired contract.







====================================================================================

--a

SELECT t.Title,
       COUNT(ta.Authors_id) AS CNT
  FROM Titles AS t
  JOIN TitleAuthor AS ta
    ON t.Title_id = ta.Title_id
 GROUP BY t.Title
HAVING COUNT(ta.Authors_id) = 1

--b

SELECT t.Title,
       COUNT(ta.Authors_id) AS CNT
  FROM Titles AS t
  JOIN TitleAuthor AS ta
    ON t.Title_id    = ta.Title_id
  JOIN Authors AS a
    ON ta.Authors_id = a.Authors_id
 WHERE a.Contract = 0
 GROUP BY t.Title
HAVING COUNT(ta.Authors_id) = 1
