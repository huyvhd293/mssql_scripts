CREATE PROCEDURE [Tracking].[GetResourceName]
	@WaitResource NVARCHAR(256),
	@ResourceName NVARCHAR(1000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @DBID INT,
		@FileID BIGINT,
		@PageID BIGINT,
		@ResourceType NVARCHAR(128),
		@ResourceValue NVARCHAR(128),
		@Pos TINYINT,
		@SQLString NVARCHAR(MAX) = '',
		@HobtID BIGINT,
		@ObjectID INT

SET @ResourceType = REPLACE(LEFT(@WaitResource, ISNULL(NULLIF(CHARINDEX(' ', @WaitResource), 0) - 1, 0)), ':', '');

	SET @ResourceValue = STUFF(@WaitResource, 1, CHARINDEX(' ', @WaitResource), '');

	IF @ResourceType = ''
	BEGIN
		SET @ResourceType = 'PAGE';
	END

	IF @ResourceType IN ('PAGE', 'RID')
	BEGIN
		SET @Pos = CHARINDEX(':', @ResourceValue);

		SELECT	@DBID = LEFT(@ResourceValue, @Pos - 1),
				@FileID = SUBSTRING(@ResourceValue, @Pos + 1, CHARINDEX(':', @ResourceValue, @Pos + 1) - @Pos - 1);

		IF @DBID = 0
		BEGIN
			SET @ResourceName = '[tempdb] (maybe, can be ignored)';

			RETURN;
		END

		SET @Pos = CHARINDEX(':', @ResourceValue, @Pos + 1);

		SELECT @PageID = SUBSTRING(@ResourceValue, @Pos + 1, IIF(CHARINDEX(':', @ResourceValue, @Pos + 1) > 0, CHARINDEX(':', @ResourceValue, @Pos + 1) - @Pos - 1, LEN(@ResourceValue)));

		SET @SQLString = 'USE [' + DB_NAME(@DBID) + '];

		DECLARE @ObjectID INT,
				@IndexID INT;
		
		CREATE TABLE #PageHeader (
			ParentObject VARCHAR(1000) NULL,
			Object VARCHAR(4000) NULL,
			Field VARCHAR(1000) NULL,
			ObjectValue VARCHAR(max) NULL
		);
		
		DBCC TRACEON (3604);

		SET NOCOUNT ON;
		
		INSERT INTO #PageHeader(ParentObject, Object, Field, ObjectValue)		
		EXEC (''DBCC PAGE (' + CAST(@DBID AS NVARCHAR(20)) + ', ' + CAST(@FileID AS NVARCHAR(20)) + ', ' + CAST(@PageID AS NVARCHAR(20)) + ', 0) WITH TABLERESULTS;'');
		
		SELECT @ObjectID = ObjectValue
		FROM #PageHeader
		WHERE Field LIKE ''Metadata: ObjectId%'';

		SELECT @IndexID = ObjectValue
		FROM #PageHeader
		WHERE Field LIKE ''Metadata: IndexId%'';
		
		SELECT @ResourceName = ''[' + DB_NAME(@DBID) + '].['' + SCHEMA_NAME(o.schema_id) + ''].['' + o.name + ''] (['' + ISNULL(i.name, ''HEAP'') + ''])''
		FROM sys.objects o WITH(NOLOCK)
			JOIN sys.indexes i WITH(NOLOCK) ON o.object_id = i.object_id
		WHERE o.object_id = @ObjectID
			AND i.index_id = @IndexID;'

		EXEC sp_executesql @SQLString, N'@ResourceName NVARCHAR(1000) OUTPUT', @ResourceName OUTPUT;
	END

	IF @ResourceType IN ('DATABASE', 'FILE')
	BEGIN
		SET @Pos = CHARINDEX(':', @ResourceValue);

		SELECT	@DBID = LEFT(@ResourceValue, @Pos - 1);

		SET @ResourceName = '[' + DB_NAME(@DBID) + ']';
	END

	IF @ResourceType IN ('KEY')
	BEGIN
		SET @Pos = CHARINDEX(':', @ResourceValue);

		SELECT	@DBID = LEFT(@ResourceValue, @Pos - 1),
				@HobtID = SUBSTRING(@ResourceValue, @Pos + 1, CHARINDEX(' ', @ResourceValue, @Pos + 1) - @Pos - 1);

		SET @SQLString = 'USE [' + DB_NAME(@DBID) + '];
		
		SELECT @ResourceName = ''[' + DB_NAME(@DBID) + '].['' + SCHEMA_NAME(o.schema_id) + ''].['' + o.name + ''] (['' + ISNULL(i.name, ''HEAP'') + ''])''
		FROM sys.objects o WITH(NOLOCK)
			JOIN sys.indexes i WITH(NOLOCK) ON o.object_id = i.object_id
			JOIN sys.partitions p WITH(NOLOCK) ON p.object_id = i.object_id AND p.index_id = i.index_id
		WHERE p.hobt_id = ' + CAST(@HobtID AS NVARCHAR(20)) + ';'

		EXEC sp_executesql @SQLString, N'@ResourceName NVARCHAR(1000) OUTPUT', @ResourceName OUTPUT;
	END

	IF @ResourceType IN ('OBJECT')
	BEGIN
		SET @Pos = CHARINDEX(':', @ResourceValue);

		SELECT	@DBID = LEFT(@ResourceValue, @Pos - 1),
				@ObjectID = SUBSTRING(@ResourceValue, @Pos + 1, CHARINDEX(':', @ResourceValue, @Pos + 1) - @Pos - 1);

		SET @SQLString = 'USE [' + DB_NAME(@DBID) + '];
		
		SELECT @ResourceName = ''[' + DB_NAME(@DBID) + '].['' + SCHEMA_NAME(o.schema_id) + ''].['' + o.name + ''] ('' + o.type_desc + '')''
		FROM sys.objects o WITH(NOLOCK)
		WHERE o.object_id = ' + CAST(@ObjectID AS NVARCHAR(20)) + ';'

		EXEC sp_executesql @SQLString, N'@ResourceName NVARCHAR(1000) OUTPUT', @ResourceName OUTPUT;
	END

	IF @ResourceType IN ('LOG_MANAGER')
	BEGIN
		SET @ResourceName = 'Log file (Size change)';
	END

	IF @ResourceType IN ('METADATA')
	BEGIN
		SET @Pos = CHARINDEX(' ', @ResourceValue, 15);

		SELECT	@DBID = SUBSTRING(@ResourceValue, 15, @Pos - 15),
				@ResourceName = SUBSTRING(@ResourceValue, @Pos + 1, CHARINDEX('(', @ResourceValue, @Pos + 1) - @Pos - 1);

		SET @ResourceName = '[' + DB_NAME(@DBID) + '] (' + @ResourceName + ')'
	END

	SET NOCOUNT OFF;
END
GO


