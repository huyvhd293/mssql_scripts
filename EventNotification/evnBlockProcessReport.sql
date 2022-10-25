USE [DBA_Management]
GO

CREATE PROCEDURE evnBlockProcessReport
AS
	BEGIN
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
            @Duratiion BIGINT,
            @PostTime VARCHAR;

	WHILE @Attempt < 3
	BEGIN
		BEGIN TRY
			BEGIN TRAN
			
			WAITFOR
			(
				RECEIVE TOP(1) [validation], [message_body] FROM QueueBlockProcessReport
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
                        @Duratiion = @Message.value(N'(/EVENT_INSTANCE/Duration)[1]','BIGINT');
                INSERT INTO [Tracking].[EVN_BlockProcessReports]([DatabaseID], TransactionID, EventSequence, ObjectID, IndexID, TextData, Duration, PostTime)
								VALUES(@DatabaseID,@TransactionID, @EventSequence, @ObjectID, @IndexID, @TextData, @Duratiion, @PostTime);
                -- Checking value of variable
                --PRINT @DatabaseID;
                --PRINT @TransactionID;
                --PRINT @EventSequence;
                --PRINT @ObjectID;
                --PRINT @IndexID;
                --PRINT @Duratiion;
                COMMIT TRAN;
			END
			BREAK;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
			BEGIN
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
	END
END
GO