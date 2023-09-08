/*
a. What authors live in the same city and state as their publisher? Show the following columns:
- Authors First Name
- Authors Last Name
- Publishers Name
- City
- State
b. Now show the authors and publishers that live in the same state, but not the same city.*/

=====================================================================================

--a

SELECT a.FirstName,
       a.LastName,
       p.PublisherName,
       a.City,
       a.[State]
  FROM Authors AS a
  JOIN TitleAuthor AS ta
    ON a.Authors_id = ta.Authors_id
  JOIN Titles AS t
    ON t.Title_id   = ta.Title_id
  JOIN Publishers AS p
    ON t.Pub_id     = p.Pub_id
 WHERE a.City    = p.City
   AND a.[State] = p.[State]


--b

SELECT a.FirstName,
       a.LastName,
       p.PublisherName,
       a.City,
       a.[State]
  FROM Authors AS a
  JOIN TitleAuthor AS ta
    ON a.Authors_id = ta.Authors_id
  JOIN Titles AS t
    ON t.Title_id   = ta.Title_id
  JOIN Publishers AS p
    ON t.Pub_id     = p.Pub_id
 WHERE a.City    != p.City
   AND a.[State] = p.[State]
