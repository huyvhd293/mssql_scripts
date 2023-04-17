# Listing all triggers in all databases in SQL Intance
SET NOCOUNT ON
DECLARE @AllTables TABLE (CompleteTableName NVARCHAR(4000))
INSERT INTO @AllTables (CompleteTableName)
EXEC sp_msforeachdb 'select @@SERVERNAME+''.''+''?''+''.''+s.name+''.''+t.name from [?].sys.tables t inner join sys.schemas s on t.schema_id=s.schema_id'
SET NOCOUNT OFF
