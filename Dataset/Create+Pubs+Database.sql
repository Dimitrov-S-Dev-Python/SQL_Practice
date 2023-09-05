
   
/*                                                                        */
/*              InstPubs.SQL - Creates the Pubs database                  */ 
/*                                                                        */
/*
** Copyright Microsoft, Inc. 1994 - 2000
** All Rights Reserved.
*/

SET NOCOUNT ON
GO

set nocount    on
set dateformat mdy

USE master

declare @dttm varchar(55)
select  @dttm=convert(varchar,getdate(),113)
raiserror('Beginning InstPubs.SQL at %s ....',1,1,@dttm) with nowait

GO

if exists (select * from sysdatabases where name='Pubs')
begin
  raiserror('Dropping existing Pubs database ....',0,1)
  DROP database Pubs
end
GO

CHECKPOINT
go

raiserror('Creating Pubs database....',0,1)
go
/*
   Use default size with autogrow
*/

CREATE DATABASE Pubs
GO

CHECKPOINT

GO

USE Pubs

GO

if db_name() <> 'Pubs'
   raiserror('Error in InstPubs.SQL, ''USE Pubs'' failed!  Killing the SPID now.'
            ,22,127) with log

GO

if CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)<12 
BEGIN
  exec sp_dboption 'Pubs','trunc. log on chkpt.','true'
  exec sp_dboption 'Pubs','select into/bulkcopy','true'
END
ELSE ALTER DATABASE [Pubs] SET RECOVERY SIMPLE WITH NO_WAIT
GO

execute sp_addType id      ,'varchar(11)' ,'NOT NULL'
execute sp_addType tid     ,'varchar(6)'  ,'NOT NULL'
execute sp_addType empid   ,'char(9)'     ,'NOT NULL'

raiserror('Now at the create table section ....',0,1)

GO

CREATE TABLE Authors
(
   Authors_id          id

         CHECK (Authors_id like '[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]')

         CONSTRAINT UPKCL_auidind PRIMARY KEY CLUSTERED,

   LastName       varchar(40)       NOT NULL,
   FirstName       varchar(20)       NOT NULL,

   PhoneNumber          char(12)          NOT NULL

         DEFAULT ('UNKNOWN'),

   Address        varchar(40)           NULL,
   City           varchar(20)           NULL,
   State          char(2)               NULL,

   Zip            char(5)               NULL

         CHECK (Zip like '[0-9][0-9][0-9][0-9][0-9]'),

   Contract       bit               NOT NULL
)

GO

CREATE TABLE Publishers
(
   Pub_id         char(4)           NOT NULL

         CONSTRAINT UPKCL_pubind PRIMARY KEY CLUSTERED

         CHECK (Pub_id in ('1389', '0736', '0877', '1622', '1756')
            OR Pub_id like '99[0-9][0-9]'),

   PublisherName       varchar(40)           NULL,
   City           varchar(20)           NULL,
   State          char(2)               NULL,

   Country        varchar(30)           NULL

         DEFAULT('USA')
)

GO

CREATE TABLE Titles
(
   Title_id tid CONSTRAINT UPKCL_Titleidind PRIMARY KEY CLUSTERED,
   Title          varchar(80)       NOT NULL,
   Type           char(12)          NOT NULL DEFAULT ('UNDECIDED'),
   Pub_id         char(4)               NULL REFERENCES Publishers(Pub_id),
   Price          money                 NULL,
   Advance        money                 NULL,
   Royalty        int                   NULL,
   YTD_Sales      int                   NULL,
   Notes          varchar(200)          NULL,
   Publish_Date        datetime         NULL

         DEFAULT (null)
)

GO

CREATE TABLE TitleAuthor
(
   Authors_id          id

         REFERENCES Authors(Authors_id),

   Title_id       tid

         REFERENCES Titles(Title_id),

   Author_Order         tinyint               NULL,
   RoyalTyper     int                   NULL,


   CONSTRAINT UPKCL_taind PRIMARY KEY CLUSTERED(Authors_id, Title_id)
)

GO

CREATE TABLE Stores
(
   Store_id        char(4)           NOT NULL

         CONSTRAINT UPK_storeid PRIMARY KEY CLUSTERED,

   StoreName      varchar(40)           NULL,
   Address   varchar(40)           NULL,
   City           varchar(20)           NULL,
   State          char(2)               NULL,
   Zip            char(5)               NULL
)

GO

CREATE TABLE Sales
(
   Store_id        char(4)           NOT NULL

         REFERENCES Stores(Store_id),

   Order_id        varchar(20)       NOT NULL,
   Order_Date       datetime          NOT NULL,
   Qty            smallint          NOT NULL,
   PayTerms       varchar(12)       NOT NULL,

   Title_id       tid

         REFERENCES Titles(Title_id),


   CONSTRAINT UPKCL_Sales PRIMARY KEY CLUSTERED (Store_id, Order_id, Title_id)
)

GO

CREATE TABLE RoySched
(
   Title_id       tid

         REFERENCES Titles(Title_id),

   LowRange        int                   NULL,
   HighRange        int                   NULL,
   Royalty        int                   NULL
)

GO

CREATE TABLE Discounts
(
   DiscountType   varchar(40)       NOT NULL,

   Store_id        char(4) NULL

         REFERENCES Stores(Store_id),

   LowQty         smallint              NULL,
   HighQty        smallint              NULL,
   Discount       dec(4,2)          NOT NULL
)

GO

CREATE TABLE Jobs
(
   Job_id         smallint          IDENTITY(1,1)

         PRIMARY KEY CLUSTERED,

   Job_Desc       varchar(50)       NOT NULL

         DEFAULT 'New Position - Title not formalized yet',

   Min_Lvl        tinyint           NOT NULL

         CHECK (Min_Lvl >= 10),

   Max_Lvl        tinyint           NOT NULL

         CHECK (Max_Lvl <= 250)
)

GO

CREATE TABLE Pub_Info
(
   Pub_id         char(4)           NOT NULL

         REFERENCES Publishers(Pub_id)

         CONSTRAINT UPKCL_pubinfo PRIMARY KEY CLUSTERED,

   Logo           image                 NULL,
   PR_Info        text                  NULL
)

GO

CREATE TABLE Employee
(
   Employee_id         empid

         CONSTRAINT PK_Employee_id PRIMARY KEY NONCLUSTERED

         CONSTRAINT CK_Employee_id CHECK (Employee_id LIKE
            '[A-Z][A-Z][A-Z][1-9][0-9][0-9][0-9][0-9][FM]' or
            Employee_id LIKE '[A-Z]-[A-Z][1-9][0-9][0-9][0-9][0-9][FM]'),

   FirstName          varchar(20)       NOT NULL,
   MiddleInitial          char(1)               NULL,
   LastName          varchar(30)       NOT NULL,

   Job_id         smallint          NOT NULL

         DEFAULT 1

         REFERENCES Jobs(Job_id),

   Job_Lvl        tinyint

         DEFAULT 10,

   Pub_id         char(4)           NOT NULL

         DEFAULT ('9952')

         REFERENCES Publishers(Pub_id),

   Hire_Date      datetime          NOT NULL

         DEFAULT (getdate())
)

GO

raiserror('Now at the create trigger section ...',0,1)

GO

CREATE TRIGGER Employee_insupd
ON Employee
FOR insert, UPDATE
AS
--Get the range of level for this job Type from the Jobs table.
declare @Min_Lvl tinyint,
   @Max_Lvl tinyint,
   @emp_lvl tinyint,
   @Job_id smallint
select @Min_Lvl = Min_Lvl,
   @Max_Lvl = Max_Lvl,
   @emp_lvl = i.Job_Lvl,
   @Job_id = i.Job_id
from Employee e, Jobs j, inserted i
where e.Employee_id = i.Employee_id AND i.Job_id = j.Job_id
IF (@Job_id = 1) and (@emp_lvl <> 10)
begin
   raiserror ('Job id 1 expects the default level of 10.',16,1)
   ROLLBACK TRANSACTION
end
ELSE
IF NOT (@emp_lvl BETWEEN @Min_Lvl AND @Max_Lvl)
begin
   raiserror ('The level for Job_id:%d should be between %d and %d.',
      16, 1, @Job_id, @Min_Lvl, @Max_Lvl)
   ROLLBACK TRANSACTION
end

GO

raiserror('Now at the inserts to Authors ....',0,1)

GO

insert Authors
   values('409-56-7008', 'Bennet', 'Abraham', '415 658-9932',
   '6223 Bateman St.', 'Berkeley', 'CA', '94705', 1)
insert Authors
   values('213-46-8915', 'Green', 'Marjorie', '415 986-7020',
   '309 63rd St. #411', 'Oakland', 'CA', '94618', 1)
insert Authors
   values('238-95-7766', 'Carson', 'Cheryl', '415 548-7723',
   '589 Darwin Ln.', 'Berkeley', 'CA', '94705', 1)
insert Authors
   values('998-72-3567', 'Ringer', 'Albert', '801 826-0752',
   '67 Seventh Av.', 'Salt Lake City', 'UT', '84152', 1)
insert Authors
   values('899-46-2035', 'Ringer', 'Anne', '801 826-0752',
   '67 Seventh Av.', 'Salt Lake City', 'UT', '84152', 1)
insert Authors
   values('722-51-5454', 'DeFrance', 'Michel', '219 547-9982',
   '3 Balding Pl.', 'Gary', 'IN', '46403', 1)
insert Authors
   values('807-91-6654', 'Panteley', 'Sylvia', '301 946-8853',
   '1956 Arlington Pl.', 'Rockville', 'MD', '20853', 0)
insert Authors
   values('893-72-1158', 'McBadden', 'Heather',
   '707 448-4982', '301 Putnam', 'Vacaville', 'CA', '95688', 0)
insert Authors
   values('724-08-9931', 'Stringer', 'Dirk', '415 843-2991',
   '5420 Telegraph Av.', 'Oakland', 'CA', '94609', 0)
insert Authors
   values('274-80-9391', 'Straight', 'Dean', '415 834-2919',
   '5420 College Av.', 'Oakland', 'CA', '94609', 1)
insert Authors
   values('756-30-7391', 'Karsen', 'Livia', '415 534-9219',
   '5720 McAuley St.', 'Oakland', 'CA', '94609', 1)
insert Authors
   values('724-80-9391', 'MacFeather', 'Stearns', '415 354-7128',
   '44 Upland Hts.', 'Oakland', 'CA', '94612', 1)
insert Authors
   values('427-17-2319', 'Dull', 'Ann', '415 836-7128',
   '3410 Blonde St.', 'Palo Alto', 'CA', '94301', 1)
insert Authors
   values('672-71-3249', 'Yokomoto', 'Akiko', '415 935-4228',
   '3 Silver Ct.', 'Walnut Creek', 'CA', '94595', 1)
insert Authors
   values('267-41-2394', 'O''Leary', 'Michael', '408 286-2428',
   '22 Cleveland Av. #14', 'San Jose', 'CA', '95128', 1)
insert Authors
   values('472-27-2349', 'Gringlesby', 'Burt', '707 938-6445',
   'PO Box 792', 'Covelo', 'CA', '95428', 3)
insert Authors
   values('527-72-3246', 'Greene', 'Morningstar', '615 297-2723',
   '22 Graybar House Rd.', 'Nashville', 'TN', '37215', 0)
insert Authors
   values('172-32-1176', 'White', 'Johnson', '408 496-7223',
   '10932 Bigge Rd.', 'Menlo Park', 'CA', '94025', 1)
insert Authors
   values('712-45-1867', 'del Castillo', 'Innes', '615 996-8275',
   '2286 Cram Pl. #86', 'Ann Arbor', 'MI', '48105', 1)
insert Authors
   values('846-92-7186', 'Hunter', 'Sheryl', '415 836-7128',
   '3410 Blonde St.', 'Palo Alto', 'CA', '94301', 1)
insert Authors
   values('486-29-1786', 'Locksley', 'Charlene', '415 585-4620',
   '18 Broadway Av.', 'San Francisco', 'CA', '94130', 1)
insert Authors
   values('648-92-1872', 'Blotchet-Halls', 'Reginald', '503 745-6402',
   '55 Hillsdale Bl.', 'Corvallis', 'OR', '97330', 1)
insert Authors
   values('341-22-1782', 'Smith', 'Meander', '913 843-0462',
   '10 Mississippi Dr.', 'Lawrence', 'KS', '66044', 0)

GO

raiserror('Now at the inserts to Publishers ....',0,1)

GO

insert Publishers values('0736', 'New Moon Books', 'Boston', 'MA', 'USA')
insert Publishers values('0877', 'Binnet & Hardley', 'Washington', 'DC', 'USA')
insert Publishers values('1389', 'Algodata Infosystems', 'Berkeley', 'CA', 'USA')
insert Publishers values('9952', 'Scootney Books', 'New York', 'NY', 'USA')
insert Publishers values('1622', 'Five Lakes Publishing', 'Chicago', 'IL', 'USA')
insert Publishers values('1756', 'Ramona Publishers', 'Dallas', 'TX', 'USA')
insert Publishers values('9901', 'GGG&G', 'Mnchen', NULL, 'Germany')
insert Publishers values('9999', 'Lucerne Publishing', 'Paris', NULL, 'France')

GO

raiserror('Now at the inserts to Pub_Info ....',0,1)

GO

insert Pub_Info values('0736', 0x474946383961D3001F00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000D3001F004004FFF0C949ABBD38EBCDBBFF60288E245001686792236ABAB03BC5B055B3F843D3B99DE2AB532A36FB15253B19E5A6231A934CA18CB75C1191D69BF62AAD467F5CF036D8243791369F516ADEF9304AF8F30A3563D7E54CFC04BF24377B5D697E6451333D8821757F898D8E8F1F76657877907259755E5493962081798D9F8A846D9B4A929385A7A5458CA0777362ACAF585E6C6A84AD429555BAA9A471A89D8E8BA2C3C7C82DC9C8AECBCECF1EC2D09143A66E80D3D9BC2C41D76AD28FB2CD509ADAA9AAC62594A3DF81C65FE0BDB5B0CDF4E276DEF6DD78EF6B86FA6C82C5A2648A54AB6AAAE4C1027864DE392E3AF4582BF582DFC07D9244ADA2480BD4C6767BFF32AE0BF3EF603B3907490A4427CE21A7330A6D0584B810664D7F383FA25932488FB96D0F37BDF9491448D1A348937A52CAB4A9D3784EF5E58B4A5545D54BC568FABC9A68DD526ED0A6B8AA17331BD91E5AD9D1D390CED23D88F54A3ACB0A955ADDAD9A50B50D87296E3EB9C76A7CDAABC86B2460040DF34D3995515AB9FF125F1AFA0DAB20A0972382CCB9F9E5AEBC368B21EEDB66EDA15F1347BE2DFDEBB44A7B7C6889240D9473EB73322F4E8D8DBBE14D960B6519BCE5724BB95789350E97EA4BF3718CDD64068D751A261D8B1539D6DCDE3C37F68E1FB58E5DCED8A44477537049852EFD253CEE38C973B7E9D97A488C2979FB936FBAFF2CF5CB79E35830400C31860F4A9BE925D4439F81B6A073BEF1575F593C01A25B26127255D45D4A45B65B851A36C56154678568A20E1100003B,
'This is sample text data for New Moon Books, publisher 0736 in the Pubs database. New Moon Books is located in Boston, Massachusetts.')

insert Pub_Info values('0877', 0x4749463839618B002F00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C000000008B002F004004FFF0C949ABBD38EBCDBBFFA0048464089CE384A62BD596309CC6F4F58A287EBA79ED73B3D26A482C1A8FC8A47249FCCD76BC1F3058D94135579C9345053D835768560CFE6A555D343A1B6D3FC6DC2A377E66DBA5F8DBEBF6EEE1FF2A805B463A47828269871F7A3D7C7C8A3E899093947F666A756567996E6C519E167692646E7D9C98A42295ABAC24A092AD364C737EB15EB61B8E8DB58FB81DB0BE8C6470A0BE58C618BAC365C5C836CEA1BCBBC4C0D0AAD6D14C85CDD86FDDDFAB5F43A580DCB519A25B9BAE989BC3EEA9A7EBD9BF54619A7DF8BBA87475EDA770D6C58B968C59A27402FB99E2378FC7187010D5558948B15CC58B4E20CE9A762E62B558CAB86839FC088D24AB90854662BCD60D653E832BBD7924F49226469327FDEC91C6AD2538972E6FFEE429720D4E63472901251A33A9D28DB47A5A731A7325D56D50B36ADDAA2463D5AF1EAE82F5F84FAA946656AA21AC31D0C4BF85CBA87912D6D194D4B535C5DDDBA93221CB226D022E9437D89C594305FD321C0CB7DFA5C58223036E088F3139B9032563DD0BE66D2ACD8B2BCB9283CEDEE3C6A53EE39BA7579A62C1294917DC473035E0B9E3183F9A3BB6F7ABDE608B018800003B,
'This is sample text data for Binnet & Hardley, publisher 0877 in the Pubs database. Binnet & Hardley is located in Washington, D.C.')

insert Pub_Info values('1389', 0x474946383961C2001D00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000C2001D004004FFF0C949ABBD38EBCDBBFF60288E1C609E2840AE2C969E6D2CCFB339D90F2CE1F8AEE6BC9FEF26EC01413AA3F2D76BAA96C7A154EA7CC29C449AC7A8ED7A2FDC2FED25149B29E4D479FD55A7CBD931DC35CFA4916171BEFDAABC51546541684C8285847151537F898A588D89806045947491757B6C9A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A95A6A3E64169923B0901A775B7566B25D7F8C888A5150BE7B8F93847D8DC3C07983BEBDC1878BCFAF6F44BBD0AD71C9CBD653BFD5CEC7D1C3DFDB8197D8959CB9AAB8B7EBEEEFF0BA92F1B6B5F4A0F6F776D3FA9EBCFD748C01DCB4AB5DBF7C03CF1454070F61423D491C326BA18E211081250C7AB12867619825F37F2ECE1168AC242B6A274556D121D28FA46C11E78564C5B295308F21BBF5CAD6CCE52C7018813932C4ED5C517346B7C1C2683368349D49A19D0439D31538A452A916135A0B19A59AAB9E6A835A0EABD00E5CD11D1D478C1C59714053AA4C4955AB4B9956879AB497F62E1CBA2373DA25B752239F8787119390AB5806C74E1100003B,
'This is sample text data for Algodata Infosystems, publisher 1389 in the Pubs database. Algodata Infosystems is located in Berkeley, California.')

