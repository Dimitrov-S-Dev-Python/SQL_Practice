--in Question 2 we learned that Title_id TC7777 has three Authors. See syntax below:
--a. What are the First and Last Names of these three Authors?
--b. Add RoyalTyper. Which Author has the most ownership? Order by highest RoyalTyper.
--c. What is the price of their book? Add price to part a and b, which means you will have the following columns:
--FirstName
--LastName
--RoyalTyper
--Price

=====================================================================================
--a

SELECT a.FirstName,
       a.LastName
  FROM TitleAuthor AS ta
  JOIN Authors AS a
    ON ta.Authors_id = a.Authors_id
 WHERE Title_id = 'TC7777'


--b

SELECT a.FirstName,
       a.LastName,
       ta.RoyalTyper
  FROM TitleAuthor AS ta
  JOIN Authors AS a
    ON ta.Authors_id = a.Authors_id
 WHERE Title_id = 'TC7777'
 ORDER BY ta.RoyalTyper DESC

--c

SELECT a.FirstName,
       a.LastName,
       t.Price
  FROM TitleAuthor AS ta
  JOIN Authors AS a
    ON ta.Authors_id = a.Authors_id
  JOIN Titles AS t
    ON t.Title_id    = ta.Title_id
 WHERE ta.Title_id = 'TC7777'
