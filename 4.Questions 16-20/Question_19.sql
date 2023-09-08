/*
a. Show the count of employees for each Publisher. Include the following columns:
- Publisher Name
- Count of Employees
    Sort by the most employees to least employees
b. Add the average Job_Lvl
c. Show the results from part b, but exclude any publisher in CA and NY (States)*/


=====================================================================================

--a

SELECT p.PublisherName,
       COUNT(e.Employee_id) AS EmployeeCNT
  FROM Publishers AS p
  JOIN Employee AS e
    ON p.Pub_id = e.Pub_id
 GROUP BY p.PublisherName
 ORDER BY COUNT(e.Employee_id) DESC

--b

SELECT p.PublisherName,
       COUNT(e.Employee_id) AS EmployeeCNT,
       AVG(e.Job_Lvl) AS AvgJob_Lvl
  FROM Publishers AS p
  JOIN Employee AS e
    ON p.Pub_id = e.Pub_id
 GROUP BY p.PublisherName
 ORDER BY COUNT(e.Employee_id) DESC

--c

SELECT p.PublisherName,
       COUNT(e.Employee_id) AS EmployeeCNT,
       AVG(e.Job_Lvl) AS AvgJob_Lvl
  FROM Publishers AS p
  JOIN Employee AS e
    ON p.Pub_id = e.Pub_id
 WHERE p.[State] NOT IN ( 'CA', 'NY' )
 GROUP BY p.PublisherName
 ORDER BY COUNT(e.Employee_id) DESC
