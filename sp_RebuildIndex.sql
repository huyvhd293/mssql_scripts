CREATE PROCEDURE sp_RebuildIndex @Database nvarchar(255)
AS
BEGIN
	DECLARE @cmd nvarchar(255)
	DECLARE @Table nvarchar(255)

	SET @cmd = 'DECLARE TableCursor CURSOR READ_ONLY FOR SELECT ''['' + table_catalog + ''].['' + table_schema + ''].['' +  table_name + '']'' as tableName FROM [' + @Database + '].INFORMATION_SCHEMA.TABLES WHERE table_type = ''BASE TABLE'''
	EXEC (@cmd)
	OPEN TableCursor

	FETCH NEXT FROM TableCursor INTO @Table
	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY   
         SET @cmd = 'ALTER INDEX ALL ON ' + @Table + ' REBUILD' 
         EXEC (@cmd) 
		END TRY
		BEGIN CATCH
			PRINT '---'
			PRINT @cmd
			PRINT ERROR_MESSAGE() 
			PRINT '---'
		END CATCH

		FETCH NEXT FROM TableCursor INTO @Table   
	END;
	CLOSE TableCursor
	DEALLOCATE TableCursor
END;
GO