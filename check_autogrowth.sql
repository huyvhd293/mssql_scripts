-- This query is use for checking autogrowth setting of each database in instance
-- Author:  HuyVo
-- Date:    20 Oct 2022
---------------------------------------------------------------------------------------------------------------------------------------
SELECT
S.[name] AS [Logical Name],
S.[file_id] AS [FILE ID],
S.[physical_name] AS [File Name],
CAST(CAST(G.name AS VARBINARY(256)) AS sysname) AS [FileGroup_Name],
CONVERT(VARCHAR(10), (S.[size]*8)) + ' KB' AS [Size],
CASE WHEN S.[max_size]=-1 THEN 'Unlimited' ELSE CONVERT(VARCHAR(10),CONVERT(bigint,S.[max_size])*8) + ' KB' END AS [Max Size],
CASE WHEN S.is_percent_growth=1 THEN CONVERT(VARCHAR(10),S.growth) +'%' ELSE CONVERT(VARCHAR(10),S.growth*8) + 'KB' END AS [Growth],
CASE WHEN S.[type]=0 THEN 'Data Only'
	WHEN S.[type]=1 THEN 'Log Only'
	WHEN S.[type]=2 THEN 'FILESTREAM Only'
	WHEN S.[type]=3 THEN 'Information Purposes Only'
	WHEN S.[type]=4 THEN 'Full-text'
END AS [usage],
DB_NAME(S.database_id) AS [Database Name]
FROM sys.master_files S
LEFT JOIN sys.filegroups AS G ON ((S.type = 2 or S.type = 0) AND (S.drop_lsn IS NULL)) AND (S.data_space_id=G.data_space_id);