insert Pub_Info values('1622', 0x474946383961F5003400B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000F50034004004FFF0C949ABBD38EBCDBBFF60288E64D90166AA016CEBBEB02ACF746D67E82DC2ACEEFFC0A02997B31027C521EF25698D8E42230E049D3E8AD8537385BC4179DB6B574C26637BE58BF38A1EB393DF2CE55CA52731F77918BE9FAFCD6180817F697F5F6E6C7A836D62876A817A79898A7E31524D708E7299159C9456929F9044777C6575A563A68E827D9D4C8D334BB3B051B6B7B83A8490B91EB4B3BDC1C251A1C24BC3C8C9C8C5C4BFCCCAD0D135ACC36B2E3BBCB655AD1CDB8F6921DEB8D48AA9ADA46046D7E0DC829B9D98E9988878D9AAE5AEF875BC6DEFF7E7A35C9943F18CCA3175C0A4295C48625F3B8610234A0C17D159C289189515CC7531A3C7891BFF9B59FA4812634820F24AAA94882EA50D8BBB3E8813598B8A3D7C0D6F12CB8710E5BA7536D9ED3C458F8B509CF17CE94CEA658F254D944889528306E83C245089629DDA4F8BD65885049ACBB7ADAB2A5364AFDAF344902752409A6085FA39105EBB3C2DAB2E52FA8611B7ACFA060956CB1370598176DB3E74FB956CCCA77207BB6B8CAAAADEA3FFBE01A48CD871D65569C37E25A458C5C9572E57AADE59F7F40A98B456CB36560F730967B3737B74ADBBB7EFDABF830BE70B11F6C8E1C82F31345E33B9F3A5C698FB7D4E9D779083D4B313D7985ABB77E0C9B07F1F0F3EFA71F2E8ED56EB98BEBD7559306FC72C6995EA7499F3B5DDA403FF17538AB6FD20C9FF7D463D531681971888E0104E45069D7C742D58DB7B29B45454811B381420635135B5D838D6E487612F876D98D984B73D2820877DFD871523F5E161D97DD7FCB4C82E31BEC8176856D9D8487D95E1E5D711401AE2448EF11074E47E9D69359382E8A8871391880C28E5861636399950FEFCA55E315D8279255C2C6AA89899B68588961C5B82C366693359F1CA89ACACB959971D76F6E6607B6E410E9D57B1A9196A52BDD56636CC08BA519C5E1EDA8743688906DA9D53F2E367999656A96292E2781397A6264E62A04E25FE49A59354696958409B11F527639DEAC84E7795553A9AACA85C68E8977D2A7919A5A7F83329A46F0D79698BF60D98688CCC118A6C3F8F38E6D89C8C12F635E49145F6132D69DCCE684725FC0546C3B40875D79E70A5867A8274E69E8BAEAC1FEEC02E92EE3AA7ADA015365BEFBE83F2EB6F351100003B,
'This is sample text data for Five Lakes Publishing, publisher 1622 in the Pubs database. Five Lakes Publishing is located in Chicago, Illinois.')

insert Pub_Info values('1756', 0x474946383961E3002500B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000E30025004004FFF0C949ABBD38EBCDBBFF60288E240858E705A4D2EA4E6E0CC7324DD1EB9CDBBAFCE1AC878DE7ABBD84476452C963369F2F288E933A595B404DB27834E67A5FEC37ACEC517D4EB24E5C8D069966361A5E8ED3C3DCA5AA54B9B2AE2D423082817F848286898386858754887B8A8D939094947E918B7D8780959E9D817C18986FA2A6A75A7B22A59B378E1DACAEB18F1940B6A8B8A853727AB5BD4E76676A37BFB9AF2A564D6BC0776E635BCE6DCFD2C3C873716879D4746C6053DA76E0DAB3A133D6D5B290929F9CEAEDEB6FA0C435EF9E97F59896EC28EEFA9DFF69A21C1BB4CA1E3E63084DB42B970FD6407D05C9E59298B0A2C58B18337AA0E88DA3468DC3FFD0692187A7982F5F2271B152162DE54795CEB0F0DAF8EBDA2A932F1FF203B38C484B6ED07674194ACD639679424B4EDB36279B4D3852FE1095266743955138C5209ADA6D5CB26DCDFC644DD351EACF804BCD32421A562DB6965F25AADD11B056BD7BA436C903E82A1D4A3D024769BAE777B0BB7887F51A0E022E9589BCFCE0DD6527597223C4917502ACBCF8D5E6C49F0B6FA60751A7C2748A3EE7DD6B70B5628F9A5873C6DB5936E57EB843C726043B95EBDE394F3584EC7096ED8DA60D86001EBCB9F3E72F99439F0E7DEC7297BA84D9924EFDB11A65566B8EFB510C7CC258DBB7779F7834A9756E6C97D114F95E5429F13CE5F7F9AAF51C996928604710FF544AFDC79717C10CD85157C6EDD75F7EB49C81D45C5EA9674E5BBBA065941BFB45F3D62D5E99E11488516568A15D1292255F635E8045E0520F3E15A0798DB5C5A08105EE52E3884C05255778E6F5C4A287CCB4D84D1D41CE08CD913C56656482EAEDE8E38D71B974553C199EC324573C3669237C585588E52D1ACE049F85521648659556CD83445D27C9F4D68501CE580E31748ED4948C0E3E88959B257C87E39D0A8EC5D812559234996A9EE5B6E864FE31BA5262971DE40FA5B75D9A487A9A79975C6AB5DD06EA6CCA9DB94FA6A1568AD8A4C33DBA6A5995EE5450AC0AA24A9C6DBAE9F6883CB48976D0ABA8D90AA9A88D6246C2ABA3FE8A1B43CA229B9C58AFC11E071AB1D1BE366DB5C9AE85DCA48595466B83AC95C61DA60D1146EEB3BB817ADA40A08CFBDBB2EB9972EB6EDB66D26D71768D5B2B1FEFC65B11AFA5FA96C93AF50AA6AFBEFE263C1DC0FCA2AB8AC210472C310A1100003B,
'This is sample text data for Ramona Publishers, publisher 1756 in the Pubs database. Ramona Publishers is located in Dallas, Texas.')

insert Pub_Info values('9901', 0x4749463839615D002200B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C000000005D0022004004FFF0C949ABBD38EBCDFB03DF078C249895A386AA68BB9E6E0ACE623ABD1BC9E9985DFFB89E8E366BED782C5332563ABA4245A6744AAD5AAF4D2276CBED5EA1D026C528B230CD38B2C92721D78CC4772526748F9F611EB28DE7AFE25E818283604A1E8788898A7385838E8F55856F6C2C1D86392F6B9730708D6C5477673758A3865E92627E94754E173697A6A975809368949BB2AE7B9A6865AA734F80A2A17DA576AA5BB667C290CDCE4379CFD2CE9ED3D6A7CCD7DAA4D9C79341C8B9DF5FC052A8DEBA9BB696767B9C7FD5B8BBF23EABB9706BCAE5F05AB7E6C4C7488DDAF7251BC062530EFE93638C5B3580ECD4951312C217C425E73E89D38709D79D810D393BD20A528CE0AA704AA2D4D3082E583C89BD2C2D720753E1C8922697D44CF6AE53BF6D4041750B4AD467C54548932A1D7374A9D3A789004400003B,
'This is sample text data for GGG&G, publisher 9901 in the Pubs database. GGG&G is located in München, Germany.')

insert Pub_Info values('9952', 0x47494638396107012800B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000070128004004FFF0C949ABBD38EBCDBBFF60288E6469660005AC2C7BB56D05A7D24C4F339E3F765FC716980C3824F28418E4D1A552DA8ACCA5517A7B526F275912690D2A9BD11D14AB8B8257E7E9776BDEE452C2279C47A5CBEDEF2B3C3FBF9FC85981821D7D76868588878A898C8B838F1C8D928E733890829399949B979D9E9FA074A1A3A4A5A6A7458F583E69803F53AF4C62AD5E6DB13B6B3DAEAC6EBA64B365B26BB7ABBEB5C07FB428BCC4C8C1CCC7BBB065637C7A9B7BBE8CDADBDA8B7C31D9E1D88E2FA89E9AE9E49AE7EDA48DA2EEF2F3F4F597AEF6F9FAFBFC805D6CD28C0164C64D18BE3AAD88D87AA5C1DBC07FD59CE54293F0E0882AC39ED9CA2886E3308FB3FF262EBC726D591823204F2E0C09A4A3B32CFEACBC24198D86C48FD3E208D43832E3C0671A2D89737167281AA333219AC048D061499A3C83BEC8090BD84E5A99DE808B730DE9516B727CE85AE7C122BF73EAD29255CB76ADDBB6EC549C8504F7AD5DB37343A98D97576EDDBF7CFB0AEE8457EF5D4E83132BAEB1B8B1E3C749204B9EACB830E5CB984DE1F339A4E1CC88C93CB7D989D72234D1D3A672FEF85055C483C80A06742ADB664F3563119E417D5A8F52DFB1512AEC5D82E9C8662A477FB19A72B6F2E714413F8D0654AA75A8C4C648FDBC346ACDCD5487AFC439BE8BC8E8AA7F6BD77D2B7DF4E6C5882E57DFBDE2F56AEE6D87DFB8BFE06BE7E8F1C6CBCE4D2DC15751803C5956567EFA1D47A041E5F1176183CC1D571D21C2850396565CF5B1D5571D8AC21D08E099A15E85269E87207B1736B31E6FE620324E582116F5215178C86763518A9068DF7FE8C9C6207DCD0104A47B6B717388901EFA27238E3482454E43BB61E8D388F7FD44DD32473E79D43A527633232561E6F86536660256891699D175989A6F1A020A9C75C9D5E68274C619D79D91B5C5189F7906CA67297129D88F9E881A3AA83E8AB623E85E8B0EDAE89C892216E9A584B80318A69C7E3269A7A046FA69A8A4B6094004003B,
'This is sample text data for Scootney Books, publisher 9952 in the Pubs database. Scootney Books is located in New York City, New York.')

insert Pub_Info values('9999', 0x474946383961A9002400B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000A90024004004FFF0C949ABBD38EBCDBBFF60F8011A609E67653EA8D48A702CCFF44566689ED67CEFFF23D58E7513B686444A6EA26B126FC8E74AC82421A7ABE5F4594D61B7BBF0D6F562719A68A07ACDC6389925749AFC6EDBEFBCA24D3E96E2FF803D7A1672468131736E494A8B5C848D8633834B916E598B657E4A83905F7D9B7B56986064A09BA2A68D63603A2E717C9487B2B3209CA7AD52594751B4BD80B65D75B799BEC5BFAF7CC6CACB6638852ACC409F901BD33EB6BCCDC1D1CEA9967B23C082C3709662A69FA4A591E7AE84D87A5FA0AB502F43AC5D74EB9367B0624593FA5CB101ED144173E5F4315AE8485B4287FCBE39E446B1624173FEAC59DC2809594623D9C3388A54E4ACD59C642353E2F098E919319530DD61C405C7CBCB9831C5E5A2192C244E983A3FFE1CDA21282CA248ABB18C25336952A389D689E489B0D24483243B66CD8775A315801AA5A60A6B2DAC074E3741D6BBA8902BA687E9A6D1A3B6D6D15C7460C77AA3E3E556D79EBAF4AAAAB2CFCF578671DFDE657598305D51F7BE5E5A25361ED3388EED0A84B2B7535D6072C1D62DB5588BE5CCA5B1BDA377B99E3CBE9EDA31944A951ADF7DB15263A1429B37BB7E429D8EC4D754B87164078F2B87012002003B,
'This is sample text data for Lucerne Publishing, publisher 9999 in the Pubs database. Lucerne publishing is located in Paris, France.')
GO


raiserror('Now at the inserts to Titles ....',0,1)

GO

insert Titles values ('PC8888', 'Secrets of Silicon Valley', 'popular_comp', '1389',
$20.00, $8000.00, 10, 20100,
'Muckraking reporting on the world''s largest computer hardware and software manufacturers.',
'05/12/24')

insert Titles values ('BU1032', 'The Busy Executive''s Database Guide', 'business',
'1389', $19.99, $5000.00, 10, 19650,
'An overview of available database systems with emphasis on common business applications. Illustrated.',
'07/12/21')

insert Titles values ('PS7777', 'Emotional Security: A New Algorithm', 'psychology',
'0736', $7.99, $4000.00, 10, 3387,
'Protecting yourself and your loved ones from undue emotional stress in the modern world. Use of computer and nutritional aids emphasized.',
'06/12/21')

insert Titles values ('PS3333', 'Prolonged Data Deprivation: Four Case Studies',
'psychology', '0736', $19.99, $2000.00, 10, 10994,
'What happens when the data runs dry?  Searching evaluations of information-shortage effects.',
'05/12/21')

insert Titles values ('BU1111', 'Cooking with Computers: Surreptitious Balance Sheets',
'business', '1389', $11.95, $5000.00, 10, 5843,
'Helpful hints on how to use your electronic resources to the best advantage.',
'08/09/21')

insert Titles values ('MC2222', 'Silicon Valley Gastronomic Treats', 'mod_cook', '0877',
$19.99, $0.00, 12, 14912,
'Favorite recipes for quick, easy, and elegant meals.',
'07/09/21')

insert Titles values ('TC7777', 'Sushi, Anyone?', 'trad_cook', '0877', $14.99, $8000.00,
10, 8409,
'Detailed instructions on how to make authentic Japanese sushi in your spare time.',
'07/12/21')

insert Titles values ('TC4203', 'Fifty Years in Buckingham Palace Kitchens', 'trad_cook',
'0877', $11.95, $4000.00, 14, 6453,
'More anecdotes from the Queen''s favorite cook describing life among English Royalty. Recipes, techniques, tender vignettes.',
'05/12/21')

insert Titles values ('PC1035', 'But Is It User Friendly?', 'popular_comp', '1389',
$22.95, $7000.00, 16, 4612,
'A survey of software for the naive user, focusing on the ''friendliness'' of each.',
'06/30/21')

insert Titles values('BU2075', 'You Can Combat Computer Stress!', 'business', '0736',
$2.99, $10125.00, 24, 1477,
'The latest medical and psychological techniques for living with the electronic office. Easy-to-understand explanations.',
'06/30/21')

insert Titles values('PS2091', 'Is Anger the Enemy?', 'psychology', '0736', $10.95,
$2275.00, 12, 22239,
'Carefully researched study of the effects of strong emotions on the body. Metabolic charts included.',
'08/15/21')

insert Titles values('PS2106', 'Life Without Fear', 'psychology', '0736', $7.00, $6000.00,
10, 3710,
'New exercise, meditation, and nutritional techniques that can reduce the shock of daily interactions. Popular audience. Sample menus included, exercise video available separately.',
'10/05/21')

insert Titles values('MC3021', 'The Gourmet Microwave', 'mod_cook', '0877', $2.99,
$15000.00, 24, 4099,
'Traditional French gourmet recipes adapted for modern microwave cooking.',
'06/18/21')

insert Titles values('TC3218', 'Onions, Leeks, and Garlic: Cooking Secrets of the Mediterranean',
'trad_cook', '0877', $20.95, $7000.00, 10, 7646,
'Profusely illustrated in color, this makes a wonderful gift book for a cuisine-oriented friend.',
'10/21/21')

insert Titles (Title_id, Title, Pub_id) values('MC3026',
'The Psychology of Computer Cooking', '0877')

insert Titles values ('BU7832', 'Straight Talk About Computers', 'business', '1389',
$19.99, $5000.00, 10, 9915,
'Annotated analysis of what computers can do for you: a no-hype guide for the critical user.',
'07/22/21')

insert Titles values('PS1372', 'Computer Phobic AND Non-Phobic Individuals: Behavior Variations',
'psychology', '0877', $21.59, $7000.00, 10, 9391,
'A must for the specialist, this book examines the difference between those who hate and fear computers and those who don''t.',
'10/21/21')

insert Titles (Title_id, Title, Type, Pub_id, Notes) values('PC9999', 'Net Etiquette',
'popular_comp', '1389', 'A must-read for computer conferencing.')

GO

raiserror('Now at the inserts to TitleAuthor ....',0,1)

GO

insert TitleAuthor values('409-56-7008', 'BU1032', 1, 60)
insert TitleAuthor values('486-29-1786', 'PS7777', 1, 100)
insert TitleAuthor values('486-29-1786', 'PC9999', 1, 100)
insert TitleAuthor values('712-45-1867', 'MC2222', 1, 100)
insert TitleAuthor values('172-32-1176', 'PS3333', 1, 100)
insert TitleAuthor values('213-46-8915', 'BU1032', 2, 40)
insert TitleAuthor values('238-95-7766', 'PC1035', 1, 100)
insert TitleAuthor values('213-46-8915', 'BU2075', 1, 100)
insert TitleAuthor values('998-72-3567', 'PS2091', 1, 50)
insert TitleAuthor values('899-46-2035', 'PS2091', 2, 50)
insert TitleAuthor values('998-72-3567', 'PS2106', 1, 100)
insert TitleAuthor values('722-51-5454', 'MC3021', 1, 75)
insert TitleAuthor values('899-46-2035', 'MC3021', 2, 25)
insert TitleAuthor values('807-91-6654', 'TC3218', 1, 100)
insert TitleAuthor values('274-80-9391', 'BU7832', 1, 100)
insert TitleAuthor values('427-17-2319', 'PC8888', 1, 50)
insert TitleAuthor values('846-92-7186', 'PC8888', 2, 50)
insert TitleAuthor values('756-30-7391', 'PS1372', 1, 75)
insert TitleAuthor values('724-80-9391', 'PS1372', 2, 25)
insert TitleAuthor values('724-80-9391', 'BU1111', 1, 60)
insert TitleAuthor values('267-41-2394', 'BU1111', 2, 40)
insert TitleAuthor values('672-71-3249', 'TC7777', 1, 40)
insert TitleAuthor values('267-41-2394', 'TC7777', 2, 30)
insert TitleAuthor values('472-27-2349', 'TC7777', 3, 30)
insert TitleAuthor values('648-92-1872', 'TC4203', 1, 100)

