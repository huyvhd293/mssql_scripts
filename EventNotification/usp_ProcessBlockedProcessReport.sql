CREATE PROCEDURE [Tracking].[usp_ProcessBlockedProcessReport]
	@RowID INT
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;

	SET QUOTED_IDENTIFIER ON;

	SET XACT_ABORT ON;

	BEGIN TRY

	DECLARE @TextData XML,
			@blocked AS XML,
			@blocking AS XML,
			@innerBody AS XML,
			@PostTime DATETIME2,
			@ReportID INT,
			@ChainID INT,
			@BlockingInfoID_Blocking INT,
			@BlockingInfoID_Blocked INT,
			@SQLServerStartTime DATETIME,
			@BlockingID INT,
			@BlockingDetailID_Blocking INT,
			@BlockingDetailID_Blocked INT,
			@Duration BIGINT,
			@LastDuration BIGINT;

	DECLARE @BlockingSPID SMALLINT,
			@BlockingECID SMALLINT,
			@BlockingLastBatchStarted DATETIME,
			@BlockingAppName NVARCHAR(128),
			@BlockingHostName NVARCHAR(128),
			@BlockingLoginName NVARCHAR(128),
			@BlockingIsolationLevel NVARCHAR(128),
			@BlockingDBName NVARCHAR(128),
			@BlockingStatus NVARCHAR(30),
			@BlockingWaitResource NVARCHAR(256),
			@BlockingWaitTime BIGINT,
			@BlockingInputBuffer NVARCHAR(MAX),
			@BlockingSQLText NVARCHAR(MAX),
			@BlockingSQLHandle VARBINARY(64),
			@BlockingStmtStart INT,
			@BlockingStmtEnd INT,
			@BlockingPlanHandle VARBINARY(64),
			@BlockingQueryPlan NVARCHAR(MAX),
			@BlockingWaitType NVARCHAR(128),
			@BlockingResourceName NVARCHAR(1000);

	DECLARE @BlockedSPID SMALLINT,
			@BlockedECID SMALLINT,
			@BlockedLastBatchStarted DATETIME,
			@BlockedAppName NVARCHAR(128),
			@BlockedHostName NVARCHAR(128),
			@BlockedLoginName NVARCHAR(128),
			@BlockedIsolationLevel NVARCHAR(128),
			@BlockedDBName NVARCHAR(128),
			@BlockedStatus NVARCHAR(30),
			@BlockedWaitResource NVARCHAR(256),
			@BlockedWaitTime BIGINT,
			@BlockedInputBuffer NVARCHAR(MAX),
			@BlockedSQLText NVARCHAR(MAX),
			@BlockedSQLHandle VARBINARY(64),
			@BlockedStmtStart INT,
			@BlockedStmtEnd INT,
			@BlockedTransactionName NVARCHAR(128),
			@BlockedLockMode NVARCHAR(128),
			@BlockedPlanHandle VARBINARY(64),
			@BlockedQueryPlan NVARCHAR(MAX),
			@BlockedWaitType NVARCHAR(128),
			@BlockedResourceName NVARCHAR(1000);

	SELECT @SQLServerStartTime = sqlserver_start_time 
	FROM sys.dm_os_sys_info WITH(NOLOCK);

	SELECT	@TextData = TextData,
			@PostTime = PostTime,
            @ReportID = RowID,
			@Duration = Duration
	FROM [DBA_Management].[Tracking].[BlockProcessReports]
	WHERE RowID = @RowID;

	SET @innerBody = @TextData.query('(/EVENT_INSTANCE/TextData/blocked-process-report/.)[1]');
	SET @blocked = @innerBody.query('(/blocked-process-report/blocked-process/process/.)[1]');
	SET @blocking = @innerBody.query('(/blocked-process-report/blocking-process/process/.)[1]');

	SELECT	@BlockingSPID = ISNULL(NULLIF(xc.value('@spid', 'smallint'), ''), 0),
			@BlockingECID = ISNULL(NULLIF(xc.value('@ecid', 'smallint'), ''), 0),
			@BlockingLastBatchStarted = ISNULL(NULLIF(xc.value('@lastbatchstarted', 'datetime'), ''), @SQLServerStartTime),
			@BlockingAppName = xc.value('@clientapp', 'nvarchar(128)'),
			@BlockingHostName = xc.value('@hostname', 'nvarchar(128)'),
			@BlockingLoginName = xc.value('@loginname', 'nvarchar(128)'),
			@BlockingIsolationLevel = xc.value('@isolationlevel', 'nvarchar(128)'),
			@BlockingDBName = xc.value('@currentdbname', 'nvarchar(128)'),
			@BlockingStatus = xc.value('@status', 'nvarchar(30)'),
			@BlockingWaitResource = TRIM(xc.value('@waitresource', 'nvarchar(256)')),
			@BlockingWaitTime = xc.value('@waittime', 'bigint'),
			@BlockingInputBuffer = xc.value('(/process/inputbuf/.)[1]', 'nvarchar(max)'),
			@BlockingStmtStart = ISNULL(NULLIF(f.value('@stmtstart', 'int'), ''), 0),
			@BlockingStmtEnd = ISNULL(NULLIF(f.value('@stmtend', 'int'), ''), -1),
			@BlockingSQLHandle = CONVERT(VARBINARY(64), f.value('@sqlhandle', 'varchar(max)'), 1)
	FROM @blocking.nodes('/process') AS XT(XC)
		OUTER APPLY xc.nodes('(/process/executionStack/frame/.)[1]') es(f);

	IF ISNULL(@BlockingSPID, 0) = 0
	BEGIN
		SELECT	@BlockingAppName = 'Dummy value due to empty blocking node';
	END

	SELECT @BlockingLoginName = COALESCE(@BlockingLoginName, login_name)
	FROM sys.dm_exec_sessions WITH(NOLOCK)
	WHERE session_id = @BlockingSPID;

	SELECT	@BlockingPlanHandle = plan_handle,
			@BlockingWaitType = wait_type
	FROM sys.dm_exec_requests WITH(NOLOCK)
	WHERE session_id = @BlockingSPID;

	SELECT @BlockingSQLText = SUBSTRING(text, @BlockingStmtStart / 2 + 1, (CASE @BlockingStmtEnd WHEN -1 THEN DATALENGTH(text) ELSE @BlockingStmtEnd END - @BlockingStmtStart) / 2 + 1)
	FROM sys.dm_exec_sql_text(@BlockingSQLHandle);

	SELECT @BlockingQueryPlan = query_plan
	FROM sys.dm_exec_text_query_plan(@BlockingPlanHandle, @BlockingStmtStart, @BlockingStmtEnd);

	IF @BlockingWaitResource IS NOT NULL
	BEGIN
		EXEC [DBA_Management].Tracking.GetResourceName @BlockingWaitResource, @BlockingResourceName OUTPUT;
	END

	SELECT	@BlockedSPID = xc.value('@spid', 'smallint'),
			@BlockedECID = xc.value('@ecid', 'smallint'),
			@BlockedLastBatchStarted = ISNULL(NULLIF(xc.value('@lastbatchstarted', 'datetime'), ''), @SQLServerStartTime),
			@BlockedAppName = xc.value('@clientapp', 'nvarchar(128)'),
			@BlockedHostName = xc.value('@hostname', 'nvarchar(128)'),
			@BlockedLoginName = xc.value('@loginname', 'nvarchar(128)'),
			@BlockedIsolationLevel = xc.value('@isolationlevel', 'nvarchar(128)'),
			@BlockedDBName = xc.value('@currentdbname', 'nvarchar(128)'),
			@BlockedStatus = xc.value('@status', 'nvarchar(30)'),
			@BlockedWaitResource = TRIM(xc.value('@waitresource', 'nvarchar(256)')),
			@BlockedWaitTime = xc.value('@waittime', 'bigint'),
			@BlockedInputBuffer = xc.value('(/process/inputbuf/.)[1]', 'nvarchar(max)'),
			@BlockedStmtStart = ISNULL(NULLIF(f.value('@stmtstart', 'int'), ''), 0),
			@BlockedStmtEnd = ISNULL(NULLIF(f.value('@stmtend', 'int'), ''), -1),
			@BlockedSQLHandle = CONVERT(VARBINARY(64), f.value('@sqlhandle', 'varchar(max)'), 1),
			@BlockedTransactionName = xc.value('@transactionname', 'nvarchar(128)'),
			@BlockedLockMode = xc.value('@lockMode', 'nvarchar(128)')
	FROM @blocked.nodes('/process') AS XT(XC)
		OUTER APPLY xc.nodes('(/process/executionStack/frame/.)[1]') es(f);

	SELECT @BlockedLoginName = COALESCE(@BlockedLoginName, login_name)
	FROM sys.dm_exec_sessions WITH(NOLOCK)
	WHERE session_id = @BlockedSPID;

	SELECT	@BlockedPlanHandle = plan_handle,
			@BlockedWaitType = wait_type
	FROM sys.dm_exec_requests WITH(NOLOCK)
	WHERE session_id = @BlockedSPID;

	SELECT @BlockedSQLText = SUBSTRING(text, @BlockedStmtStart / 2 + 1, (CASE @BlockedStmtEnd WHEN -1 THEN DATALENGTH(text) ELSE @BlockedStmtEnd END - @BlockedStmtStart) / 2 + 1)
	FROM sys.dm_exec_sql_text(@BlockedSQLHandle);

	SELECT @BlockedQueryPlan = query_plan
	FROM sys.dm_exec_text_query_plan(@BlockedPlanHandle, @BlockedStmtStart, @BlockedStmtEnd);

	IF @BlockedWaitResource IS NOT NULL
	BEGIN
		EXEC [DBA_Management].Tracking.GetResourceName @BlockedWaitResource, @BlockedResourceName OUTPUT;
	END

	IF ISNULL(@BlockingWaitResource, '') = ''
	BEGIN
		SELECT @ChainID = ChainID
		FROM [DBA_Management].Tracking.BlockingChains
		WHERE SPID = @BlockingSPID
			AND ECID = @BlockingECID
			AND LastBatchStarted = @BlockingLastBatchStarted;

		IF @ChainID IS NOT NULL
		BEGIN
			UPDATE [DBA_Management].Tracking.BlockingChains
			SET LastEventTime = @PostTime
			WHERE ChainID = @ChainID;

			SELECT @BlockingInfoID_Blocking = BlockingInfoID
			FROM [DBA_Management].Tracking.BlockingInfo
			WHERE SPID = @BlockingSPID
				AND ECID = @BlockingECID
				AND LastBatchStarted = @BlockingLastBatchStarted
				AND ChainID = @ChainID;

			UPDATE [DBA_Management].Tracking.BlockingInfo
			SET LastEventTime = @PostTime,
				EventCount = EventCount + 1
			WHERE BlockingInfoID = @BlockingInfoID_Blocking;
		END
		ELSE
		BEGIN
			INSERT INTO DBA_Management.Tracking.BlockingChains(SPID, ECID, LastBatchStarted, FirstEventTime, LastEventTime)
			VALUES(@BlockingSPID, @BlockingECID, @BlockingLastBatchStarted, @PostTime, @PostTime);

			SET @ChainID = SCOPE_IDENTITY();

			INSERT INTO [DBA_Management].Tracking.BlockingInfo(SPID, ECID, LastBatchStarted, FirstEventTime, LastEventTime, AppName, HostName, LoginName, IsolationLevel, DBName, EventCount, ChainID, BlockingID)
			VALUES(@BlockingSPID, @BlockingECID, @BlockingLastBatchStarted, @PostTime, @PostTime, @BlockingAppName, @BlockingHostName, @BlockingLoginName, @BlockingIsolationLevel, @BlockingDBName, 1, @ChainID, NULL);

			SET @BlockingInfoID_Blocking = SCOPE_IDENTITY();
		END
	END
	ELSE
	BEGIN
		SELECT TOP 1 @ChainID = ChainID, @BlockingInfoID_Blocking = BlockingInfoID, @BlockingID = BlockingID
		FROM [DBA_Management].Tracking.BlockingInfo
		WHERE SPID = @BlockingSPID
			AND ECID = @BlockingECID
			AND LastBatchStarted = @BlockingLastBatchStarted
		ORDER BY LastEventTime DESC;

		IF @ChainID IS NOT NULL
		BEGIN
			UPDATE [DBA_Management].Tracking.BlockingChains
			SET LastEventTime = @PostTime
			WHERE ChainID = @ChainID
				AND SPID = @BlockingSPID
				AND ECID = @BlockingECID
				AND LastBatchStarted = @BlockingLastBatchStarted
				AND @BlockingID IS NULL;

			UPDATE [DBA_Management].Tracking.BlockingInfo
			SET LastEventTime = @PostTime,
				EventCount = EventCount + 1
			WHERE BlockingInfoID = @BlockingInfoID_Blocking;
		END
		ELSE
		BEGIN
			INSERT INTO DBA_Management.Tracking.BlockingChains(SPID, ECID, LastBatchStarted, FirstEventTime, LastEventTime)
			VALUES(@BlockingSPID, @BlockingECID, @BlockingLastBatchStarted, @PostTime, @PostTime);

			SET @ChainID = SCOPE_IDENTITY();

			INSERT INTO [DBA_Management].Tracking.BlockingInfo(SPID, ECID, LastBatchStarted, FirstEventTime, LastEventTime, AppName, HostName, LoginName, IsolationLevel, DBName, EventCount, ChainID, BlockingID)
			VALUES(@BlockingSPID, @BlockingECID, @BlockingLastBatchStarted, @PostTime, @PostTime, @BlockingAppName, @BlockingHostName, @BlockingLoginName, @BlockingIsolationLevel, @BlockingDBName, 1, @ChainID, NULL);

			SET @BlockingInfoID_Blocking = SCOPE_IDENTITY();
		END
	END

	INSERT INTO [DBA_Management].Tracking.BlockingDetails(BlockingInfoID, Status, WaitResource, WaitTime, TransactionName, LockMode, InputBuffer, SQLText, EventTime, ReportID, WaitType, QueryPlan, StmtStart, StmtEnd, SQLHandle, ChainID, ResourceName, IsBlocked)
	VALUES (@BlockingInfoID_Blocking, @BlockingStatus, @BlockingWaitResource, @BlockingWaitTime, NULL, NULL, @BlockingInputBuffer, @BlockingSQLText, @PostTime, @ReportID, @BlockingWaitType, @BlockingQueryPlan, @BlockingStmtStart, @BlockingStmtEnd, @BlockingSQLHandle, @ChainID, @BlockingResourceName, 0);

	SET @BlockingDetailID_Blocking = SCOPE_IDENTITY();

	SELECT @BlockingInfoID_Blocked = BlockingInfoID
	FROM [DBA_Management].Tracking.BlockingInfo
	WHERE SPID = @BlockedSPID
		AND ECID = @BlockedECID
		AND LastBatchStarted = @BlockedLastBatchStarted
		AND BlockingID = @BlockingInfoID_Blocking
		AND ChainID = @ChainID;

	IF @BlockingInfoID_Blocked IS NOT NULL
	BEGIN
		UPDATE [DBA_Management].Tracking.BlockingInfo
		SET LastEventTime = @PostTime,
			EventCount = EventCount + 1
		WHERE BlockingInfoID = @BlockingInfoID_Blocked; 
	END
	ELSE
	BEGIN
		INSERT INTO [DBA_Management].Tracking.BlockingInfo(SPID, ECID, LastBatchStarted, FirstEventTime, LastEventTime, AppName, HostName, LoginName, IsolationLevel, DBName, EventCount, ChainID, BlockingID)
		VALUES(@BlockedSPID, @BlockedECID, @BlockedLastBatchStarted, @PostTime, @PostTime, @BlockedAppName, @BlockedHostName, @BlockedLoginName, @BlockedIsolationLevel, @BlockedDBName, 1, @ChainID, @BlockingInfoID_Blocking);

		SET @BlockingInfoID_Blocked = SCOPE_IDENTITY();
	END

	INSERT INTO [DBA_Management].Tracking.BlockingDetails(BlockingInfoID, Status, WaitResource, WaitTime, TransactionName, LockMode, InputBuffer, SQLText, EventTime, ReportID, WaitType, QueryPlan, StmtStart, StmtEnd, SQLHandle, ChainID, ResourceName, IsBlocked)
	VALUES (@BlockingInfoID_Blocked, @BlockedStatus, @BlockedWaitResource, @BlockedWaitTime, @BlockedTransactionName, @BlockedLockMode, @BlockedInputBuffer, @BlockedSQLText, @PostTime, @ReportID, @BlockedWaitType, @BlockedQueryPlan, @BlockedStmtStart, @BlockedStmtEnd, @BlockedSQLHandle, @ChainID, @BlockedResourceName, 1);

	SET @BlockingDetailID_Blocked = SCOPE_IDENTITY();

	SELECT TOP (1) @LastDuration = bpr.Duration
	FROM [DBA_Management].Tracking.BlockingDetails bd
		JOIN [DBA_Management].[Tracking].[BlockProcessReports] bpr ON bd.ReportID = bpr.RowID
	WHERE bd.BlockingInfoID = @BlockingInfoID_Blocked
		AND bd.IsBlocked = 1
		AND bd.BlockingDetailID < @BlockingDetailID_Blocked
	ORDER BY bd.BlockingDetailID DESC;

	UPDATE [DBA_Management].Tracking.BlockingDetails
	SET Duration = @Duration - ISNULL(@LastDuration, 0)
	WHERE BlockingDetailID IN (@BlockingDetailID_Blocking, @BlockingDetailID_Blocked);

	END TRY
	BEGIN CATCH

	INSERT INTO [DBA_Management].Tracking.TrackObjectErrors(ObjectName, ErrorNumber, ErrorMessage)
	VALUES ('SP: DBA_Management.Tracking.ups_BlockProcessReports', ERROR_NUMBER(), ERROR_MESSAGE());

	THROW;

	END CATCH
END
GO


