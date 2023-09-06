/*In question 6 part b we wrote this script:
        Select
	    State
	    ,Count(City) as CityCount
	From Authors
	Group by State
a. Add another column to the script above for "Region." Region is not in the Pubs database. Use the information    below:
State   Region
   CA - West
   IN - Midwest
   KS - Midwest
   MD - Northeast
   MI - Midwest
   OR - West
   TN - Southeast
   UT - West
b. How many cities per Region?
c. How many authors with an active contract per Region? */

=====================================================================================

--a

SELECT [State],
       CASE
            WHEN [State] = 'CA' THEN 'West'
            WHEN [State] = 'IN' THEN 'Midwest'
            WHEN [State] = 'KS' THEN 'Midwest'
            WHEN [State] = 'MD' THEN 'Northeast'
            WHEN [State] = 'MI' THEN 'Midwest'
            WHEN [State] = 'OR' THEN 'West'
            WHEN [State] = 'TN' THEN 'Southeast'
            WHEN [State] = 'UT' THEN 'West' END AS Region,
       COUNT(City) AS CityCount
  FROM Authors
 GROUP BY [State]

--b

SELECT Region,
       COUNT(*) AS RegionCityCount
  FROM (   SELECT [State],
                  City,
                  Region = CASE
                                WHEN [State] = 'CA' THEN 'West'
                                WHEN [State] = 'IN' THEN 'Midwest'
                                WHEN [State] = 'KS' THEN 'Midwest'
                                WHEN [State] = 'MD' THEN 'Northeast'
                                WHEN [State] = 'MI' THEN 'Midwest'
                                WHEN [State] = 'OR' THEN 'West'
                                WHEN [State] = 'TN' THEN 'Southeast'
                                WHEN [State] = 'UT' THEN 'West' END
             FROM Authors) AS SubQ
 GROUP BY Region

--c

SELECT Region,
       COUNT(*) AS ActiveContract
  FROM (   SELECT [State],
                  City,
                  Region = CASE
                                WHEN [State] = 'CA' THEN 'West'
                                WHEN [State] = 'IN' THEN 'Midwest'
                                WHEN [State] = 'KS' THEN 'Midwest'
                                WHEN [State] = 'MD' THEN 'Northeast'
                                WHEN [State] = 'MI' THEN 'Midwest'
                                WHEN [State] = 'OR' THEN 'West'
                                WHEN [State] = 'TN' THEN 'Southeast'
                                WHEN [State] = 'UT' THEN 'West' END
             FROM Authors
            WHERE Contract = 1) AS SubQ
 GROUP BY Region
