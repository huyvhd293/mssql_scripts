USE [DBA_Management]
GO

/****** Object:  StoredProcedure [Tracking].[sp_BlockProcessReport]    Script Date: 11/4/2022 11:15:57 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [Tracking].[usp_BlockProcessReport]
WITH EXECUTE AS OWNER
AS
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	BEGIN
		DECLARE @temp AS TABLE
		(
			RowID INT
		);
		DECLARE @RecordID INT;
		DECLARE @Messages TABLE (
			[validation] nvarchar(2) NOT NULL,
			[message_body] VARBINARY(MAX)
		);
		DECLARE @Message XML, @Attempt TINYINT = 0;
		DECLARE @DatabaseID INT,
				@TransactionID BIGINT,
				@EventSequence INT,
				@ObjectID INT,
				@IndexID INT,
				@TextData xml,
				@Duration BIGINT,
				@PostTime DATETIME;
		WHILE @Attempt < 3
		BEGIN
			BEGIN TRY
				BEGIN TRAN
			
					WAITFOR
					(
						RECEIVE TOP(1) [validation], [message_body] FROM [dbo].[QueueBlockProcessReport]
						INTO @Messages
					), TIMEOUT 5000;
				
					SELECT @Message = CASE WHEN msg.[validation] = N'X' THEN CONVERT(xml, msg.message_body) ELSE NULL END
					FROM @Messages msg;
				
					IF @Message IS NOT NULL
					BEGIN
						SELECT  @DatabaseID = @Message.value(N'(/EVENT_INSTANCE/DatabaseID)[1]', 'INT'),
								@TransactionID = @Message.value(N'(/EVENT_INSTANCE/TransactionID)[1]','BIGINT'),
								@EventSequence = @Message.value(N'(/EVENT_INSTANCE/EventSequence)[1]','INT'),
								@ObjectID = @Message.value(N'(/EVENT_INSTANCE/ObjectID)[1]','INT'),
								@IndexID = @Message.value(N'(/EVENT_INSTANCE/IndexID)[1]','INT'),
								@TextData = @Message,
								@Duration = @Message.value(N'(/EVENT_INSTANCE/Duration)[1]','BIGINT'),
								@PostTime = @Message.value(N'(/EVENT_INSTANCE/PostTime)[1]','DATETIME')
						INSERT INTO [Tracking].[BlockProcessReports]([DatabaseID], TransactionID, EventSequence, ObjectID, IndexID, TextData, Duration, PostTime)
						OUTPUT inserted.RowID INTO @temp(RowID) VALUES(@DatabaseID,@TransactionID, @EventSequence, @ObjectID, @IndexID, @TextData, @Duration, @PostTime);
						-- Checking value of variable
						--PRINT @DatabaseID;
						--PRINT @TransactionID;
						--PRINT @EventSequence;
						--PRINT @ObjectID;
						--PRINT @IndexID;
						--PRINT @Duration;
						--SELECT @RowID = RowID FROM [Tracking].[BlockProcessReports];
						SELECT @RecordID = RowID FROM @temp;
						PRINT @RecordID
						EXEC [DBA_Management].[Tracking].[usp_ProcessBlockedProcessReport] @RecordID;
					END
				COMMIT TRAN;
				BREAK;
			END TRY
			BEGIN CATCH
				IF @@TRANCOUNT > 0
				BEGIN
					INSERT INTO [DBA_Management].Tracking.TrackObjectErrors(ObjectName, ErrorNumber, ErrorMessage)
		VALUES ('SP: DBA_Management.Tracking.usp_BlockProcessReport', ERROR_NUMBER(), ERROR_MESSAGE());
					ROLLBACK TRAN;
				END
				SET @Attempt = @Attempt + 1;
			END CATCH
		END
		IF @Attempt = 3
		BEGIN
			ALTER QUEUE QueueBlockProcessReport
			WITH ACTIVATION (
				STATUS = OFF
			);

            SELECT @AlertMailProfile = KeyValue
		    FROM DBA_Management.dbo.RefValues
		    Where KeyName1 = 'AlertMailProfile';

            SELECT @AlertMailRecipients = KeyValue
            FROM DBA_Management.dbo.RefValues
            Where KeyName1 = 'AlertMailRecipients';

            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @AlertMailProfile, 
                @recipients = @AlertMailRecipients, 
                @body = 'Queue Activation for Block Process Report is disabled after 3 consecutive failed attempts. Please check DBA_Management.Tracking.TrackObjectErrors for further information!',
                @subject = 'Fail to receive Block Process Report',
                @importance = 'High';
		END
END
GO