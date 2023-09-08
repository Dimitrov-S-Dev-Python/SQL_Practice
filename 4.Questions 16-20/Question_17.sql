/*
a. What two titles exist in the Titles table but not in the sales table?
b. Why don't these Title exist in the sales table?*/






====================================================================================

--a

SELECT t.Title
  FROM Titles AS t
  LEFT JOIN Sales AS s
    ON s.Title_id = t.Title_id
 WHERE s.Title_id IS NULL

--b

SELECT *
  FROM Titles AS t
  LEFT JOIN Sales AS s
    ON s.Title_id = t.Title_id
 WHERE s.Title_id IS NULL
