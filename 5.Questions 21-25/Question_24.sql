/*
a. Write an Alter Statement that will add a column to the Employee Table. The Column will be called "Gender" and the data type will be varchar(5).
b. Assume the last character in the Employee_id identifies the employee  as either 'M' or 'F' (male or female). For example, the last character in Employee_id 'VPA30890F' is 'F'. Update the Gender Column in part a to either 'M' or 'F'.
c. Drop the Gender column*/





====================================================================================

--a

ALTER TABLE Employee ADD Gender VARCHAR(5)

--b

UPDATE Employee
   SET Gender = RIGHT(Employee_id, 1)

--c

ALTER TABLE Employee DROP COLUMN Gender
