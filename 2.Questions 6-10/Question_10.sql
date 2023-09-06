--a. Find all the Book Titles that start with "The"
--b. Find the Book Titles that have the word 'Computer' in the Notes column
--c. Find all the Book Titles that aren't a business type.






====================================================================================

--a

SELECT Title
  FROM Titles
 WHERE Title LIKE 'The%'

--b

SELECT Title
  FROM Titles
 WHERE Notes LIKE '%Computer%'

--c

SELECT Title
  FROM Titles
 WHERE [Type] != 'business'
