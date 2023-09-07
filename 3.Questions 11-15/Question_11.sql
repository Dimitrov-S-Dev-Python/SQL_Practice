/*a. Pull the following columns. Order by Count of Book Titles DESC.
- FirstName (Authors)
- LastName (Authors)
- PhoneNumber (Authors)
- State (Authors)
- Count of Book Titles
b. Using your results from part a, concatenate FirstName and LastName (be sure to include a space) and call it FullName
c. Only include authors that have 2 Book Titles published and are from the state of 'CA'*/

=====================================================================================

--a

SELECT a.FirstName,
       a.LastName,
       a.PhoneNumber,
       a.[State],
       COUNT(ta.Title_id) AS TitleIdCNT
  FROM Authors AS a
  JOIN TitleAuthor AS ta
    ON a.Authors_id = ta.Authors_id
 GROUP BY a.FirstName,
          a.LastName,
          a.PhoneNumber,
          a.[State]
 ORDER BY TitleIdCNT DESC

--b

SELECT CONCAT_WS(' ', a.FirstName, a.LastName) AS FullName,
       a.PhoneNumber,
       a.[State],
       COUNT(ta.Title_id) AS TitleIdCNT
  FROM Authors AS a
  JOIN TitleAuthor AS ta
    ON a.Authors_id = ta.Authors_id
 GROUP BY a.FirstName,
          a.LastName,
          a.PhoneNumber,
          a.[State]
 ORDER BY TitleIdCNT DESC

--c

SELECT CONCAT_WS(' ', a.FirstName, a.LastName) AS FullName,
       a.PhoneNumber,
       a.[State],
       COUNT(ta.Title_id) AS TitleIdCNT
  FROM Authors AS a
  JOIN TitleAuthor AS ta
    ON a.Authors_id = ta.Authors_id
 WHERE a.[State] = 'CA'
 GROUP BY a.FirstName,
          a.LastName,
          a.PhoneNumber,
          a.[State]
HAVING COUNT(ta.Title_id) >= 2
 ORDER BY COUNT(ta.Title_id)