GO

raiserror('Now at the inserts to Stores ....',0,1)

GO

insert Stores values('7066','Barnum''s','567 Pasadena Ave.','Tustin','CA','92789')
insert Stores values('7067','News & Brews','577 First St.','Los Gatos','CA','96745')
insert Stores values('7131','Doc-U-Mat: Quality Laundry and Books',
      '24-A Avogadro Way','Remulade','WA','98014')
insert Stores values('8042','Bookbeat','679 Carson St.','Portland','OR','89076')
insert Stores values('6380','Eric the Read Books','788 Catamaugus Ave.',
      'Seattle','WA','98056')
insert Stores values('7896','Fricative Bookshop','89 Madison St.','Fremont','CA','90019')

GO

raiserror('Now at the inserts to Sales ....',0,1)

GO

Insert Sales Values('6380', '89768', '01/26/2024', 32, 'Net 60', 'BU1032')
Insert Sales Values('6380', '89771', '03/27/2023', 25, 'Net 60', 'PS2091')
Insert Sales Values('7066', '89774', '06/21/2024', 79, 'Net 30', 'PC8888')
Insert Sales Values('7066', '89777', '01/04/2023', 73, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '89780', '08/02/2020', 102, 'Net 60', 'PS2091')
Insert Sales Values('7067', '89783', '12/10/2023', 8, 'Net 30', 'TC3218')
Insert Sales Values('7067', '89786', '12/10/2020', 63, 'Net 30', 'TC4203')
Insert Sales Values('7067', '89789', '08/13/2024', 31, 'Net 30', 'TC7777')
Insert Sales Values('7131', '89792', '05/21/2022', 28, 'Net 30', 'PS2091')
Insert Sales Values('7131', '89795', '08/21/2021', 72, 'Net 30', 'MC3021')
Insert Sales Values('7131', '89798', '07/05/2023', 63, 'Net 60', 'PS1372')
Insert Sales Values('7131', '89801', '04/02/2023', 70, 'Net 60', 'PS2106')
Insert Sales Values('7131', '89804', '07/30/2022', 82, 'Net 60', 'PS3333')
Insert Sales Values('7131', '89807', '05/01/2021', 74, 'Net 60', 'PS7777')
Insert Sales Values('7896', '89810', '07/27/2024', 44, 'Net 60', 'BU7832')
Insert Sales Values('7896', '89813', '08/26/2024', 102, 'Net 60', 'MC2222')
Insert Sales Values('7896', '89816', '11/08/2021', 47, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '89819', '09/19/2020', 90, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '89822', '08/16/2022', 50, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '89825', '01/25/2024', 58, 'Net 30', 'BU1111')
Insert Sales Values('8042', '89828', '03/20/2021', 66, 'Net 30', 'PC1035')
Insert Sales Values('6380', '89831', '04/18/2023', 9, 'Net 60', 'BU1032')
Insert Sales Values('6380', '89834', '01/21/2024', 45, 'Net 60', 'PS2091')
Insert Sales Values('7066', '89837', '08/07/2023', 33, 'Net 30', 'PC8888')
Insert Sales Values('7066', '89840', '04/27/2024', 49, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '89843', '02/19/2023', 16, 'Net 60', 'PS2091')
Insert Sales Values('7067', '89846', '08/18/2024', 102, 'Net 30', 'TC3218')
Insert Sales Values('7067', '89849', '03/21/2021', 26, 'Net 30', 'TC4203')
Insert Sales Values('7067', '89852', '06/06/2022', 93, 'Net 30', 'TC7777')
Insert Sales Values('7131', '89855', '12/31/2023', 71, 'Net 30', 'PS2091')
Insert Sales Values('7131', '89858', '04/10/2022', 9, 'Net 30', 'MC3021')
Insert Sales Values('7131', '89861', '10/28/2021', 9, 'Net 60', 'PS1372')
Insert Sales Values('7131', '89864', '12/21/2020', 22, 'Net 60', 'PS2106')
Insert Sales Values('7131', '89867', '10/23/2022', 57, 'Net 60', 'PS3333')
Insert Sales Values('7131', '89870', '03/23/2024', 50, 'Net 60', 'PS7777')
Insert Sales Values('7896', '89873', '07/10/2020', 54, 'Net 60', 'BU7832')
Insert Sales Values('7896', '89876', '06/04/2023', 6, 'Net 60', 'MC2222')
Insert Sales Values('7896', '89879', '04/14/2024', 22, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '89882', '02/11/2022', 56, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '89885', '11/28/2023', 98, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '89888', '06/11/2024', 82, 'Net 30', 'BU1111')
Insert Sales Values('8042', '89891', '04/19/2023', 13, 'Net 30', 'PC1035')
Insert Sales Values('6380', '89894', '04/27/2021', 97, 'Net 60', 'BU1032')
Insert Sales Values('6380', '89897', '11/15/2022', 57, 'Net 60', 'PS2091')
Insert Sales Values('7066', '89900', '04/23/2024', 52, 'Net 30', 'PC8888')
Insert Sales Values('7066', '89903', '01/23/2023', 29, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '89906', '10/07/2020', 49, 'Net 60', 'PS2091')
Insert Sales Values('7067', '89909', '11/10/2022', 82, 'Net 30', 'TC3218')
Insert Sales Values('7067', '89912', '08/12/2023', 40, 'Net 30', 'TC4203')
Insert Sales Values('7067', '89915', '06/24/2021', 57, 'Net 30', 'TC7777')
Insert Sales Values('7131', '89918', '11/08/2023', 99, 'Net 30', 'PS2091')
Insert Sales Values('7131', '89921', '02/03/2022', 75, 'Net 30', 'MC3021')
Insert Sales Values('7131', '89924', '06/08/2021', 53, 'Net 60', 'PS1372')
Insert Sales Values('7131', '89927', '12/25/2022', 91, 'Net 60', 'PS2106')
Insert Sales Values('7131', '89930', '10/28/2023', 7, 'Net 60', 'PS3333')
Insert Sales Values('7131', '89933', '07/27/2021', 26, 'Net 60', 'PS7777')
Insert Sales Values('7896', '89936', '04/06/2021', 51, 'Net 60', 'BU7832')
Insert Sales Values('7896', '89939', '11/26/2022', 23, 'Net 60', 'MC2222')
Insert Sales Values('7896', '89942', '06/04/2024', 25, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '89945', '04/29/2023', 72, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '89948', '05/20/2021', 83, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '89951', '08/07/2020', 70, 'Net 30', 'BU1111')
Insert Sales Values('8042', '89954', '05/17/2021', 22, 'Net 30', 'PC1035')
Insert Sales Values('6380', '89957', '07/09/2022', 46, 'Net 60', 'BU1032')
Insert Sales Values('6380', '89960', '05/08/2021', 30, 'Net 60', 'PS2091')
Insert Sales Values('7066', '89963', '02/10/2022', 89, 'Net 30', 'PC8888')
Insert Sales Values('7066', '89966', '05/07/2021', 79, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '89969', '01/14/2022', 72, 'Net 60', 'PS2091')
Insert Sales Values('7067', '89972', '09/23/2023', 61, 'Net 30', 'TC3218')
Insert Sales Values('7067', '89975', '04/07/2022', 37, 'Net 30', 'TC4203')
Insert Sales Values('7067', '89978', '10/28/2021', 60, 'Net 30', 'TC7777')
Insert Sales Values('7131', '89981', '11/02/2022', 56, 'Net 30', 'PS2091')
Insert Sales Values('7131', '89984', '07/10/2021', 55, 'Net 30', 'MC3021')
Insert Sales Values('7131', '89987', '03/18/2024', 13, 'Net 60', 'PS1372')
Insert Sales Values('7131', '89990', '05/26/2024', 23, 'Net 60', 'PS2106')
Insert Sales Values('7131', '89993', '03/07/2023', 47, 'Net 60', 'PS3333')
Insert Sales Values('7131', '89996', '03/02/2022', 19, 'Net 60', 'PS7777')
Insert Sales Values('7896', '89999', '12/07/2021', 21, 'Net 60', 'BU7832')
Insert Sales Values('7896', '90002', '02/23/2022', 97, 'Net 60', 'MC2222')
Insert Sales Values('7896', '90005', '12/07/2021', 22, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '90008', '12/30/2023', 92, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '90011', '11/30/2020', 94, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '90014', '08/06/2021', 39, 'Net 30', 'BU1111')
Insert Sales Values('8042', '90017', '02/09/2021', 17, 'Net 30', 'PC1035')
Insert Sales Values('6380', '90020', '11/09/2021', 86, 'Net 60', 'BU1032')
Insert Sales Values('6380', '90023', '03/30/2021', 82, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90026', '06/29/2024', 39, 'Net 30', 'PC8888')
Insert Sales Values('7066', '90029', '02/27/2024', 98, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '90032', '10/21/2021', 42, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90035', '07/03/2024', 13, 'Net 30', 'TC3218')
Insert Sales Values('7067', '90038', '11/24/2020', 24, 'Net 30', 'TC4203')
Insert Sales Values('7067', '90041', '08/08/2023', 68, 'Net 30', 'TC7777')
Insert Sales Values('7131', '90044', '06/09/2022', 33, 'Net 30', 'PS2091')
Insert Sales Values('7131', '90047', '04/29/2022', 94, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90050', '10/31/2023', 72, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90053', '12/22/2020', 28, 'Net 60', 'PS2106')
Insert Sales Values('7131', '90056', '12/21/2022', 81, 'Net 60', 'PS3333')
Insert Sales Values('7131', '90059', '11/30/2023', 100, 'Net 60', 'PS7777')
Insert Sales Values('7896', '90062', '08/10/2022', 12, 'Net 60', 'BU7832')
Insert Sales Values('7896', '90065', '10/29/2023', 72, 'Net 60', 'MC2222')
Insert Sales Values('7896', '90068', '11/17/2020', 40, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '90071', '08/17/2023', 40, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '90074', '10/07/2023', 105, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '90077', '11/21/2021', 55, 'Net 30', 'BU1111')
Insert Sales Values('8042', '90080', '09/23/2023', 27, 'Net 30', 'PC1035')
Insert Sales Values('8042', '90083', '07/08/2020', 10, 'Net 60', 'BU1032')
Insert Sales Values('8042', '90086', '02/28/2021', 36, 'Net 60', 'PS2091')
Insert Sales Values('8042', '90089', '07/18/2020', 73, 'Net 30', 'PC8888')
Insert Sales Values('6380', '90092', '10/24/2022', 37, 'ON invoice', 'PS2091')
Insert Sales Values('6380', '90095', '06/21/2024', 5, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90098', '03/10/2021', 44, 'Net 30', 'TC3218')
Insert Sales Values('7066', '90101', '09/04/2020', 24, 'Net 30', 'TC4203')
Insert Sales Values('7067', '90104', '03/31/2021', 82, 'Net 30', 'TC7777')
Insert Sales Values('7067', '90107', '01/26/2024', 70, 'Net 30', 'PS2091')
Insert Sales Values('7067', '90110', '10/08/2021', 46, 'Net 30', 'MC3021')
Insert Sales Values('7067', '90113', '05/02/2024', 88, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90116', '05/25/2021', 48, 'Net 60', 'PS2106')
Insert Sales Values('7131', '90119', '10/07/2022', 33, 'Net 60', 'PS3333')
Insert Sales Values('7131', '90122', '06/30/2022', 59, 'Net 60', 'PS7777')
Insert Sales Values('7131', '90125', '11/30/2022', 63, 'Net 60', 'BU7832')
Insert Sales Values('7131', '90128', '07/08/2024', 82, 'Net 60', 'MC2222')
Insert Sales Values('7131', '90131', '05/15/2022', 31, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '90134', '02/08/2024', 63, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '90137', '02/26/2021', 19, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '90140', '06/06/2023', 62, 'Net 30', 'BU1111')
Insert Sales Values('8042', '90143', '07/29/2022', 72, 'Net 30', 'PC1035')
Insert Sales Values('6380', '90146', '02/25/2023', 97, 'Net 60', 'BU1032')
Insert Sales Values('6380', '90149', '07/28/2023', 27, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90152', '05/05/2024', 26, 'Net 30', 'PC8888')
Insert Sales Values('7066', '90155', '09/24/2020', 10, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '90158', '03/18/2022', 93, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90161', '03/19/2021', 54, 'Net 30', 'TC3218')
Insert Sales Values('7067', '90164', '08/06/2024', 69, 'Net 30', 'TC4203')
Insert Sales Values('7067', '90167', '05/09/2024', 28, 'Net 30', 'TC7777')
Insert Sales Values('7131', '90170', '04/28/2021', 51, 'Net 30', 'PS2091')
Insert Sales Values('7131', '90173', '12/10/2022', 101, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90176', '07/07/2023', 10, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90179', '04/16/2024', 48, 'Net 60', 'PS2106')
Insert Sales Values('7131', '90182', '05/15/2023', 5, 'Net 60', 'PS3333')
Insert Sales Values('7131', '90185', '07/12/2023', 53, 'Net 60', 'PS7777')
Insert Sales Values('7896', '90188', '06/12/2024', 93, 'Net 60', 'BU7832')
Insert Sales Values('6380', '90191', '03/07/2023', 38, 'Net 60', 'MC2222')
Insert Sales Values('6380', '90194', '06/18/2023', 83, 'ON invoice', 'BU2075')
Insert Sales Values('6380', '90197', '12/18/2022', 12, 'ON invoice', 'MC3021')
Insert Sales Values('7066', '90200', '09/06/2024', 83, 'ON invoice', 'BU1032')
Insert Sales Values('6380', '90203', '08/29/2023', 24, 'Net 30', 'BU1111')
Insert Sales Values('6380', '90206', '02/16/2021', 85, 'Net 30', 'PC1035')
Insert Sales Values('6380', '90209', '09/07/2020', 31, 'Net 60', 'BU1032')
Insert Sales Values('7066', '90212', '05/11/2021', 60, 'Net 60', 'PS2091')
Insert Sales Values('6380', '90215', '02/29/2024', 81, 'Net 30', 'PC8888')
Insert Sales Values('6380', '90218', '03/22/2022', 67, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '90221', '01/21/2022', 6, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90224', '05/05/2022', 37, 'Net 30', 'TC3218')
Insert Sales Values('8042', '90227', '06/15/2024', 93, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90230', '08/15/2024', 63, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90233', '09/21/2023', 44, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90236', '10/05/2022', 38, 'Net 30', 'MC3021')
Insert Sales Values('6380', '90239', '03/22/2021', 51, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90242', '07/05/2021', 81, 'Net 60', 'PS2106')
Insert Sales Values('7066', '90245', '12/23/2022', 76, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90248', '07/28/2023', 26, 'Net 60', 'PS7777')
Insert Sales Values('7067', '90251', '10/13/2023', 95, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90254', '09/03/2023', 37, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90257', '03/24/2021', 97, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90260', '01/29/2022', 70, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '90263', '04/05/2024', 41, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90266', '01/02/2024', 48, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90269', '02/23/2021', 60, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90272', '04/01/2023', 31, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90275', '09/28/2021', 95, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90278', '10/13/2020', 35, 'Net 30', 'PC8888')
Insert Sales Values('7896', '90281', '05/07/2021', 39, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90284', '12/17/2023', 5, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90287', '10/05/2022', 99, 'Net 30', 'TC3218')
Insert Sales Values('8042', '90290', '05/28/2021', 12, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90293', '02/16/2021', 80, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90296', '07/22/2020', 72, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90299', '04/05/2022', 20, 'Net 30', 'MC3021')
Insert Sales Values('6380', '90302', '12/25/2022', 32, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90305', '03/12/2023', 93, 'Net 60', 'PS2106')
Insert Sales Values('7066', '90308', '09/17/2022', 91, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90311', '03/01/2023', 56, 'Net 60', 'PS7777')
Insert Sales Values('7067', '90314', '12/15/2021', 76, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90317', '05/13/2024', 66, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90320', '05/24/2022', 80, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90323', '02/12/2023', 73, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '90326', '12/11/2020', 52, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90329', '07/17/2021', 19, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90332', '05/01/2023', 75, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90335', '06/27/2024', 61, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90338', '03/21/2022', 32, 'Net 60', 'PS2091')
Insert Sales Values('8042', '90341', '07/31/2021', 49, 'Net 30', 'PC8888')
Insert Sales Values('8042', '90344', '02/18/2023', 65, 'ON invoice', 'PS2091')
Insert Sales Values('8042', '90347', '04/11/2021', 20, 'Net 60', 'PS2091')
Insert Sales Values('8042', '90350', '03/13/2021', 99, 'Net 30', 'TC3218')
Insert Sales Values('6380', '90353', '08/04/2024', 96, 'Net 30', 'TC4203')
Insert Sales Values('6380', '90356', '03/22/2023', 20, 'Net 30', 'TC7777')
Insert Sales Values('7066', '90359', '02/06/2021', 83, 'Net 30', 'PS2091')
Insert Sales Values('7066', '90362', '10/20/2023', 6, 'Net 30', 'MC3021')
Insert Sales Values('7067', '90365', '05/25/2021', 56, 'Net 60', 'PS1372')
Insert Sales Values('7067', '90368', '12/15/2023', 93, 'Net 60', 'PS2106')
Insert Sales Values('7067', '90371', '07/08/2024', 6, 'Net 60', 'PS3333')
Insert Sales Values('7067', '90374', '01/07/2023', 17, 'Net 60', 'PS7777')
Insert Sales Values('7131', '90377', '05/23/2024', 13, 'Net 60', 'BU7832')
Insert Sales Values('7131', '90380', '10/28/2023', 52, 'Net 60', 'MC2222')
Insert Sales Values('7131', '90383', '05/03/2024', 36, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '90386', '03/23/2023', 92, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '90389', '10/03/2020', 84, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90392', '07/23/2024', 52, 'Net 30', 'BU1111')
Insert Sales Values('7896', '90395', '12/10/2020', 26, 'Net 30', 'PC1035')
Insert Sales Values('7896', '90398', '04/06/2023', 53, 'Net 60', 'BU1032')
Insert Sales Values('7896', '90401', '11/02/2021', 55, 'Net 60', 'PS2091')
Insert Sales Values('8042', '90404', '04/18/2023', 69, 'Net 30', 'PC8888')
Insert Sales Values('8042', '90407', '06/11/2023', 18, 'ON invoice', 'PS2091')
Insert Sales Values('8042', '90410', '12/30/2020', 86, 'Net 60', 'PS2091')
Insert Sales Values('8042', '90413', '07/26/2023', 16, 'Net 30', 'TC3218')
Insert Sales Values('6380', '90416', '05/22/2022', 81, 'Net 30', 'TC4203')
Insert Sales Values('6380', '90419', '07/06/2022', 81, 'Net 30', 'TC7777')
Insert Sales Values('7066', '90422', '05/30/2021', 12, 'Net 30', 'PS2091')
Insert Sales Values('7066', '90425', '04/04/2021', 47, 'Net 30', 'MC3021')
Insert Sales Values('7067', '90428', '10/22/2023', 95, 'Net 60', 'PS1372')
Insert Sales Values('7067', '90431', '04/05/2023', 57, 'Net 60', 'PS2106')
Insert Sales Values('7067', '90434', '11/22/2021', 22, 'Net 60', 'PS3333')
Insert Sales Values('7067', '90437', '08/02/2020', 12, 'Net 60', 'PS7777')
Insert Sales Values('7131', '90440', '12/17/2022', 47, 'Net 60', 'BU7832')
Insert Sales Values('7131', '90443', '12/10/2020', 104, 'Net 60', 'MC2222')
Insert Sales Values('7131', '90446', '12/04/2023', 31, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '90449', '08/10/2024', 104, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '90452', '08/29/2021', 39, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '90455', '08/22/2023', 27, 'Net 30', 'BU1111')
Insert Sales Values('8042', '90458', '06/13/2021', 74, 'Net 30', 'PC1035')
Insert Sales Values('8042', '90461', '09/03/2024', 83, 'Net 60', 'BU1032')
Insert Sales Values('8042', '90464', '03/09/2023', 34, 'Net 60', 'PS2091')
Insert Sales Values('6380', '90467', '07/08/2023', 9, 'Net 30', 'PC8888')
Insert Sales Values('6380', '90470', '12/03/2021', 25, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '90473', '12/30/2021', 94, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90476', '06/26/2020', 10, 'Net 30', 'TC3218')
Insert Sales Values('7067', '90479', '02/16/2022', 37, 'Net 30', 'TC4203')
Insert Sales Values('7067', '90482', '05/08/2023', 6, 'Net 30', 'TC7777')
Insert Sales Values('7067', '90485', '06/16/2022', 68, 'Net 30', 'PS2091')
Insert Sales Values('7067', '90488', '02/09/2022', 89, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90491', '05/11/2022', 40, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90494', '06/10/2022', 38, 'Net 60', 'PS2106')
Insert Sales Values('7131', '90497', '06/07/2024', 92, 'Net 60', 'PS3333')
Insert Sales Values('7131', '90500', '06/29/2023', 73, 'Net 60', 'PS7777')
Insert Sales Values('7131', '90503', '12/20/2020', 32, 'Net 60', 'BU7832')
Insert Sales Values('7131', '90506', '06/05/2021', 75, 'Net 60', 'MC2222')
Insert Sales Values('7896', '90509', '06/18/2023', 17, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '90512', '05/28/2021', 8, 'ON invoice', 'MC3021')
Insert Sales Values('7896', '90515', '03/16/2022', 91, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '90518', '01/31/2021', 105, 'Net 30', 'BU1111')
Insert Sales Values('8042', '90521', '01/09/2022', 79, 'Net 30', 'PC1035')
Insert Sales Values('8042', '90524', '09/15/2020', 24, 'Net 60', 'BU1032')
Insert Sales Values('8042', '90527', '11/09/2022', 14, 'Net 60', 'PS2091')
Insert Sales Values('6380', '90530', '04/10/2024', 85, 'Net 30', 'PC8888')
Insert Sales Values('6380', '90533', '05/07/2023', 102, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '90536', '02/20/2023', 83, 'Net 60', 'PS2091')
Insert Sales Values('7066', '90539', '01/04/2022', 8, 'Net 30', 'TC3218')
Insert Sales Values('7067', '90542', '06/29/2024', 41, 'Net 30', 'TC4203')
Insert Sales Values('7067', '90545', '08/01/2021', 71, 'Net 30', 'TC7777')
Insert Sales Values('7067', '90548', '01/13/2022', 47, 'Net 30', 'PS2091')
Insert Sales Values('7067', '90551', '08/05/2022', 72, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90554', '06/30/2021', 11, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90557', '02/11/2023', 51, 'Net 60', 'PS2106')
Insert Sales Values('7131', '90560', '01/10/2022', 91, 'Net 60', 'PS3333')
Insert Sales Values('7131', '90563', '06/08/2023', 78, 'Net 60', 'PS7777')
Insert Sales Values('7131', '90566', '05/02/2024', 83, 'Net 60', 'BU7832')
Insert Sales Values('8042', '90569', '07/23/2021', 61, 'Net 60', 'MC2222')
Insert Sales Values('8042', '90572', '04/04/2024', 7, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '90575', '02/04/2022', 70, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '90578', '11/29/2023', 39, 'ON invoice', 'BU1032')
Insert Sales Values('6380', '90581', '01/03/2023', 61, 'Net 30', 'BU1111')
Insert Sales Values('6380', '90584', '11/19/2020', 74, 'Net 30', 'PC1035')
Insert Sales Values('7066', '90587', '01/27/2021', 45, 'Net 60', 'BU1032')
Insert Sales Values('7066', '90590', '07/22/2021', 75, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90593', '07/02/2021', 99, 'Net 30', 'PC8888')
Insert Sales Values('7067', '90596', '08/01/2021', 97, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '90599', '10/29/2022', 75, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90602', '09/24/2021', 30, 'Net 30', 'TC3218')
Insert Sales Values('7131', '90605', '09/01/2022', 62, 'Net 30', 'TC4203')
Insert Sales Values('7131', '90608', '07/25/2022', 62, 'Net 30', 'TC7777')
Insert Sales Values('7131', '90611', '09/16/2022', 25, 'Net 30', 'PS2091')
Insert Sales Values('7131', '90614', '03/06/2023', 22, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90617', '04/13/2024', 62, 'Net 60', 'PS1372')
Insert Sales Values('7131', '90620', '11/01/2022', 62, 'Net 60', 'PS2106')
Insert Sales Values('7896', '90623', '08/12/2024', 36, 'Net 60', 'PS3333')
Insert Sales Values('7896', '90626', '02/28/2024', 15, 'Net 60', 'PS7777')
Insert Sales Values('7896', '90629', '04/21/2023', 94, 'Net 60', 'BU7832')
Insert Sales Values('8042', '90632', '08/09/2024', 70, 'Net 60', 'MC2222')
Insert Sales Values('8042', '90635', '02/16/2024', 70, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '90638', '01/10/2022', 98, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '90641', '03/30/2023', 82, 'ON invoice', 'BU1032')
Insert Sales Values('6380', '90644', '09/25/2022', 6, 'Net 30', 'BU1111')
Insert Sales Values('6380', '90647', '02/17/2021', 74, 'Net 30', 'PC1035')
Insert Sales Values('7066', '90650', '06/24/2022', 99, 'Net 60', 'BU1032')
Insert Sales Values('7066', '90653', '04/17/2024', 43, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90656', '11/01/2022', 95, 'Net 30', 'PC8888')
Insert Sales Values('7067', '90659', '09/25/2023', 28, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '90662', '03/17/2021', 99, 'Net 60', 'PS2091')
Insert Sales Values('7067', '90665', '12/14/2020', 44, 'Net 30', 'TC3218')
Insert Sales Values('7131', '90668', '10/18/2022', 11, 'Net 30', 'TC4203')
Insert Sales Values('7131', '90671', '11/23/2021', 61, 'Net 30', 'TC7777')
Insert Sales Values('7131', '90674', '08/27/2024', 51, 'Net 30', 'PS2091')
Insert Sales Values('7131', '90677', '07/14/2023', 46, 'Net 30', 'MC3021')
Insert Sales Values('7131', '90680', '09/01/2020', 96, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90683', '07/28/2024', 100, 'Net 60', 'PS2106')
Insert Sales Values('6380', '90686', '06/20/2020', 90, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90689', '06/06/2022', 19, 'Net 60', 'PS7777')
Insert Sales Values('7066', '90692', '07/05/2021', 67, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90695', '05/21/2023', 82, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90698', '06/25/2020', 32, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90701', '08/06/2020', 42, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '90704', '02/01/2022', 32, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90707', '04/28/2024', 37, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90710', '11/24/2023', 72, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90713', '08/24/2024', 53, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90716', '03/10/2021', 28, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90719', '08/31/2024', 102, 'Net 30', 'PC8888')
Insert Sales Values('7131', '90722', '09/29/2021', 59, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90725', '01/01/2022', 32, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90728', '08/08/2024', 30, 'Net 30', 'TC3218')
Insert Sales Values('7896', '90731', '04/10/2021', 73, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90734', '11/08/2021', 67, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90737', '09/01/2021', 22, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90740', '07/20/2022', 68, 'Net 30', 'MC3021')
Insert Sales Values('8042', '90743', '11/25/2023', 92, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90746', '07/10/2020', 23, 'Net 60', 'PS2106')
Insert Sales Values('6380', '90749', '01/04/2024', 53, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90752', '12/03/2022', 61, 'Net 60', 'PS7777')
Insert Sales Values('7066', '90755', '09/10/2021', 79, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90758', '10/08/2023', 97, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90761', '09/04/2023', 70, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90764', '05/22/2024', 22, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '90767', '05/30/2022', 26, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90770', '10/23/2022', 7, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90773', '11/05/2022', 34, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90776', '08/06/2024', 80, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90779', '09/27/2020', 5, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90782', '10/04/2020', 74, 'Net 30', 'PC8888')
Insert Sales Values('7131', '90785', '09/11/2024', 29, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90788', '03/29/2024', 42, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90791', '03/03/2021', 83, 'Net 30', 'TC3218')
Insert Sales Values('7896', '90794', '03/10/2022', 96, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90797', '08/11/2021', 41, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90800', '06/20/2023', 56, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90803', '05/15/2024', 76, 'Net 30', 'MC3021')
Insert Sales Values('8042', '90806', '11/05/2021', 75, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90809', '10/02/2023', 5, 'Net 60', 'PS2106')
Insert Sales Values('6380', '90812', '03/22/2021', 63, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90815', '07/21/2020', 81, 'Net 60', 'PS7777')
Insert Sales Values('7066', '90818', '06/28/2020', 18, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90821', '06/21/2020', 41, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90824', '05/30/2022', 8, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90827', '12/03/2023', 84, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '90830', '04/21/2023', 21, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90833', '04/24/2023', 49, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90836', '08/31/2021', 31, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90839', '04/19/2023', 28, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90842', '12/12/2021', 81, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90845', '04/30/2023', 39, 'Net 30', 'PC8888')
Insert Sales Values('7131', '90848', '06/01/2024', 79, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90851', '09/06/2020', 5, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90854', '08/21/2021', 81, 'Net 30', 'TC3218')
Insert Sales Values('7896', '90857', '10/02/2020', 48, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90860', '06/20/2022', 69, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90863', '11/11/2022', 95, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90866', '04/12/2021', 95, 'Net 30', 'MC3021')
Insert Sales Values('8042', '90869', '11/24/2021', 74, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90872', '06/16/2020', 79, 'Net 60', 'PS2106')
Insert Sales Values('6380', '90875', '06/20/2021', 48, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90878', '05/17/2022', 92, 'Net 60', 'PS7777')
Insert Sales Values('7066', '90881', '10/28/2020', 24, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90884', '09/02/2020', 87, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90887', '07/11/2023', 15, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90890', '05/26/2021', 48, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '90893', '05/27/2022', 41, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90896', '11/17/2022', 82, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90899', '09/12/2023', 32, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90902', '03/31/2021', 46, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90905', '07/23/2021', 33, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90908', '02/27/2024', 7, 'Net 30', 'PC8888')
Insert Sales Values('7131', '90911', '05/01/2022', 105, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90914', '11/06/2023', 57, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90917', '06/06/2022', 59, 'Net 30', 'TC3218')
Insert Sales Values('7896', '90920', '08/25/2021', 89, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90923', '01/30/2022', 62, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90926', '10/02/2020', 48, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90929', '03/07/2021', 15, 'Net 30', 'MC3021')
Insert Sales Values('8042', '90932', '02/25/2024', 48, 'Net 60', 'PS1372')
Insert Sales Values('6380', '90935', '07/07/2022', 36, 'Net 60', 'PS2106')
Insert Sales Values('6380', '90938', '10/18/2023', 60, 'Net 60', 'PS3333')
Insert Sales Values('7066', '90941', '12/31/2022', 58, 'Net 60', 'PS7777')
Insert Sales Values('7066', '90944', '11/23/2022', 26, 'Net 60', 'BU7832')
Insert Sales Values('7067', '90947', '10/23/2023', 36, 'Net 60', 'MC2222')
Insert Sales Values('7067', '90950', '09/07/2021', 85, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '90953', '07/10/2023', 46, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '90956', '10/02/2021', 8, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '90959', '09/26/2022', 5, 'Net 30', 'BU1111')
Insert Sales Values('7131', '90962', '05/29/2021', 20, 'Net 30', 'PC1035')
Insert Sales Values('7131', '90965', '09/08/2021', 33, 'Net 60', 'BU1032')
Insert Sales Values('7131', '90968', '04/25/2022', 5, 'Net 60', 'PS2091')
Insert Sales Values('7131', '90971', '08/11/2023', 57, 'Net 30', 'PC8888')
Insert Sales Values('7131', '90974', '02/14/2022', 22, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '90977', '05/05/2023', 64, 'Net 60', 'PS2091')
Insert Sales Values('7896', '90980', '05/21/2022', 38, 'Net 30', 'TC3218')
Insert Sales Values('7896', '90983', '01/01/2021', 102, 'Net 30', 'TC4203')
Insert Sales Values('8042', '90986', '05/26/2021', 7, 'Net 30', 'TC7777')
Insert Sales Values('8042', '90989', '01/02/2023', 15, 'Net 30', 'PS2091')
Insert Sales Values('8042', '90992', '12/21/2023', 33, 'Net 30', 'MC3021')
Insert Sales Values('8042', '90995', '01/04/2024', 56, 'Net 60', 'PS1372')
Insert Sales Values('8042', '90998', '04/02/2021', 38, 'Net 60', 'PS2106')
Insert Sales Values('8042', '91001', '07/08/2021', 6, 'Net 60', 'PS3333')
Insert Sales Values('8042', '91004', '09/10/2022', 94, 'Net 60', 'PS7777')
Insert Sales Values('6380', '91007', '05/04/2023', 71, 'Net 60', 'BU7832')
Insert Sales Values('6380', '91010', '11/06/2021', 26, 'Net 60', 'MC2222')
Insert Sales Values('7066', '91013', '11/27/2020', 39, 'ON invoice', 'BU2075')
Insert Sales Values('7066', '91016', '08/15/2021', 67, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '91019', '02/23/2021', 47, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '91022', '04/22/2021', 5, 'Net 30', 'BU1111')
Insert Sales Values('7067', '91025', '02/04/2024', 101, 'Net 30', 'PC1035')
Insert Sales Values('7067', '91028', '02/02/2021', 90, 'Net 60', 'BU1032')
Insert Sales Values('7131', '91031', '07/31/2024', 93, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91034', '04/13/2021', 89, 'Net 30', 'PC8888')
Insert Sales Values('7131', '91037', '09/19/2020', 77, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '91040', '07/26/2022', 104, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91043', '01/17/2024', 8, 'Net 30', 'TC3218')
Insert Sales Values('7131', '91046', '04/08/2024', 84, 'Net 30', 'TC4203')
Insert Sales Values('7896', '91049', '07/19/2023', 76, 'Net 30', 'TC7777')
Insert Sales Values('8042', '91052', '12/01/2021', 58, 'Net 30', 'PS2091')
Insert Sales Values('8042', '91055', '01/10/2023', 6, 'Net 30', 'MC3021')
Insert Sales Values('8042', '91058', '07/21/2023', 24, 'Net 60', 'PS1372')
Insert Sales Values('6380', '91061', '01/04/2021', 16, 'Net 60', 'PS2106')
Insert Sales Values('6380', '91064', '07/21/2022', 48, 'Net 60', 'PS3333')
Insert Sales Values('7066', '91067', '03/31/2021', 100, 'Net 60', 'PS7777')
Insert Sales Values('7066', '91070', '12/29/2021', 63, 'Net 60', 'BU7832')
Insert Sales Values('7067', '91073', '02/13/2024', 91, 'Net 60', 'MC2222')
Insert Sales Values('7067', '91076', '11/10/2022', 35, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '91079', '10/24/2020', 51, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '91082', '12/05/2023', 40, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '91085', '06/18/2020', 67, 'Net 30', 'BU1111')
Insert Sales Values('7131', '91088', '12/14/2023', 15, 'Net 30', 'PC1035')
Insert Sales Values('7131', '91091', '11/01/2021', 12, 'Net 60', 'BU1032')
Insert Sales Values('7131', '91094', '04/16/2023', 40, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91097', '05/16/2024', 82, 'Net 30', 'PC8888')
Insert Sales Values('7131', '91100', '07/30/2022', 45, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '91103', '07/15/2021', 31, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91106', '02/04/2024', 18, 'Net 30', 'TC3218')
Insert Sales Values('6380', '91109', '11/25/2020', 92, 'Net 30', 'TC4203')
Insert Sales Values('6380', '91112', '07/25/2020', 34, 'Net 30', 'TC7777')
Insert Sales Values('7066', '91115', '02/17/2023', 56, 'Net 30', 'PS2091')
Insert Sales Values('6380', '91118', '05/21/2022', 23, 'Net 30', 'MC3021')
Insert Sales Values('6380', '91121', '11/16/2020', 8, 'Net 60', 'PS1372')
Insert Sales Values('6380', '91124', '10/11/2022', 61, 'Net 60', 'PS2106')
Insert Sales Values('7066', '91127', '07/25/2022', 38, 'Net 60', 'PS3333')
Insert Sales Values('6380', '91130', '10/14/2020', 25, 'Net 60', 'PS7777')
Insert Sales Values('6380', '91133', '07/15/2022', 75, 'Net 60', 'BU7832')
Insert Sales Values('7066', '91136', '09/30/2023', 29, 'Net 60', 'MC2222')
Insert Sales Values('7066', '91139', '02/04/2024', 43, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '91142', '06/10/2024', 95, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91145', '09/05/2022', 67, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91148', '10/21/2020', 11, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91151', '10/20/2022', 63, 'Net 30', 'PC1035')
Insert Sales Values('6380', '91154', '10/15/2020', 53, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91157', '03/06/2022', 62, 'Net 60', 'PS2091')
Insert Sales Values('7066', '91160', '07/15/2023', 55, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91163', '05/19/2022', 85, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '91166', '10/09/2023', 96, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91169', '10/04/2020', 19, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91172', '01/11/2023', 8, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91175', '04/23/2024', 70, 'Net 30', 'TC7777')
Insert Sales Values('7131', '91178', '03/11/2021', 39, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91181', '11/16/2022', 62, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91184', '12/19/2022', 82, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91187', '07/07/2022', 83, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91190', '11/26/2023', 92, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91193', '09/29/2022', 46, 'Net 60', 'PS7777')
Insert Sales Values('7896', '91196', '08/11/2021', 25, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91199', '04/15/2024', 34, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91202', '02/20/2023', 77, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '91205', '01/30/2021', 91, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91208', '11/13/2021', 23, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91211', '07/04/2021', 16, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91214', '12/04/2023', 26, 'Net 30', 'PC1035')
Insert Sales Values('6380', '91217', '12/02/2020', 99, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91220', '01/09/2022', 59, 'Net 60', 'PS2091')
Insert Sales Values('7066', '91223', '05/02/2023', 72, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91226', '01/05/2024', 76, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '91229', '01/10/2021', 34, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91232', '10/14/2023', 60, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91235', '08/09/2020', 76, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91238', '05/29/2022', 27, 'Net 30', 'TC7777')
Insert Sales Values('7131', '91241', '07/18/2022', 10, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91244', '01/16/2022', 49, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91247', '12/05/2021', 93, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91250', '05/13/2023', 34, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91253', '09/07/2021', 13, 'Net 60', 'PS3333')
Insert Sales Values('8042', '91256', '02/25/2021', 81, 'Net 60', 'PS7777')
Insert Sales Values('8042', '91259', '03/25/2024', 54, 'Net 60', 'BU7832')
Insert Sales Values('8042', '91262', '12/09/2021', 22, 'Net 60', 'MC2222')
Insert Sales Values('8042', '91265', '06/18/2022', 60, 'ON invoice', 'BU2075')
Insert Sales Values('6380', '91268', '08/17/2020', 49, 'ON invoice', 'MC3021')
Insert Sales Values('6380', '91271', '10/15/2021', 74, 'ON invoice', 'BU1032')
Insert Sales Values('7066', '91274', '11/27/2022', 23, 'Net 30', 'BU1111')
Insert Sales Values('7066', '91277', '02/11/2021', 49, 'Net 30', 'PC1035')
Insert Sales Values('7067', '91280', '05/11/2024', 68, 'Net 60', 'BU1032')
Insert Sales Values('7067', '91283', '06/13/2021', 39, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91286', '05/24/2023', 65, 'Net 30', 'PC8888')
Insert Sales Values('7067', '91289', '02/24/2023', 43, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '91292', '12/11/2021', 20, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91295', '07/01/2021', 88, 'Net 30', 'TC3218')
Insert Sales Values('7131', '91298', '03/07/2023', 17, 'Net 30', 'TC4203')
Insert Sales Values('7131', '91301', '07/15/2020', 53, 'Net 30', 'TC7777')
Insert Sales Values('7131', '91304', '03/09/2021', 96, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91307', '12/26/2022', 51, 'Net 30', 'MC3021')
Insert Sales Values('7896', '91310', '10/20/2023', 91, 'Net 60', 'PS1372')
Insert Sales Values('7896', '91313', '09/30/2023', 33, 'Net 60', 'PS2106')
Insert Sales Values('7896', '91316', '09/30/2020', 37, 'Net 60', 'PS3333')
Insert Sales Values('8042', '91319', '02/11/2024', 60, 'Net 60', 'PS7777')
Insert Sales Values('8042', '91322', '02/19/2023', 41, 'Net 60', 'BU7832')
Insert Sales Values('8042', '91325', '04/05/2024', 64, 'Net 60', 'MC2222')
Insert Sales Values('8042', '91328', '02/08/2022', 20, 'ON invoice', 'BU2075')
Insert Sales Values('6380', '91331', '11/20/2020', 31, 'ON invoice', 'MC3021')
Insert Sales Values('6380', '91334', '12/01/2023', 52, 'ON invoice', 'BU1032')
Insert Sales Values('7066', '91337', '10/07/2022', 41, 'Net 30', 'BU1111')
Insert Sales Values('7066', '91340', '05/24/2022', 14, 'Net 30', 'PC1035')
Insert Sales Values('7067', '91343', '11/18/2021', 94, 'Net 60', 'BU1032')
Insert Sales Values('7067', '91346', '11/10/2020', 55, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91349', '07/27/2024', 79, 'Net 30', 'PC8888')
Insert Sales Values('7067', '91352', '02/10/2021', 65, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '91355', '12/31/2020', 55, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91358', '01/23/2022', 78, 'Net 30', 'TC3218')
Insert Sales Values('7131', '91361', '01/17/2021', 76, 'Net 30', 'TC4203')
Insert Sales Values('7131', '91364', '03/31/2022', 8, 'Net 30', 'TC7777')
Insert Sales Values('7131', '91367', '07/14/2020', 90, 'Net 30', 'PS2091')
Insert Sales Values('8042', '91370', '02/15/2021', 64, 'Net 30', 'MC3021')
Insert Sales Values('8042', '91373', '06/30/2023', 13, 'Net 60', 'PS1372')
Insert Sales Values('8042', '91376', '08/12/2024', 57, 'Net 60', 'PS2106')
Insert Sales Values('8042', '91379', '10/01/2021', 15, 'Net 60', 'PS3333')
Insert Sales Values('6380', '91382', '11/14/2021', 40, 'Net 60', 'PS7777')
Insert Sales Values('6380', '91385', '05/11/2024', 26, 'Net 60', 'BU7832')
Insert Sales Values('7066', '91388', '10/22/2020', 26, 'Net 60', 'MC2222')
Insert Sales Values('7066', '91391', '04/04/2024', 46, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '91394', '03/02/2021', 94, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '91397', '07/24/2022', 94, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '91400', '07/30/2020', 58, 'Net 30', 'BU1111')
Insert Sales Values('7067', '91403', '07/30/2023', 54, 'Net 30', 'PC1035')
Insert Sales Values('7131', '91406', '03/18/2024', 47, 'Net 60', 'BU1032')
Insert Sales Values('7131', '91409', '05/19/2023', 94, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91412', '09/09/2024', 98, 'Net 30', 'PC8888')
Insert Sales Values('7131', '91415', '05/25/2023', 54, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '91418', '07/13/2023', 51, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91421', '09/05/2023', 35, 'Net 30', 'TC3218')
Insert Sales Values('7896', '91424', '01/30/2021', 62, 'Net 30', 'TC4203')
Insert Sales Values('7896', '91427', '03/14/2022', 92, 'Net 30', 'TC7777')
Insert Sales Values('7896', '91430', '05/04/2023', 28, 'Net 30', 'PS2091')
Insert Sales Values('8042', '91433', '06/07/2022', 87, 'Net 30', 'MC3021')
Insert Sales Values('8042', '91436', '12/17/2021', 82, 'Net 60', 'PS1372')
Insert Sales Values('8042', '91439', '05/11/2024', 15, 'Net 60', 'PS2106')
Insert Sales Values('8042', '91442', '02/23/2024', 34, 'Net 60', 'PS3333')
Insert Sales Values('6380', '91445', '10/17/2021', 95, 'Net 60', 'PS7777')
Insert Sales Values('6380', '91448', '01/31/2024', 77, 'Net 60', 'BU7832')
Insert Sales Values('7066', '91451', '08/18/2023', 74, 'Net 60', 'MC2222')
Insert Sales Values('7066', '91454', '05/23/2023', 88, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '91457', '01/02/2021', 101, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '91460', '03/02/2022', 97, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '91463', '06/26/2023', 28, 'Net 30', 'BU1111')
Insert Sales Values('7067', '91466', '11/24/2023', 80, 'Net 30', 'PC1035')
Insert Sales Values('7131', '91469', '09/11/2023', 11, 'Net 60', 'BU1032')
Insert Sales Values('7131', '91472', '08/10/2020', 10, 'Net 60', 'PS2091')
Insert Sales Values('7131', '91475', '07/10/2023', 40, 'Net 30', 'PC8888')
Insert Sales Values('7131', '91478', '08/13/2020', 105, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '91481', '05/02/2021', 85, 'Net 60', 'PS2091')
Insert Sales Values('8042', '91484', '10/01/2023', 103, 'Net 30', 'TC3218')
Insert Sales Values('8042', '91487', '06/25/2021', 60, 'Net 30', 'TC4203')
Insert Sales Values('8042', '91490', '02/18/2021', 63, 'Net 30', 'TC7777')
Insert Sales Values('8042', '91493', '04/19/2023', 43, 'Net 30', 'PS2091')
Insert Sales Values('6380', '91496', '01/09/2021', 96, 'Net 30', 'MC3021')
Insert Sales Values('6380', '91499', '08/03/2022', 94, 'Net 60', 'PS1372')
Insert Sales Values('7066', '91502', '10/14/2023', 44, 'Net 60', 'PS2106')
Insert Sales Values('7066', '91505', '07/17/2020', 66, 'Net 60', 'PS3333')
Insert Sales Values('7067', '91508', '11/21/2023', 54, 'Net 60', 'PS7777')
Insert Sales Values('7067', '91511', '09/13/2021', 57, 'Net 60', 'BU7832')
Insert Sales Values('7067', '91514', '11/26/2022', 98, 'Net 60', 'MC2222')
Insert Sales Values('7067', '91517', '11/11/2021', 5, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '91520', '01/17/2023', 72, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '91523', '10/20/2021', 10, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '91526', '02/10/2021', 74, 'Net 30', 'BU1111')
Insert Sales Values('7131', '91529', '12/18/2023', 31, 'Net 30', 'PC1035')
Insert Sales Values('7131', '91532', '04/15/2022', 51, 'Net 60', 'BU1032')
Insert Sales Values('7131', '91535', '10/12/2020', 78, 'Net 60', 'PS2091')
Insert Sales Values('7896', '91538', '05/09/2022', 90, 'Net 30', 'PC8888')
Insert Sales Values('7896', '91541', '11/16/2021', 35, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '91544', '05/28/2024', 87, 'Net 60', 'PS2091')
Insert Sales Values('8042', '91547', '01/29/2022', 57, 'Net 30', 'TC3218')
Insert Sales Values('8042', '91550', '01/11/2021', 15, 'Net 30', 'TC4203')
Insert Sales Values('8042', '91553', '04/17/2021', 27, 'Net 30', 'TC7777')
Insert Sales Values('8042', '91556', '10/29/2022', 12, 'Net 30', 'PS2091')
Insert Sales Values('6380', '91559', '01/06/2024', 100, 'Net 30', 'MC3021')
Insert Sales Values('6380', '91562', '07/20/2021', 86, 'Net 60', 'PS1372')
Insert Sales Values('7066', '91565', '01/30/2021', 35, 'Net 60', 'PS2106')
Insert Sales Values('7066', '91568', '02/03/2021', 97, 'Net 60', 'PS3333')
Insert Sales Values('7067', '91571', '08/10/2024', 40, 'Net 60', 'PS7777')
Insert Sales Values('7067', '91574', '03/01/2023', 70, 'Net 60', 'BU7832')
Insert Sales Values('7067', '91577', '07/08/2021', 87, 'Net 60', 'MC2222')
Insert Sales Values('7067', '91580', '07/05/2023', 7, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '91583', '06/17/2022', 70, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '91586', '10/07/2021', 73, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '91589', '11/07/2022', 57, 'Net 30', 'BU1111')
Insert Sales Values('7131', '91592', '09/10/2022', 24, 'Net 30', 'PC1035')
Insert Sales Values('7131', '91595', '06/29/2020', 84, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91598', '09/02/2020', 45, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91601', '12/22/2023', 51, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91604', '11/18/2020', 7, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91607', '04/10/2024', 70, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91610', '12/05/2020', 92, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91613', '03/28/2024', 54, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91616', '06/09/2024', 100, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91619', '07/03/2022', 49, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91622', '03/24/2023', 82, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91625', '07/27/2023', 15, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91628', '12/19/2021', 23, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91631', '12/07/2021', 36, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91634', '10/04/2021', 23, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91637', '11/19/2021', 72, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91640', '02/08/2023', 36, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91643', '03/20/2024', 76, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '91646', '08/01/2022', 44, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91649', '10/20/2022', 21, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91652', '10/17/2023', 8, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91655', '07/31/2021', 32, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91658', '07/22/2021', 9, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91661', '01/24/2022', 99, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91664', '02/10/2022', 28, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91667', '01/04/2024', 6, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91670', '02/08/2023', 90, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91673', '04/22/2024', 9, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91676', '07/21/2020', 9, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91679', '07/17/2022', 54, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91682', '02/20/2022', 99, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91685', '09/05/2024', 48, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91688', '06/25/2020', 51, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91691', '10/17/2022', 61, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91694', '05/31/2024', 83, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91697', '05/03/2021', 25, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91700', '10/28/2021', 64, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91703', '03/05/2024', 35, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91706', '07/03/2023', 5, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '91709', '10/27/2020', 65, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91712', '03/18/2022', 23, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91715', '09/18/2020', 89, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91718', '03/26/2022', 80, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91721', '09/06/2023', 59, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91724', '04/13/2022', 81, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91727', '04/15/2024', 63, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91730', '09/14/2021', 83, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91733', '03/09/2024', 18, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91736', '04/03/2022', 93, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91739', '03/01/2024', 49, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91742', '10/22/2022', 100, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91745', '10/10/2021', 55, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91748', '04/07/2023', 61, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91751', '08/16/2024', 19, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91754', '01/13/2024', 95, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91757', '07/07/2021', 76, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91760', '06/04/2022', 68, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91763', '03/19/2024', 14, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91766', '07/02/2023', 48, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91769', '04/08/2022', 60, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '91772', '06/24/2021', 77, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91775', '03/07/2023', 75, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91778', '02/09/2022', 64, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91781', '08/23/2021', 80, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91784', '02/03/2022', 75, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91787', '10/06/2023', 48, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91790', '01/15/2021', 31, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91793', '12/12/2023', 41, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91796', '02/27/2023', 71, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91799', '03/20/2022', 83, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91802', '07/15/2023', 62, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91805', '10/31/2020', 73, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91808', '11/17/2020', 38, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91811', '04/11/2024', 100, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91814', '04/20/2023', 21, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91817', '09/28/2021', 7, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91820', '05/14/2023', 21, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91823', '06/28/2024', 40, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91826', '07/05/2023', 19, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91829', '02/20/2023', 49, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91832', '09/30/2022', 80, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '91835', '05/14/2022', 76, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91838', '01/25/2021', 42, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91841', '08/14/2024', 40, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91844', '07/04/2023', 43, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91847', '06/09/2022', 58, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91850', '02/10/2021', 105, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91853', '06/17/2020', 19, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91856', '04/24/2022', 44, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91859', '04/24/2022', 10, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91862', '11/08/2021', 92, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91865', '10/17/2021', 19, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91868', '01/09/2024', 33, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91871', '12/08/2020', 42, 'Net 30', 'PS2091')
Insert Sales Values('7131', '91874', '09/04/2024', 5, 'Net 30', 'MC3021')
Insert Sales Values('7131', '91877', '09/04/2022', 87, 'Net 60', 'PS1372')
Insert Sales Values('7131', '91880', '06/17/2022', 22, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91883', '06/19/2021', 8, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91886', '02/03/2024', 46, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91889', '12/16/2021', 22, 'Net 60', 'BU7832')
Insert Sales Values('7896', '91892', '07/26/2020', 18, 'Net 60', 'MC2222')
Insert Sales Values('7896', '91895', '05/04/2023', 5, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '91898', '10/13/2021', 88, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '91901', '04/10/2022', 25, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91904', '07/15/2024', 105, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91907', '08/22/2024', 7, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91910', '11/20/2022', 58, 'Net 60', 'BU1032')
Insert Sales Values('8042', '91913', '02/03/2024', 14, 'Net 60', 'PS2091')
Insert Sales Values('8042', '91916', '11/25/2021', 65, 'Net 30', 'PC8888')
Insert Sales Values('8042', '91919', '10/04/2021', 76, 'ON invoice', 'PS2091')
Insert Sales Values('6380', '91922', '02/02/2023', 43, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91925', '01/14/2023', 77, 'Net 30', 'TC3218')
Insert Sales Values('7066', '91928', '09/10/2020', 75, 'Net 30', 'TC4203')
Insert Sales Values('7066', '91931', '05/28/2021', 31, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91934', '08/29/2023', 77, 'Net 30', 'PS2091')
Insert Sales Values('7067', '91937', '08/18/2020', 59, 'Net 30', 'MC3021')
Insert Sales Values('7067', '91940', '02/04/2024', 64, 'Net 60', 'PS1372')
Insert Sales Values('7067', '91943', '09/16/2022', 57, 'Net 60', 'PS2106')
Insert Sales Values('7131', '91946', '05/31/2022', 29, 'Net 60', 'PS3333')
Insert Sales Values('7131', '91949', '05/26/2022', 59, 'Net 60', 'PS7777')
Insert Sales Values('7131', '91952', '08/21/2022', 84, 'Net 60', 'BU7832')
Insert Sales Values('7131', '91955', '05/23/2024', 23, 'Net 60', 'MC2222')
Insert Sales Values('7131', '91958', '02/13/2023', 57, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '91961', '02/16/2023', 9, 'ON invoice', 'MC3021')
Insert Sales Values('7896', '91964', '07/05/2022', 33, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '91967', '05/30/2024', 10, 'Net 30', 'BU1111')
Insert Sales Values('8042', '91970', '03/16/2022', 41, 'Net 30', 'PC1035')
Insert Sales Values('8042', '91973', '07/07/2021', 17, 'Net 60', 'BU1032')
Insert Sales Values('6380', '91976', '02/25/2022', 104, 'Net 60', 'PS2091')
Insert Sales Values('6380', '91979', '05/27/2022', 5, 'Net 30', 'PC8888')
Insert Sales Values('7066', '91982', '07/25/2021', 102, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '91985', '09/10/2021', 91, 'Net 60', 'PS2091')
Insert Sales Values('7067', '91988', '12/01/2023', 77, 'Net 30', 'TC3218')
Insert Sales Values('7067', '91991', '06/10/2022', 79, 'Net 30', 'TC4203')
Insert Sales Values('7067', '91994', '05/27/2022', 91, 'Net 30', 'TC7777')
Insert Sales Values('7067', '91997', '07/26/2022', 53, 'Net 30', 'PS2091')
Insert Sales Values('7131', '92000', '08/31/2022', 9, 'Net 30', 'MC3021')
Insert Sales Values('7131', '92003', '01/29/2024', 85, 'Net 60', 'PS1372')
Insert Sales Values('7131', '92006', '06/05/2022', 53, 'Net 60', 'PS2106')
Insert Sales Values('7131', '92009', '04/08/2023', 44, 'Net 60', 'PS3333')
Insert Sales Values('7131', '92012', '09/17/2020', 21, 'Net 60', 'PS7777')
Insert Sales Values('7131', '92015', '09/22/2022', 36, 'Net 60', 'BU7832')
Insert Sales Values('7896', '92018', '10/28/2021', 17, 'Net 60', 'MC2222')
Insert Sales Values('6380', '92021', '06/28/2023', 70, 'ON invoice', 'BU2075')
Insert Sales Values('6380', '92024', '09/28/2020', 33, 'ON invoice', 'MC3021')
Insert Sales Values('6380', '92027', '04/20/2022', 102, 'ON invoice', 'BU1032')
Insert Sales Values('7066', '92030', '05/08/2023', 90, 'Net 30', 'BU1111')
Insert Sales Values('6380', '92033', '11/09/2020', 13, 'Net 30', 'PC1035')
Insert Sales Values('6380', '92036', '12/15/2021', 104, 'Net 60', 'BU1032')
Insert Sales Values('6380', '92039', '04/24/2021', 86, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92042', '05/24/2021', 97, 'Net 30', 'PC8888')
Insert Sales Values('6380', '92045', '04/25/2023', 50, 'ON invoice', 'PS2091')
Insert Sales Values('6380', '92048', '01/17/2021', 98, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92051', '01/24/2022', 88, 'Net 30', 'TC3218')
Insert Sales Values('7066', '92054', '08/29/2021', 28, 'Net 30', 'TC4203')
Insert Sales Values('8042', '92057', '09/29/2023', 71, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92060', '06/25/2024', 72, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92063', '08/21/2024', 25, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92066', '07/18/2023', 85, 'Net 60', 'PS1372')
Insert Sales Values('6380', '92069', '06/11/2022', 23, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92072', '05/06/2024', 104, 'Net 60', 'PS3333')
Insert Sales Values('7066', '92075', '04/01/2021', 9, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92078', '11/02/2022', 29, 'Net 60', 'BU7832')
Insert Sales Values('7067', '92081', '01/11/2024', 62, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92084', '05/27/2024', 46, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92087', '09/24/2023', 74, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92090', '11/26/2023', 17, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '92093', '06/18/2022', 19, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92096', '07/10/2024', 11, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92099', '04/05/2022', 9, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92102', '04/18/2021', 28, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92105', '11/01/2022', 100, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92108', '07/11/2024', 62, 'ON invoice', 'PS2091')
Insert Sales Values('7896', '92111', '03/11/2023', 33, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92114', '05/17/2022', 99, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92117', '12/06/2023', 83, 'Net 30', 'TC4203')
Insert Sales Values('8042', '92120', '09/27/2022', 40, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92123', '12/01/2023', 95, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92126', '08/24/2020', 33, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92129', '05/30/2021', 39, 'Net 60', 'PS1372')
Insert Sales Values('6380', '92132', '09/05/2021', 6, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92135', '02/11/2021', 58, 'Net 60', 'PS3333')
Insert Sales Values('7066', '92138', '11/06/2020', 37, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92141', '03/29/2021', 100, 'Net 60', 'BU7832')
Insert Sales Values('7067', '92144', '08/15/2021', 56, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92147', '09/02/2021', 25, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92150', '12/19/2023', 13, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92153', '11/26/2023', 73, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '92156', '12/19/2022', 86, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92159', '11/13/2022', 90, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92162', '09/10/2022', 51, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92165', '09/14/2023', 88, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92168', '12/29/2023', 56, 'Net 30', 'PC8888')
Insert Sales Values('8042', '92171', '01/11/2022', 60, 'ON invoice', 'PS2091')
Insert Sales Values('8042', '92174', '05/16/2024', 101, 'Net 60', 'PS2091')
Insert Sales Values('8042', '92177', '10/08/2020', 71, 'Net 30', 'TC3218')
Insert Sales Values('8042', '92180', '03/19/2022', 48, 'Net 30', 'TC4203')
Insert Sales Values('6380', '92183', '09/21/2020', 100, 'Net 30', 'TC7777')
Insert Sales Values('6380', '92186', '03/25/2022', 82, 'Net 30', 'PS2091')
Insert Sales Values('7066', '92189', '01/24/2021', 14, 'Net 30', 'MC3021')
Insert Sales Values('7066', '92192', '06/30/2023', 76, 'Net 60', 'PS1372')
Insert Sales Values('7067', '92195', '07/30/2020', 23, 'Net 60', 'PS2106')
Insert Sales Values('7067', '92198', '10/29/2023', 30, 'Net 60', 'PS3333')
Insert Sales Values('7067', '92201', '02/26/2023', 49, 'Net 60', 'PS7777')
Insert Sales Values('7067', '92204', '02/15/2022', 12, 'Net 60', 'BU7832')
Insert Sales Values('7131', '92207', '08/25/2021', 51, 'Net 60', 'MC2222')
Insert Sales Values('7131', '92210', '01/02/2024', 8, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '92213', '08/30/2021', 42, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '92216', '06/09/2024', 57, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '92219', '10/24/2022', 6, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92222', '09/05/2024', 58, 'Net 30', 'PC1035')
Insert Sales Values('7896', '92225', '06/26/2024', 102, 'Net 60', 'BU1032')
Insert Sales Values('7896', '92228', '07/16/2022', 96, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92231', '08/26/2023', 54, 'Net 30', 'PC8888')
Insert Sales Values('8042', '92234', '04/16/2022', 41, 'ON invoice', 'PS2091')
Insert Sales Values('8042', '92237', '03/06/2023', 93, 'Net 60', 'PS2091')
Insert Sales Values('8042', '92240', '08/01/2021', 65, 'Net 30', 'TC3218')
Insert Sales Values('8042', '92243', '08/14/2023', 33, 'Net 30', 'TC4203')
Insert Sales Values('6380', '92246', '11/24/2020', 17, 'Net 30', 'TC7777')
Insert Sales Values('6380', '92249', '08/17/2023', 72, 'Net 30', 'PS2091')
Insert Sales Values('7066', '92252', '10/27/2022', 30, 'Net 30', 'MC3021')
Insert Sales Values('7066', '92255', '07/18/2022', 61, 'Net 60', 'PS1372')
Insert Sales Values('7067', '92258', '06/18/2021', 67, 'Net 60', 'PS2106')
Insert Sales Values('7067', '92261', '02/19/2022', 22, 'Net 60', 'PS3333')
Insert Sales Values('7067', '92264', '08/30/2021', 14, 'Net 60', 'PS7777')
Insert Sales Values('7067', '92267', '02/01/2022', 12, 'Net 60', 'BU7832')
Insert Sales Values('7131', '92270', '03/01/2023', 94, 'Net 60', 'MC2222')
Insert Sales Values('7131', '92273', '07/02/2023', 43, 'ON invoice', 'BU2075')
Insert Sales Values('7131', '92276', '05/31/2021', 63, 'ON invoice', 'MC3021')
Insert Sales Values('7131', '92279', '07/01/2023', 54, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '92282', '10/20/2022', 33, 'Net 30', 'BU1111')
Insert Sales Values('8042', '92285', '02/20/2022', 92, 'Net 30', 'PC1035')
Insert Sales Values('8042', '92288', '05/08/2022', 69, 'Net 60', 'BU1032')
Insert Sales Values('8042', '92291', '02/23/2022', 64, 'Net 60', 'PS2091')
Insert Sales Values('8042', '92294', '08/24/2022', 18, 'Net 30', 'PC8888')
Insert Sales Values('6380', '92297', '12/28/2022', 6, 'ON invoice', 'PS2091')
Insert Sales Values('6380', '92300', '10/14/2020', 27, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92303', '02/27/2021', 24, 'Net 30', 'TC3218')
Insert Sales Values('7066', '92306', '11/07/2022', 68, 'Net 30', 'TC4203')
Insert Sales Values('7067', '92309', '05/01/2024', 41, 'Net 30', 'TC7777')
Insert Sales Values('7067', '92312', '09/24/2021', 99, 'Net 30', 'PS2091')
Insert Sales Values('7067', '92315', '07/14/2020', 101, 'Net 30', 'MC3021')
Insert Sales Values('7067', '92318', '02/03/2022', 88, 'Net 60', 'PS1372')
Insert Sales Values('7131', '92321', '05/23/2022', 87, 'Net 60', 'PS2106')
Insert Sales Values('7131', '92324', '09/19/2020', 61, 'Net 60', 'PS3333')
Insert Sales Values('7131', '92327', '08/21/2020', 92, 'Net 60', 'PS7777')
Insert Sales Values('7131', '92330', '09/28/2023', 31, 'Net 60', 'BU7832')
Insert Sales Values('7131', '92333', '03/03/2021', 35, 'Net 60', 'MC2222')
Insert Sales Values('7131', '92336', '07/10/2024', 16, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '92339', '06/04/2021', 38, 'ON invoice', 'MC3021')
Insert Sales Values('7896', '92342', '05/13/2023', 63, 'ON invoice', 'BU1032')
Insert Sales Values('7896', '92345', '11/24/2023', 52, 'Net 30', 'BU1111')
Insert Sales Values('8042', '92348', '05/31/2022', 88, 'Net 30', 'PC1035')
Insert Sales Values('8042', '92351', '02/17/2023', 46, 'Net 60', 'BU1032')
Insert Sales Values('8042', '92354', '08/30/2020', 105, 'Net 60', 'PS2091')
Insert Sales Values('8042', '92357', '04/11/2024', 48, 'Net 30', 'PC8888')
Insert Sales Values('6380', '92360', '05/16/2022', 77, 'ON invoice', 'PS2091')
Insert Sales Values('6380', '92363', '09/24/2022', 28, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92366', '11/18/2023', 87, 'Net 30', 'TC3218')
Insert Sales Values('7066', '92369', '08/09/2023', 10, 'Net 30', 'TC4203')
Insert Sales Values('7067', '92372', '12/27/2023', 59, 'Net 30', 'TC7777')
Insert Sales Values('7067', '92375', '03/14/2023', 81, 'Net 30', 'PS2091')
Insert Sales Values('7067', '92378', '12/16/2021', 75, 'Net 30', 'MC3021')
Insert Sales Values('7067', '92381', '02/12/2021', 49, 'Net 60', 'PS1372')
Insert Sales Values('7131', '92384', '03/25/2022', 99, 'Net 60', 'PS2106')
Insert Sales Values('7131', '92387', '02/11/2023', 82, 'Net 60', 'PS3333')
Insert Sales Values('7131', '92390', '11/23/2020', 12, 'Net 60', 'PS7777')
Insert Sales Values('7131', '92393', '11/02/2021', 105, 'Net 60', 'BU7832')
Insert Sales Values('7131', '92396', '12/24/2023', 17, 'Net 60', 'MC2222')
Insert Sales Values('8042', '92399', '03/31/2022', 23, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '92402', '01/11/2024', 43, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '92405', '12/11/2023', 40, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '92408', '07/15/2021', 51, 'Net 30', 'BU1111')
Insert Sales Values('6380', '92411', '08/07/2020', 26, 'Net 30', 'PC1035')
Insert Sales Values('6380', '92414', '02/21/2021', 18, 'Net 60', 'BU1032')
Insert Sales Values('7066', '92417', '07/13/2021', 105, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92420', '09/25/2022', 44, 'Net 30', 'PC8888')
Insert Sales Values('7067', '92423', '11/05/2020', 26, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '92426', '03/30/2021', 33, 'Net 60', 'PS2091')
Insert Sales Values('7067', '92429', '09/13/2024', 78, 'Net 30', 'TC3218')
Insert Sales Values('7067', '92432', '10/30/2023', 102, 'Net 30', 'TC4203')
Insert Sales Values('7131', '92435', '03/05/2023', 43, 'Net 30', 'TC7777')
Insert Sales Values('7131', '92438', '09/17/2022', 105, 'Net 30', 'PS2091')
Insert Sales Values('7131', '92441', '02/22/2021', 100, 'Net 30', 'MC3021')
Insert Sales Values('7131', '92444', '12/21/2021', 51, 'Net 60', 'PS1372')
Insert Sales Values('7131', '92447', '10/31/2023', 96, 'Net 60', 'PS2106')
Insert Sales Values('7131', '92450', '02/21/2023', 96, 'Net 60', 'PS3333')
Insert Sales Values('7896', '92453', '10/29/2022', 77, 'Net 60', 'PS7777')
Insert Sales Values('7896', '92456', '03/21/2023', 33, 'Net 60', 'BU7832')
Insert Sales Values('7896', '92459', '08/24/2022', 45, 'Net 60', 'MC2222')
Insert Sales Values('8042', '92462', '12/18/2022', 32, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '92465', '08/17/2024', 31, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '92468', '05/24/2023', 58, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '92471', '05/31/2021', 59, 'Net 30', 'BU1111')
Insert Sales Values('6380', '92474', '09/06/2022', 65, 'Net 30', 'PC1035')
Insert Sales Values('6380', '92477', '02/15/2022', 92, 'Net 60', 'BU1032')
Insert Sales Values('7066', '92480', '01/30/2021', 8, 'Net 60', 'PS2091')
Insert Sales Values('7066', '92483', '05/03/2023', 32, 'Net 30', 'PC8888')
Insert Sales Values('7067', '92486', '08/18/2021', 97, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '92489', '06/14/2024', 53, 'Net 60', 'PS2091')
Insert Sales Values('7067', '92492', '08/11/2024', 12, 'Net 30', 'TC3218')
Insert Sales Values('7067', '92495', '09/26/2021', 73, 'Net 30', 'TC4203')
Insert Sales Values('7131', '92498', '10/01/2021', 50, 'Net 30', 'TC7777')
Insert Sales Values('7131', '92501', '08/31/2021', 18, 'Net 30', 'PS2091')
Insert Sales Values('7131', '92504', '06/11/2024', 55, 'Net 30', 'MC3021')
Insert Sales Values('7131', '92507', '06/07/2023', 19, 'Net 60', 'PS1372')
Insert Sales Values('7131', '92510', '11/12/2023', 61, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92513', '06/26/2021', 13, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92516', '02/01/2022', 14, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92519', '10/30/2022', 85, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92522', '02/29/2024', 17, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92525', '11/23/2020', 63, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92528', '09/24/2023', 13, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92531', '02/09/2023', 41, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92534', '04/23/2022', 57, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92537', '08/11/2020', 90, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92540', '10/31/2020', 16, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92543', '01/05/2023', 96, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92546', '03/18/2021', 85, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92549', '07/29/2020', 93, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92552', '02/26/2021', 88, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92555', '02/28/2022', 81, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92558', '04/14/2021', 87, 'Net 30', 'TC4203')
Insert Sales Values('7896', '92561', '05/27/2023', 10, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92564', '11/01/2022', 71, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92567', '05/05/2021', 67, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92570', '12/14/2021', 50, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92573', '01/27/2024', 9, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92576', '03/08/2022', 76, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92579', '01/20/2021', 77, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92582', '09/13/2021', 36, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92585', '10/23/2021', 87, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92588', '01/02/2021', 8, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92591', '04/20/2024', 84, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92594', '03/05/2021', 36, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92597', '09/21/2020', 25, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92600', '06/15/2020', 64, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92603', '05/15/2023', 6, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92606', '03/30/2021', 69, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92609', '09/09/2023', 46, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92612', '08/17/2020', 8, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92615', '07/15/2020', 98, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92618', '07/20/2024', 69, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92621', '07/25/2024', 34, 'Net 30', 'TC4203')
Insert Sales Values('7896', '92624', '05/01/2024', 19, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92627', '10/05/2020', 70, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92630', '03/26/2022', 14, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92633', '08/24/2023', 85, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92636', '10/16/2023', 35, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92639', '11/21/2021', 7, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92642', '02/09/2022', 28, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92645', '07/31/2024', 92, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92648', '01/20/2024', 100, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92651', '01/10/2022', 101, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92654', '08/03/2024', 52, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92657', '01/09/2021', 74, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92660', '08/12/2022', 28, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92663', '06/12/2023', 48, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92666', '04/02/2021', 39, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92669', '12/29/2022', 51, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92672', '06/11/2021', 104, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92675', '01/18/2023', 56, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92678', '03/03/2021', 86, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92681', '10/12/2023', 45, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92684', '10/06/2020', 35, 'Net 30', 'TC4203')
Insert Sales Values('7896', '92687', '08/30/2022', 77, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92690', '06/26/2024', 54, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92693', '01/17/2024', 97, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92696', '11/09/2021', 37, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92699', '04/24/2021', 17, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92702', '01/09/2024', 9, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92705', '07/24/2024', 88, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92708', '09/07/2023', 31, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92711', '09/03/2020', 28, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92714', '06/21/2022', 12, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92717', '06/02/2022', 82, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92720', '04/09/2022', 5, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92723', '09/25/2023', 72, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92726', '01/13/2023', 38, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92729', '09/24/2021', 30, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92732', '05/08/2023', 52, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92735', '12/26/2020', 16, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92738', '04/11/2024', 32, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92741', '02/01/2021', 103, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92744', '09/06/2022', 28, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92747', '04/10/2022', 72, 'Net 30', 'TC4203')
Insert Sales Values('7896', '92750', '08/07/2024', 45, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92753', '06/14/2021', 87, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92756', '03/27/2024', 46, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92759', '10/04/2021', 90, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92762', '07/26/2022', 42, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92765', '02/18/2021', 16, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92768', '09/11/2024', 45, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92771', '04/15/2022', 25, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92774', '07/21/2022', 26, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92777', '11/03/2020', 86, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92780', '09/01/2024', 26, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92783', '06/08/2022', 68, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92786', '09/02/2020', 16, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92789', '04/13/2021', 56, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92792', '07/16/2023', 62, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92795', '02/18/2024', 28, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92798', '10/29/2020', 7, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92801', '06/22/2021', 53, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92804', '04/26/2023', 76, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92807', '05/16/2023', 79, 'Net 30', 'TC3218')
Insert Sales Values('7896', '92810', '03/03/2021', 79, 'Net 30', 'TC4203')
Insert Sales Values('7896', '92813', '03/16/2023', 11, 'Net 30', 'TC7777')
Insert Sales Values('8042', '92816', '08/02/2021', 64, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92819', '05/10/2024', 81, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92822', '12/14/2022', 29, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92825', '01/16/2023', 54, 'Net 60', 'PS2106')
Insert Sales Values('8042', '92828', '02/06/2024', 25, 'Net 60', 'PS3333')
Insert Sales Values('8042', '92831', '12/15/2020', 55, 'Net 60', 'PS7777')
Insert Sales Values('8042', '92834', '10/19/2021', 41, 'Net 60', 'BU7832')
Insert Sales Values('6380', '92837', '05/21/2021', 48, 'Net 60', 'MC2222')
Insert Sales Values('6380', '92840', '08/12/2023', 66, 'ON invoice', 'BU2075')
Insert Sales Values('7066', '92843', '07/12/2021', 12, 'ON invoice', 'MC3021')
Insert Sales Values('7066', '92846', '06/03/2022', 55, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92849', '10/17/2022', 105, 'Net 30', 'BU1111')
Insert Sales Values('7067', '92852', '08/02/2024', 24, 'Net 30', 'PC1035')
Insert Sales Values('7067', '92855', '07/21/2023', 30, 'Net 60', 'BU1032')
Insert Sales Values('7067', '92858', '05/10/2024', 97, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92861', '12/04/2023', 32, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92864', '07/09/2021', 45, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92867', '01/22/2024', 68, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92870', '06/17/2023', 103, 'Net 30', 'TC3218')
Insert Sales Values('7131', '92873', '02/06/2023', 8, 'Net 30', 'TC4203')
Insert Sales Values('7131', '92876', '12/02/2020', 48, 'Net 30', 'TC7777')
Insert Sales Values('7896', '92879', '07/31/2024', 8, 'Net 30', 'PS2091')
Insert Sales Values('8042', '92882', '02/13/2023', 78, 'Net 30', 'MC3021')
Insert Sales Values('8042', '92885', '03/11/2023', 100, 'Net 60', 'PS1372')
Insert Sales Values('8042', '92888', '12/10/2022', 103, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92891', '11/13/2021', 72, 'Net 60', 'PS3333')
Insert Sales Values('6380', '92894', '05/24/2023', 62, 'Net 60', 'PS7777')
Insert Sales Values('7066', '92897', '10/23/2020', 52, 'Net 60', 'BU7832')
Insert Sales Values('7066', '92900', '03/27/2021', 61, 'Net 60', 'MC2222')
Insert Sales Values('7067', '92903', '02/15/2022', 8, 'ON invoice', 'BU2075')
Insert Sales Values('7067', '92906', '12/08/2020', 68, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '92909', '02/22/2024', 19, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '92912', '03/21/2022', 49, 'Net 30', 'BU1111')
Insert Sales Values('7131', '92915', '04/08/2022', 20, 'Net 30', 'PC1035')
Insert Sales Values('7131', '92918', '09/03/2024', 95, 'Net 60', 'BU1032')
Insert Sales Values('7131', '92921', '07/02/2022', 65, 'Net 60', 'PS2091')
Insert Sales Values('7131', '92924', '11/15/2021', 99, 'Net 30', 'PC8888')
Insert Sales Values('7131', '92927', '12/28/2022', 88, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '92930', '02/28/2023', 38, 'Net 60', 'PS2091')
Insert Sales Values('7896', '92933', '06/22/2024', 26, 'Net 30', 'TC3218')
Insert Sales Values('6380', '92936', '05/15/2021', 96, 'Net 30', 'TC4203')
Insert Sales Values('6380', '92939', '08/16/2022', 26, 'Net 30', 'TC7777')
Insert Sales Values('6380', '92942', '06/07/2021', 90, 'Net 30', 'PS2091')
Insert Sales Values('7066', '92945', '10/31/2023', 58, 'Net 30', 'MC3021')
Insert Sales Values('6380', '92948', '04/07/2023', 70, 'Net 60', 'PS1372')
Insert Sales Values('6380', '92951', '06/22/2024', 64, 'Net 60', 'PS2106')
Insert Sales Values('6380', '92954', '04/06/2024', 48, 'Net 60', 'PS3333')
Insert Sales Values('7066', '92957', '07/17/2021', 34, 'Net 60', 'PS7777')
Insert Sales Values('6380', '92960', '08/15/2023', 88, 'Net 60', 'BU7832')
Insert Sales Values('6380', '92963', '04/27/2021', 61, 'Net 60', 'MC2222')
Insert Sales Values('7066', '92966', '08/12/2020', 42, 'ON invoice', 'BU2075')
Insert Sales Values('7066', '92969', '11/06/2021', 5, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '92972', '09/29/2020', 46, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '92975', '11/06/2022', 71, 'Net 30', 'BU1111')
Insert Sales Values('8042', '92978', '10/03/2021', 97, 'Net 30', 'PC1035')
Insert Sales Values('8042', '92981', '08/06/2022', 93, 'Net 60', 'BU1032')
Insert Sales Values('6380', '92984', '06/29/2023', 63, 'Net 60', 'PS2091')
Insert Sales Values('6380', '92987', '08/13/2021', 72, 'Net 30', 'PC8888')
Insert Sales Values('7066', '92990', '07/11/2020', 31, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '92993', '01/16/2024', 92, 'Net 60', 'PS2091')
Insert Sales Values('7067', '92996', '12/03/2020', 63, 'Net 30', 'TC3218')
Insert Sales Values('7067', '92999', '09/10/2022', 48, 'Net 30', 'TC4203')
Insert Sales Values('7067', '93002', '05/30/2023', 68, 'Net 30', 'TC7777')
Insert Sales Values('7067', '93005', '05/16/2024', 105, 'Net 30', 'PS2091')
Insert Sales Values('7131', '93008', '07/30/2024', 15, 'Net 30', 'MC3021')
Insert Sales Values('7131', '93011', '09/26/2022', 63, 'Net 60', 'PS1372')
Insert Sales Values('7131', '93014', '07/07/2023', 25, 'Net 60', 'PS2106')
Insert Sales Values('7131', '93017', '08/21/2020', 79, 'Net 60', 'PS3333')
Insert Sales Values('7131', '93020', '02/24/2024', 40, 'Net 60', 'PS7777')
Insert Sales Values('7131', '93023', '11/30/2021', 66, 'Net 60', 'BU7832')
Insert Sales Values('7896', '93026', '05/12/2022', 63, 'Net 60', 'MC2222')
Insert Sales Values('7896', '93029', '08/17/2024', 56, 'ON invoice', 'BU2075')
Insert Sales Values('7896', '93032', '02/15/2022', 7, 'ON invoice', 'MC3021')
Insert Sales Values('8042', '93035', '02/03/2024', 52, 'ON invoice', 'BU1032')
Insert Sales Values('8042', '93038', '11/14/2022', 83, 'Net 30', 'BU1111')
Insert Sales Values('8042', '93041', '11/16/2022', 43, 'Net 30', 'PC1035')
Insert Sales Values('8042', '93044', '05/31/2022', 37, 'Net 60', 'BU1032')
Insert Sales Values('6380', '93047', '07/11/2022', 24, 'Net 60', 'PS2091')
Insert Sales Values('6380', '93050', '03/05/2024', 100, 'Net 30', 'PC8888')
Insert Sales Values('7066', '93053', '02/10/2023', 38, 'ON invoice', 'PS2091')
Insert Sales Values('7066', '93056', '10/03/2022', 62, 'Net 60', 'PS2091')
Insert Sales Values('7067', '93059', '02/10/2023', 56, 'Net 30', 'TC3218')
Insert Sales Values('7067', '93062', '10/21/2020', 85, 'Net 30', 'TC4203')
Insert Sales Values('7067', '93065', '10/02/2020', 24, 'Net 30', 'TC7777')
Insert Sales Values('7067', '93068', '02/28/2024', 49, 'Net 30', 'PS2091')
Insert Sales Values('7131', '93071', '05/31/2024', 96, 'Net 30', 'MC3021')
Insert Sales Values('7131', '93074', '10/31/2020', 72, 'Net 60', 'PS1372')
Insert Sales Values('7131', '93077', '10/30/2020', 104, 'Net 60', 'PS2106')
Insert Sales Values('7131', '93080', '05/07/2023', 32, 'Net 60', 'PS3333')
Insert Sales Values('7131', '93083', '02/04/2023', 82, 'Net 60', 'PS7777')
Insert Sales Values('8042', '93086', '07/30/2020', 24, 'Net 60', 'BU7832')
Insert Sales Values('8042', '93089', '08/29/2023', 37, 'Net 60', 'MC2222')
Insert Sales Values('8042', '93092', '03/31/2024', 43, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '93095', '08/19/2020', 52, 'ON invoice', 'MC3021')
Insert Sales Values('6380', '93098', '08/05/2022', 17, 'ON invoice', 'BU1032')
Insert Sales Values('6380', '93101', '03/02/2024', 57, 'Net 30', 'BU1111')
Insert Sales Values('7066', '93104', '02/15/2022', 62, 'Net 30', 'PC1035')
Insert Sales Values('7066', '93107', '02/06/2021', 30, 'Net 60', 'BU1032')
Insert Sales Values('7067', '93110', '06/11/2023', 84, 'Net 60', 'PS2091')
Insert Sales Values('7067', '93113', '08/01/2020', 93, 'Net 30', 'PC8888')
Insert Sales Values('7067', '93116', '06/22/2022', 28, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '93119', '12/01/2020', 67, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93122', '01/22/2021', 72, 'Net 30', 'TC3218')
Insert Sales Values('7131', '93125', '12/03/2022', 58, 'Net 30', 'TC4203')
Insert Sales Values('7131', '93128', '07/14/2023', 54, 'Net 30', 'TC7777')
Insert Sales Values('7131', '93131', '07/15/2024', 92, 'Net 30', 'PS2091')
Insert Sales Values('7131', '93134', '12/27/2020', 23, 'Net 30', 'MC3021')
Insert Sales Values('7131', '93137', '04/04/2023', 14, 'Net 60', 'PS1372')
Insert Sales Values('7896', '93140', '08/17/2023', 24, 'Net 60', 'PS2106')
Insert Sales Values('7896', '93143', '12/24/2020', 29, 'Net 60', 'PS3333')
Insert Sales Values('7896', '93146', '02/07/2022', 67, 'Net 60', 'PS7777')
Insert Sales Values('8042', '93149', '06/21/2020', 21, 'Net 60', 'BU7832')
Insert Sales Values('8042', '93152', '04/23/2021', 85, 'Net 60', 'MC2222')
Insert Sales Values('8042', '93155', '11/09/2022', 49, 'ON invoice', 'BU2075')
Insert Sales Values('8042', '93158', '01/12/2024', 21, 'ON invoice', 'MC3021')
Insert Sales Values('6380', '93161', '03/17/2024', 76, 'ON invoice', 'BU1032')
Insert Sales Values('6380', '93164', '12/15/2023', 7, 'Net 30', 'BU1111')
Insert Sales Values('7066', '93167', '12/02/2020', 24, 'Net 30', 'PC1035')
Insert Sales Values('7066', '93170', '08/25/2021', 6, 'Net 60', 'BU1032')
Insert Sales Values('7067', '93173', '04/14/2024', 29, 'Net 60', 'PS2091')
Insert Sales Values('7067', '93176', '07/24/2021', 41, 'Net 30', 'PC8888')
Insert Sales Values('7067', '93179', '12/25/2023', 38, 'ON invoice', 'PS2091')
Insert Sales Values('7067', '93182', '02/26/2021', 72, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93185', '05/12/2023', 24, 'Net 30', 'TC3218')
Insert Sales Values('7131', '93188', '04/20/2024', 20, 'Net 30', 'TC4203')
Insert Sales Values('7131', '93191', '11/26/2021', 89, 'Net 30', 'TC7777')
Insert Sales Values('7131', '93194', '07/25/2022', 6, 'Net 30', 'PS2091')
Insert Sales Values('7131', '93197', '06/27/2023', 37, 'Net 30', 'MC3021')
Insert Sales Values('8042', '93200', '11/01/2021', 63, 'Net 60', 'PS1372')
Insert Sales Values('8042', '93203', '09/05/2020', 6, 'Net 60', 'PS2106')
Insert Sales Values('8042', '93206', '12/30/2022', 5, 'Net 60', 'PS3333')
Insert Sales Values('8042', '93209', '12/09/2023', 55, 'Net 60', 'PS7777')
Insert Sales Values('6380', '93212', '01/28/2021', 101, 'Net 60', 'BU7832')
Insert Sales Values('6380', '93215', '07/16/2023', 88, 'Net 60', 'MC2222')
Insert Sales Values('7066', '93218', '07/25/2023', 90, 'ON invoice', 'BU2075')
Insert Sales Values('7066', '93221', '07/28/2020', 86, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '93224', '02/08/2024', 34, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '93227', '11/06/2020', 37, 'Net 30', 'BU1111')
Insert Sales Values('7067', '93230', '12/03/2022', 74, 'Net 30', 'PC1035')
Insert Sales Values('7067', '93233', '11/29/2022', 31, 'Net 60', 'BU1032')
Insert Sales Values('7131', '93236', '11/10/2023', 27, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93239', '02/12/2024', 64, 'Net 30', 'PC8888')
Insert Sales Values('7131', '93242', '01/03/2021', 26, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '93245', '08/25/2022', 96, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93248', '06/30/2021', 52, 'Net 30', 'TC3218')
Insert Sales Values('7131', '93251', '01/09/2023', 63, 'Net 30', 'TC4203')
Insert Sales Values('7896', '93254', '03/26/2023', 17, 'Net 30', 'TC7777')
Insert Sales Values('7896', '93257', '05/31/2023', 44, 'Net 30', 'PS2091')
Insert Sales Values('7896', '93260', '10/13/2020', 46, 'Net 30', 'MC3021')
Insert Sales Values('8042', '93263', '05/22/2021', 32, 'Net 60', 'PS1372')
Insert Sales Values('8042', '93266', '06/27/2022', 18, 'Net 60', 'PS2106')
Insert Sales Values('8042', '93269', '06/16/2020', 104, 'Net 60', 'PS3333')
Insert Sales Values('8042', '93272', '06/17/2023', 34, 'Net 60', 'PS7777')
Insert Sales Values('6380', '93275', '04/10/2023', 83, 'Net 60', 'BU7832')
Insert Sales Values('6380', '93278', '07/17/2021', 61, 'Net 60', 'MC2222')
Insert Sales Values('7066', '93281', '11/14/2021', 96, 'ON invoice', 'BU2075')
Insert Sales Values('7066', '93284', '02/17/2024', 58, 'ON invoice', 'MC3021')
Insert Sales Values('7067', '93287', '11/12/2023', 51, 'ON invoice', 'BU1032')
Insert Sales Values('7067', '93290', '03/15/2023', 36, 'Net 30', 'BU1111')
Insert Sales Values('7067', '93293', '06/21/2022', 13, 'Net 30', 'PC1035')
Insert Sales Values('7067', '93296', '03/13/2023', 75, 'Net 60', 'BU1032')
Insert Sales Values('7131', '93299', '04/09/2024', 96, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93302', '12/23/2022', 45, 'Net 30', 'PC8888')
Insert Sales Values('7131', '93305', '03/15/2021', 83, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '93308', '01/03/2023', 46, 'Net 60', 'PS2091')
Insert Sales Values('7131', '93311', '09/12/2021', 14, 'Net 60', 'TC3218')
Insert Sales Values('8042', '93314', '12/27/2022', 76, 'Net 30', 'TC4203')
Insert Sales Values('8042', '93317', '08/12/2024', 40, 'ON invoice', 'TC7777')
Insert Sales Values('8042', '93320', '04/07/2023', 16, 'Net 60', 'PS2091')
Insert Sales Values('8042', '93323', '09/14/2023', 74, 'Net 30', 'MC3021')
Insert Sales Values('6380', '93326', '10/03/2020', 56, 'Net 30', 'PS1372')
Insert Sales Values('6380', '93329', '06/13/2024', 103, 'Net 30', 'PS2106')
Insert Sales Values('7066', '93332', '07/14/2024', 60, 'Net 30', 'PS3333')
Insert Sales Values('7066', '93335', '03/02/2023', 8, 'Net 30', 'PS7777')
Insert Sales Values('7067', '93338', '06/29/2022', 78, 'Net 60', 'BU7832')
Insert Sales Values('7067', '93341', '08/12/2022', 38, 'Net 60', 'MC2222')
Insert Sales Values('7067', '93344', '10/26/2021', 105, 'Net 60', 'BU2075')
Insert Sales Values('7067', '93347', '01/07/2024', 28, 'Net 60', 'MC3021')
Insert Sales Values('7131', '93350', '07/03/2021', 101, 'Net 60', 'BU1032')
Insert Sales Values('7131', '93353', '08/08/2022', 62, 'Net 60', 'BU1111')
Insert Sales Values('7131', '93356', '07/15/2022', 72, 'ON invoice', 'PC1035')
Insert Sales Values('7131', '93359', '12/19/2022', 95, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '93362', '05/02/2024', 105, 'ON invoice', 'PS2091')
Insert Sales Values('7131', '93365', '06/21/2021', 81, 'Net 30', 'PC8888')
Insert Sales Values('7896', '93368', '04/03/2023', 86, 'Net 30', 'PS2091')
Insert Sales Values('7896', '93371', '10/01/2020', 10, 'Net 60', 'PS2091')
Insert Sales Values('7896', '93374', '07/30/2020', 85, 'Net 60', 'TC3218')
Insert Sales Values('8042', '93377', '12/13/2021', 83, 'Net 30', 'TC4203')
Insert Sales Values('8042', '93380', '07/05/2024', 91, 'ON invoice', 'TC7777')
Insert Sales Values('8042', '93383', '11/21/2022', 92, 'Net 60', 'PS2091')
Insert Sales Values('8042', '93386', '11/05/2022', 99, 'Net 30', 'MC3021')
Insert Sales Values('6380', '93389', '05/19/2021', 56, 'Net 30', 'PS1372')
Insert Sales Values('6380', '93392', '06/02/2024', 16, 'Net 30', 'PS2106')
Insert Sales Values('7066', '93395', '06/20/2022', 85, 'Net 30', 'PS3333')
Insert Sales Values('7066', '93398', '05/12/2021', 88, 'Net 30', 'PS7777')
Insert Sales Values('7067', '93401', '11/12/2020', 27, 'Net 60', 'BU7832')
Insert Sales Values('7067', '93404', '06/24/2023', 99, 'Net 60', 'MC2222')
Insert Sales Values('7067', '93407', '08/21/2022', 86, 'Net 60', 'BU2075')
Insert Sales Values('7067', '93410', '08/29/2023', 79, 'Net 60', 'MC3021')
Insert Sales Values('7131', '93413', '02/22/2022', 87, 'Net 60', 'BU1032')
Insert Sales Values('7131', '93416', '05/01/2022', 60, 'Net 60', 'BU1111')
Insert Sales Values('7131', '93419', '08/15/2022', 43, 'ON invoice', 'PC1035')
Insert Sales Values('7131', '93422', '08/28/2021', 60, 'ON invoice', 'BU1032')
Insert Sales Values('7131', '93425', '04/21/2024', 13, 'ON invoice', 'PS2091')


GO

raiserror('Now at the inserts to RoySched ....',0,1)

GO

insert RoySched values('BU1032', 0, 5000, 10)
insert RoySched values('BU1032', 5001, 50000, 12)
insert RoySched values('PC1035', 0, 2000, 10)
insert RoySched values('PC1035', 2001, 3000, 12)
insert RoySched values('PC1035', 3001, 4000, 14)
insert RoySched values('PC1035', 4001, 10000, 16)
insert RoySched values('PC1035', 10001, 50000, 18)
insert RoySched values('BU2075', 0, 1000, 10)
insert RoySched values('BU2075', 1001, 3000, 12)
insert RoySched values('BU2075', 3001, 5000, 14)

GO

insert RoySched values('BU2075', 5001, 7000, 16)
insert RoySched values('BU2075', 7001, 10000, 18)
insert RoySched values('BU2075', 10001, 12000, 20)
insert RoySched values('BU2075', 12001, 14000, 22)
insert RoySched values('BU2075', 14001, 50000, 24)
insert RoySched values('PS2091', 0, 1000, 10)
insert RoySched values('PS2091', 1001, 5000, 12)
insert RoySched values('PS2091', 5001, 10000, 14)
insert RoySched values('PS2091', 10001, 50000, 16)
insert RoySched values('PS2106', 0, 2000, 10)

GO

insert RoySched values('PS2106', 2001, 5000, 12)
insert RoySched values('PS2106', 5001, 10000, 14)
insert RoySched values('PS2106', 10001, 50000, 16)
insert RoySched values('MC3021', 0, 1000, 10)
insert RoySched values('MC3021', 1001, 2000, 12)
insert RoySched values('MC3021', 2001, 4000, 14)
insert RoySched values('MC3021', 4001, 6000, 16)
insert RoySched values('MC3021', 6001, 8000, 18)
insert RoySched values('MC3021', 8001, 10000, 20)
insert RoySched values('MC3021', 10001, 12000, 22)

GO

insert RoySched values('MC3021', 12001, 50000, 24)
insert RoySched values('TC3218', 0, 2000, 10)
insert RoySched values('TC3218', 2001, 4000, 12)
insert RoySched values('TC3218', 4001, 6000, 14)
insert RoySched values('TC3218', 6001, 8000, 16)
insert RoySched values('TC3218', 8001, 10000, 18)
insert RoySched values('TC3218', 10001, 12000, 20)
insert RoySched values('TC3218', 12001, 14000, 22)
insert RoySched values('TC3218', 14001, 50000, 24)
insert RoySched values('PC8888', 0, 5000, 10)
insert RoySched values('PC8888', 5001, 10000, 12)

GO

insert RoySched values('PC8888', 10001, 15000, 14)
insert RoySched values('PC8888', 15001, 50000, 16)
insert RoySched values('PS7777', 0, 5000, 10)
insert RoySched values('PS7777', 5001, 50000, 12)
insert RoySched values('PS3333', 0, 5000, 10)
insert RoySched values('PS3333', 5001, 10000, 12)
insert RoySched values('PS3333', 10001, 15000, 14)
insert RoySched values('PS3333', 15001, 50000, 16)
insert RoySched values('BU1111', 0, 4000, 10)
insert RoySched values('BU1111', 4001, 8000, 12)
insert RoySched values('BU1111', 8001, 10000, 14)

GO

insert RoySched values('BU1111', 12001, 16000, 16)
insert RoySched values('BU1111', 16001, 20000, 18)
insert RoySched values('BU1111', 20001, 24000, 20)
insert RoySched values('BU1111', 24001, 28000, 22)
insert RoySched values('BU1111', 28001, 50000, 24)
insert RoySched values('MC2222', 0, 2000, 10)
insert RoySched values('MC2222', 2001, 4000, 12)
insert RoySched values('MC2222', 4001, 8000, 14)
insert RoySched values('MC2222', 8001, 12000, 16)

GO

insert RoySched values('MC2222', 12001, 20000, 18)
insert RoySched values('MC2222', 20001, 50000, 20)
insert RoySched values('TC7777', 0, 5000, 10)
insert RoySched values('TC7777', 5001, 15000, 12)
insert RoySched values('TC7777', 15001, 50000, 14)
insert RoySched values('TC4203', 0, 2000, 10)
insert RoySched values('TC4203', 2001, 8000, 12)
insert RoySched values('TC4203', 8001, 16000, 14)
insert RoySched values('TC4203', 16001, 24000, 16)
insert RoySched values('TC4203', 24001, 32000, 18)

GO

insert RoySched values('TC4203', 32001, 40000, 20)
insert RoySched values('TC4203', 40001, 50000, 22)
insert RoySched values('BU7832', 0, 5000, 10)
insert RoySched values('BU7832', 5001, 10000, 12)
insert RoySched values('BU7832', 10001, 15000, 14)
insert RoySched values('BU7832', 15001, 20000, 16)
insert RoySched values('BU7832', 20001, 25000, 18)
insert RoySched values('BU7832', 25001, 30000, 20)
insert RoySched values('BU7832', 30001, 35000, 22)
insert RoySched values('BU7832', 35001, 50000, 24)

GO

insert RoySched values('PS1372', 0, 10000, 10)
insert RoySched values('PS1372', 10001, 20000, 12)
insert RoySched values('PS1372', 20001, 30000, 14)
insert RoySched values('PS1372', 30001, 40000, 16)
insert RoySched values('PS1372', 40001, 50000, 18)

GO

raiserror('Now at the inserts to Discounts ....',0,1)

GO

insert Discounts values('Initial Customer', NULL, NULL, NULL, 10.5)
insert Discounts values('Volume Discount', NULL, 100, 1000, 6.7)
insert Discounts values('Customer Discount', '8042', NULL, NULL, 5.0)

GO

raiserror('Now at the inserts to Jobs ....',0,1)

GO

insert Jobs values ('New Hire - Job not specified', 10, 10)
insert Jobs values ('Chief Executive Officer', 200, 250)
insert Jobs values ('Business Operations Manager', 175, 225)
insert Jobs values ('Chief Financial Officier', 175, 250)
insert Jobs values ('Publisher', 150, 250)
insert Jobs values ('Managing Editor', 140, 225)
insert Jobs values ('Marketing Manager', 120, 200)
insert Jobs values ('Public Relations Manager', 100, 175)
insert Jobs values ('Acquisitions Manager', 75, 175)
insert Jobs values ('Productions Manager', 75, 165)
insert Jobs values ('Operations Manager', 75, 150)
insert Jobs values ('Editor', 25, 100)
insert Jobs values ('Sales Representative', 25, 100)
insert Jobs values ('Designer', 25, 100)

GO

raiserror('Now at the inserts to Employee ....',0,1)

GO

insert Employee values ('PTC11962M', 'Philip', 'T', 'Cramer', 2, 215, '9952', '11/11/19')
insert Employee values ('AMD15433F', 'Ann', 'M', 'Devon', 3, 200, '9952', '07/16/21')
insert Employee values ('F-C16315M', 'Francisco',NULL, 'Chang', 4, 227, '9952', '11/03/20')
insert Employee values ('LAL21447M', 'Laurence', 'A', 'Lebihan', 5, 175, '0736', '06/03/20')
insert Employee values ('PXH22250M', 'Paul', 'X', 'Henriot', 5, 159, '0877', '08/19/23')
insert Employee values ('SKO22412M', 'Sven', 'K', 'Ottlieb', 5, 150, '1389', '04/05/21')
insert Employee values ('RBM23061F', 'Rita', 'B', 'Muller', 5, 198, '1622', '10/09/23')
insert Employee values ('MJP25939M', 'Maria', 'J', 'Pontes', 5, 246, '1756', '03/01/19')
insert Employee values ('JYL26161F', 'Janine', 'Y', 'Labrune', 5, 172, '9901', '05/26/21')
insert Employee values ('CFH28514M', 'Carlos', 'F', 'Hernadez', 5, 211, '9999', '04/21/19')
insert Employee values ('VPA30890F', 'Victoria', 'P', 'Ashworth', 6, 140, '0877', '09/13/20')
insert Employee values ('L-B31947F', 'Lesley',NULL, 'Brown', 7, 120, '0877', '02/13/21')
insert Employee values ('ARD36773F', 'Anabela', 'R', 'Domingues', 8, 100, '0877', '01/27/23')
insert Employee values ('M-R38834F', 'Martine',NULL, 'Rance', 9, 75, '0877', '02/05/22')
insert Employee values ('PHF38899M', 'Peter', 'H', 'Franken', 10, 75, '0877', '05/17/22')
insert Employee values ('DBT39435M', 'Daniel', 'B', 'Tonini', 11, 75, '0877', '01/01/20')
insert Employee values ('H-B39728F', 'Helen',NULL, 'Bennett', 12, 35, '0877', '09/21/19')
insert Employee values ('PMA42628M', 'Paolo', 'M', 'Accorti', 13, 35, '0877', '08/27/22')
insert Employee values ('ENL44273F', 'Elizabeth', 'N', 'Lincoln', 14, 35, '0877', '07/24/20')

GO

insert Employee values ('MGK44605M', 'Matti', 'G', 'Karttunen', 6, 220, '0736', '05/01/24')
insert Employee values ('PDI47470M', 'Palle', 'D', 'Ibsen', 7, 195, '0736', '05/09/23')
insert Employee values ('MMS49649F', 'Mary', 'M', 'Saveley', 8, 175, '0736', '06/29/23')
insert Employee values ('GHT50241M', 'Gary', 'H', 'Thomas', 9, 170, '0736', '08/09/18')
insert Employee values ('MFS52347M', 'Martin', 'F', 'Sommer', 10, 165, '0736', '04/13/20')
insert Employee values ('R-M53550M', 'Roland', NULL, 'Mendel', 11, 150, '0736', '09/05/21')
insert Employee values ('HAS54740M', 'Howard', 'A', 'Snyder', 12, 100, '0736', '11/19/18')
insert Employee values ('TPO55093M', 'Timothy', 'P', 'O''Rourke', 13, 100, '0736', '06/19/18')
insert Employee values ('KFJ64308F', 'Karin', 'F', 'Josephs', 14, 100, '0736', '10/17/22')
insert Employee values ('DWR65030M', 'Diego', 'W', 'Roel', 6, 192, '1389', '12/16/21')
insert Employee values ('M-L67958F', 'Maria', NULL, 'Larsson', 7, 135, '1389', '03/27/22')
insert Employee values ('PSP68661F', 'Paula', 'S', 'Parente', 8, 125, '1389', '01/19/24')
insert Employee values ('MAS70474F', 'Margaret', 'A', 'Smith', 9, 78, '1389', '09/29/18')
insert Employee values ('A-C71970F', 'Aria', NULL, 'Cruz', 10, 87, '1389', '10/26/21')
insert Employee values ('MAP77183M', 'Miguel', 'A', 'Paolino', 11, 112, '1389', '12/07/22')
insert Employee values ('Y-L77953M', 'Yoshi', NULL, 'Latimer', 12, 32, '1389', '06/11/19')
insert Employee values ('CGS88322F', 'Carine', 'G', 'Schmitt', 13, 64, '1389', '07/07/22')
insert Employee values ('PSA89086M', 'Pedro', 'S', 'Afonso', 14, 89, '1389', '12/24/20')
insert Employee values ('A-R89858F', 'Annette', NULL, 'Roulet', 6, 152, '9999', '02/21/20')
insert Employee values ('HAN90777M', 'Helvetius', 'A', 'Nagy', 7, 120, '9999', '03/19/23')
insert Employee values ('M-P91209M', 'Manuel',NULL, 'Pereira', 8, 101, '9999', '01/09/19')
insert Employee values ('KJJ92907F', 'Karla', 'J', 'Jablonski', 9, 170, '9999', '03/11/24')
insert Employee values ('POK93028M', 'Pirkko', 'O', 'Koskitalo', 10, 80, '9999', '11/29/23')
insert Employee values ('PCM98509F', 'Patricia', 'C', 'McKenna', 11, 150, '9999', '08/01/19')
GO

raiserror('Now at the create index section ....',0,1) with nowait

GO

CREATE CLUSTERED INDEX Employee_ind ON Employee(LastName, FirstName, MiddleInitial)

GO

CREATE NONCLUSTERED INDEX aunmind ON Authors (LastName, FirstName)
GO
CREATE NONCLUSTERED INDEX Titleidind ON Sales (Title_id)
GO
CREATE NONCLUSTERED INDEX Titleind ON Titles (Title)
GO
CREATE NONCLUSTERED INDEX auidind ON TitleAuthor (Authors_id)
GO
CREATE NONCLUSTERED INDEX Titleidind ON TitleAuthor (Title_id)
GO
CREATE NONCLUSTERED INDEX Titleidind ON RoySched (Title_id)
GO

raiserror('Now at the create view section ....',0,1)

GO

CREATE VIEW Titleview
AS
select Title, Author_Order, LastName, Price, YTD_Sales, Pub_id
from Authors, Titles, TitleAuthor
where Authors.Authors_id = TitleAuthor.Authors_id
   AND Titles.Title_id = TitleAuthor.Title_id

GO

raiserror('Now at the create procedure section ....',0,1)

GO

CREATE PROCEDURE byRoyalty @percentage int
AS
select Authors_id from TitleAuthor
where TitleAuthor.RoyalTyper = @percentage

GO

CREATE PROCEDURE reptq1 AS
select 
	case when grouping(Pub_id) = 1 then 'ALL' else Pub_id end as Pub_id, 
	avg(Price) as avg_Price
from Titles
where Price is NOT NULL
group by Pub_id with rollup
order by Pub_id

GO

CREATE PROCEDURE reptq2 AS
select 
	case when grouping(Type) = 1 then 'ALL' else Type end as Type, 
	case when grouping(Pub_id) = 1 then 'ALL' else Pub_id end as Pub_id, 
	avg(YTD_Sales) as avg_YTD_Sales
from Titles
where Pub_id is NOT NULL
group by Pub_id, Type with rollup

GO

CREATE PROCEDURE reptq3 @lolimit money, @hilimit money,
@Type char(12)
AS
select 
	case when grouping(Pub_id) = 1 then 'ALL' else Pub_id end as Pub_id, 
	case when grouping(Type) = 1 then 'ALL' else Type end as Type, 
	count(Title_id) as cnt
from Titles
where Price >@lolimit AND Price <@hilimit AND Type = @Type OR Type LIKE '%cook%'
group by Pub_id, Type with rollup

GO

UPDATE STATISTICS Publishers
UPDATE STATISTICS Employee
UPDATE STATISTICS Jobs
UPDATE STATISTICS Pub_Info
UPDATE STATISTICS Titles
UPDATE STATISTICS Authors
UPDATE STATISTICS TitleAuthor
UPDATE STATISTICS Sales
UPDATE STATISTICS RoySched
UPDATE STATISTICS Stores
UPDATE STATISTICS Discounts

GO

CHECKPOINT

GO

USE master

GO

CHECKPOINT

GO

declare @dttm varchar(55)
select  @dttm=convert(varchar,getdate(),113)
raiserror('Ending InstPubs.SQL at %s ....',1,1,@dttm) with nowait

GO





-- -
