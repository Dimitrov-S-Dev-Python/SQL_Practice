/*
a. Dean Straight (Author) has changed his phone number to '415 123-1234'. Update his phone number in the Author table.
b. Update his phone number back to '415 834-2919'
c. Find the four authors that live at two addresses. Write a query that will return the four author names (First and Last Name) and the two Addresses.*/





====================================================================================

--a

UPDATE Authors
   SET PhoneNumber = '415 123-1234'
 WHERE LastName = 'Straight'

--b

UPDATE Authors
   SET PhoneNumber = '415 834-2919'
 WHERE LastName = 'Straight'

--c

SELECT a1.FirstName,
       a1.LastName,
       a1.Address
  FROM Authors AS a1
  JOIN Authors AS a2
    ON a1.Address = a2.Address
   AND a1.City    = a2.City
   AND a1.[State] = a2.[State]
 WHERE a1.Authors_id != a2.Authors_id
