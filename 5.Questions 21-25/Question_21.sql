/*
a. Show the number of books that have to be sold to pay for an Authors Advance. Include the following columns:
- Title
- Advance
- Price
- Number of Books to pay for Authors Advance (call this column: "AdvanceQty")
Sort by the Title with the highest advance.
b. Format the AdvanceQty column to include a comma and zero decimals.
c. Format Advance and Price to include a "$" (or your currency of choice) with a comma and two decimals.*/
=====================================================================================

--a

SELECT Title,
       Advance,
       Price,
       Advance / Price AS AdvanceQty
  FROM Titles
 WHERE Advance IS NOT NULL
   AND Advance != 0
 ORDER BY Advance DESC

--b

SELECT Title,
       Advance,
       Price,
       FORMAT(Advance / Price, 'N0') AS AdvanceQty
  FROM Titles
 WHERE Advance IS NOT NULL
   AND Advance != 0
 ORDER BY Advance DESC

--c

SELECT Title,
       FORMAT(Advance, 'C2') AS Advance,
       FORMAT(Price, 'C2') AS Price,
       FORMAT(Advance / Price, 'N0') AS AdvanceQty
  FROM Titles
 WHERE Advance IS NOT NULL
   AND Advance != 0
 ORDER BY Advance DESC
