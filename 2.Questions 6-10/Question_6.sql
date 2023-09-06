--a. Show a distinct list of States From the Authors table.
--b. Add a count of Cities to the results in part a.
--c. Limit the results from part b to only the following States - CA,UT,OR






====================================================================================

--a

SELECT DISTINCT [State]
  FROM Authors

--b

SELECT [State],
       COUNT(City) AS CityCount
  FROM Authors
 GROUP BY [State]

--c

SELECT [State],
       COUNT(City) AS CityCount
  FROM Authors
 WHERE [State] IN ( 'CA', 'UT', 'OR' )
 GROUP BY [State]
