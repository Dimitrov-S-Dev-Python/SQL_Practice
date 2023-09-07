/*a. Add a new store to the Stores table. Using the information below:
Store_id: 1234
StoreName: "Books, Games, and More"
Address: 678 Main St.
City: Las Vegas
State: NV
Zip: 88901
b. Update the store that was just added. Change the StoreName to "Books and Games"
c. Delete the store from the Stores table.*/
====================================================================================

--a

INSERT INTO Stores (Store_id,
                    StoreName,
                    [Address],
                    City,
                    [State],
                    Zip)
VALUES ('1234', 'Books, Games, and More', '678 Main St.', 'Las Vegas', 'NV', '88901')

--b

UPDATE Stores
   SET StoreName = 'Books and Games'
 WHERE Store_id = '1234'

--c

DELETE FROM Stores
 WHERE Store_id = '1234'
