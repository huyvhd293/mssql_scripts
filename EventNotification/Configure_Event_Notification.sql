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
with activation (status=on, procedure_name = spHandleBlockProcessReport,
max_queue_readers = 1, 
execute as owner) 
GO