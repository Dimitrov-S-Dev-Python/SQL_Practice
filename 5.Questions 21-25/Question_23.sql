/*
Jane A Doe was just hired by New Moon Books in Boston, MA.
Her Employee_id is 'JAD12345F',
she was hired on '06/01/2024', and her job_id is '1'.

a. Add her to the Employee table.
Using information above to add all the information below.
- Employee_id
- FirstName
- MiddleInitial
- LastName
- Job_id
- Job_Lvl
- Pub_id
- Hire_Date
b. Delete Jane Doe from the employee table*/



=====================================================================================

--a

INSERT INTO Employee (Employee_id,
                      FirstName,
                      MiddleInitial,
                      Job_id,
                      Job_Lvl,
                      Pub_id,
                      Hire_Date)
VALUES ('JAD12345F', 'Jane', 'A', 'Doe', '1', '10', '0736', '06/01/2024')

--b

DELETE FROM Employee
 WHERE Employee_id = 'JAD12345F'
