/*Complete question 7 before attempting this question.
In question 7 part a we added a region column to our query using the information below:
State   Region
   CA - West
   IN - Midwest
   KS - Midwest
   MD - Northeast
   MI - Midwest
   OR - West
   TN - Southeast
   UT - West
a. Write a statement that will add a new column to the Authors table. Call the new column - "Region" and have    the data type be varchar(20).
b. Update the Region column using the logic provided above. For example, UT will be the West Region.
c. Adding the column to the Authors table would make it so a case statement wouldn't be necessary to show region. To keep the Authors table in its original state delete the Region column.*/





=====================================================================================

--a

ALTER TABLE Authors ADD Region VARCHAR(20)

--b

UPDATE Authors
   SET Region = CASE
                     WHEN [State] IN ( 'CA', 'OR', 'UT' ) THEN 'West'
                     WHEN [State] IN ( 'IN', 'KS', 'MI' ) THEN 'Midwest'
                     WHEN [State] = 'MD' THEN 'Northeast'
                     ELSE 'Southeast' END

--c

ALTER TABLE Authors DROP COLUMN Region
