USE DBNAME;
GO

-- Enable Service Broker 
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'DBNAME' AND is_broker_enabled = 0) 
	ALTER DATABASE DBNAME SET ENABLE_BROKER; 
GO

-- Create QUEUE QueueBlockProcessReport
IF NOT EXISTS (SELECT 1 FROM sys.service_queues WHERE name='QueueBlockProcessReport')
CREATE QUEUE QueueBlockProcessReport;
GO

-- Create SERVICE svcBlockProcessReport
CREATE SERVICE svcBlockProcessReport ON QUEUE QueueBlockProcessReport
(
	[http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]
);
GO

-- Create ROUTE RouteBlockProcessReport
CREATE ROUTE RouteBlockProcessReport  
WITH SERVICE_NAME = 'svcBlockProcessReport',
ADDRESS = 'LOCAL';  
GO

-- Create EVENT NOTIFICATION evnBlockProcessReport
CREATE EVENT NOTIFICATION evnBlockProcessReport
ON SERVER
FOR BLOCKED_PROCESS_REPORT
TO SERVICE 'svcBlockProcessReport', 'current database'
GO

-- Adding Procedure
ALTER QUEUE evnBlockProcessReport 
with activation (status=on, procedure_name = evnBlockProcessReport,
max_queue_readers = 1, 
execute as owner) 
GO

-- Create table
CREATE TABLE [DBA_Management].[Tracking].[EVN_BlockProcessReports](
    RowID int IDENTITY(1,1) NOT FOR REPLICATION PRIMARY KEY NOT NULL,
    DatabaseID int NULL,
    TransactionID bigint NULL,
    EventSequence int NULL,
    ObjectID int NULL,
    IndexID int NULL,
    TextData xml NULL,
    Duration bigint NULL,
    PostTime varchar NULL,
    CollectionDate datetime NULL
);

ALTER TABLE [Tracking].[EVN_BlockProcessReports] ADD  DEFAULT (getdate()) FOR [CollectionDate]
GO

