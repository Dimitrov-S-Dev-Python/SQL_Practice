/*a. Create a new table called: "AudioBooks" include the following columns and data types:
- Audio_id varchar(6)
- Title_id varchar(6)
- NarratorFirstName varchar(40)
- NarratorLastName varchar(20)
- Status varchar(20)
- Royalty int
b. Insert the following values into the AudioBooks Table:
-Audio_id: AU5312
- Title_id: MC3021
- NarratorFirstName: Sandra
- NarratorLastName: Smith
- Status: Completed
- Royalty: 10
c. What is the Title that has a AudioBook?
d. Drop the AudioBooks table*/



=====================================================================================

--a

CREATE TABLE AudioBooks (
    Audio_id VARCHAR(6),
    Title_id VARCHAR(6),
    NarratorFirstName VARCHAR(40),
    NarratorLastName VARCHAR(20),
    [Status] VARCHAR(20),
    Royalty INT)

--b

INSERT INTO AudioBooks (Audio_id,
                        Title_id,
                        NarratorFirstName,
                        NarratorLastName,
                        [Status],
                        Royalty)
VALUES ('AU5312', 'MC3021', 'Sandra', 'Smith', 'Completed', 10)

--c

SELECT Title
  FROM Titles AS t
  JOIN AudioBooks AS ab
    ON ab.Title_id = t.Title_id

--d

DROP TABLE AudioBooks
