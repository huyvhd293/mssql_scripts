USE DBA_Management;
GO

-- Enable Service Broker 
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'USE DBA_Management' AND is_broker_enabled = 0) 
	ALTER DATABASE DBNAME SET ENABLE_BROKER; 
GO

-- Configure Trustworthy
SELECT name, 
    case is_trustworthy_on
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS ON_OFF
FROM sys.databases where name='DBA_Management';
-- ALTER DATABASE [DBA_Management] SET Trustworthy ON;

-- Create QUEUE QueueBlockProcessReport
IF NOT EXISTS (SELECT 1 FROM sys.service_queues WHERE name='QueueBlockProcessReport')
BEGIN
    CREATE QUEUE QueueBlockProcessReport;
END;
GO

-- Create SERVICE svcBlockProcessReport
IF NOT EXISTS (SELECT 1 FROM sys.services WHERE name = 'svcBlockProcessReport')
BEGIN
    CREATE SERVICE svcBlockProcessReport ON QUEUE QueueBlockProcessReport
    (
        [http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]
    );
END;
GO

-- Create ROUTE svcBlockProcessReport
IF NOT EXISTS (SELECT * FROM sys.routes WHERE name = 'svcBlockProcessReport')
BEGIN
    CREATE ROUTE RouteBlockProcessReport WITH SERVICE_NAME = 'svcBlockProcessReport', ADDRESS = 'LOCAL';
END;
GO

-- Create EVENT NOTIFICATION EventBlockProcessReport
IF NOT EXISTS (SELECT 1 FROM sys.server_event_notifications WHERE name = 'EventBlockProcessReport')
BEGIN
    CREATE EVENT NOTIFICATION EventBlockProcessReport ON SERVER FOR BLOCKED_PROCESS_REPORT TO SERVICE 'svcBlockProcessReport', 'current database'
END;
GO

-- Adding Procedure
ALTER QUEUE QueueBlockProcessReport 
with activation (status=ON, procedure_name = [Tracking].[usp_BlockProcessReport],
max_queue_readers = 1, 
execute as owner) 
GO

-- Create table [Tracking].[BlockProcessReports]
CREATE TABLE [DBA_Management].[Tracking].[BlockProcessReports](
    RowID int IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
    DatabaseID int NULL,
    TransactionID bigint NULL,
    EventSequence int NULL,
    ObjectID int NULL,
    IndexID int NULL,
    TextData xml NULL,
    Duration bigint NULL,
    PostTime datetime NULL,
    CollectionDate datetime NULL,
    CONSTRAINT [PK_BlockProcessReports] PRIMARY KEY CLUSTERED([RowID] ASC)
);

ALTER TABLE [DBA_Management].[Tracking].[BlockProcessReports] ADD  DEFAULT (getdate()) FOR [CollectionDate]
GO

-- Create table [Tracking].[BlockingChains]
CREATE TABLE [Tracking].[BlockingChains](
	[ChainID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[SPID] [smallint] NOT NULL,
	[ECID] [smallint] NOT NULL,
	[LastBatchStarted] [datetime] NOT NULL,
	[FirstEventTime] [datetime2](7) NOT NULL,
	[LastEventTime] [datetime2](7) NOT NULL,
	CONSTRAINT [PK_BlockingChains] PRIMARY KEY CLUSTERED ([ChainID] ASC)
);

-- Create table [Tracking].[BlockingDetails]

CREATE TABLE [Tracking].[BlockingDetails](
	[BlockingDetailID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[BlockingInfoID] [int] NOT NULL,
	[Status] [nvarchar](30) NULL,
	[WaitResource] [nvarchar](256) NULL,
	[WaitTime] [bigint] NULL,
	[WaitType] [nvarchar](128) NULL,
	[TransactionName] [nvarchar](128) NULL,
	[LockMode] [nvarchar](128) NULL,
	[InputBuffer] [nvarchar](max) NULL,
	[SQLText] [nvarchar](max) NULL,
	[QueryPlan] [nvarchar](max) NULL,
	[StmtStart] [int] NULL,
	[StmtEnd] [int] NULL,
	[SQLHandle] [varbinary](64) NULL,
	[EventTime] [datetime2](7) NOT NULL,
	[ChainID] [int] NULL,
	[ReportID] [int] NULL,
	[ResourceName] [nvarchar](1000) NULL,
	[IsBlocked] [bit] NULL,
	[Duration] [bigint] NULL,
 CONSTRAINT [PK_BlockingDetails] PRIMARY KEY CLUSTERED 
(
	[BlockingDetailID] ASC
)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
;

-- Create table BlockingInfo
CREATE TABLE [Tracking].[BlockingInfo](
	[BlockingInfoID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[SPID] [smallint] NOT NULL,
	[ECID] [smallint] NOT NULL,
	[LastBatchStarted] [datetime] NOT NULL,
	[FirstEventTime] [datetime2](7) NOT NULL,
	[LastEventTime] [datetime2](7) NOT NULL,
	[AppName] [nvarchar](128) NULL,
	[HostName] [nvarchar](128) NULL,
	[LoginName] [nvarchar](128) NULL,
	[IsolationLevel] [nvarchar](128) NULL,
	[DBName] [nvarchar](128) NULL,
	[EventCount] [int] NULL,
	[ChainID] [int] NOT NULL,
	[BlockingID] [int] NULL,
 CONSTRAINT [PK_BlockingInfo] PRIMARY KEY CLUSTERED ([BlockingInfoID] ASC)
);

-- Create table TrackObjectErrors
CREATE TABLE [Tracking].[TrackObjectErrors](
	[ID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[ObjectName] [nvarchar](256) NULL,
	[ErrorNumber] [int] NULL,
	[ErrorMessage] [nvarchar](4000) NULL,
	[CreatedDate] [smalldatetime] NULL,
 CONSTRAINT [PK_TrackObjectErrors] PRIMARY KEY CLUSTERED ([ID] ASC)
);

ALTER TABLE [Tracking].[TrackObjectErrors] ADD  CONSTRAINT [DF_TrackObjectErrors_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO


