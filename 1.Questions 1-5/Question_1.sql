--a. How many Employees exist in the Pubs database?

--b. How many Employees have a middle initial?

--c. Based on hire date what is the first and last name of the newest employee?




=====================================================================================

SELECT
	*
FROM
	Employee

-- a

SELECT COUNT(*) AS EmployeeCount
  FROM Employee

--b

SELECT COUNT(MiddleInitial) AS MiddleInitial
  FROM Employee
 WHERE MiddleInitial IS NOT NULL

-- c

SELECT TOP 1 FirstName,
       LastName
  FROM Employee
 ORDER BY Hire_Date DESC
