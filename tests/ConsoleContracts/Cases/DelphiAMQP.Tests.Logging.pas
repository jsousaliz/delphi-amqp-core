unit DelphiAMQP.Tests.Logging;

interface

procedure RunLoggingTests;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Logging,
  DelphiAMQP.Tests.Assertions;

procedure TestInMemoryLogger;
var
  LLogger: TAMQPInMemoryLogger;
  LEvents: TAMQPLogEventArray;
  LError: Exception;
begin
  LLogger := TAMQPInMemoryLogger.Create;
  LLogger.Log(Default(TAMQPLogEvent));
  TAMQPLogger.Info(LLogger, lekQueue, 'connection-id', 1, 'queue declared', AMQP_LOG_QUEUE_DECLARE);
  TAMQPLogger.Warning(
    LLogger,
    lekConnection,
    'connection-id',
    0,
    'connection warning',
    AMQP_LOG_CONNECTION_CLOSE_ERROR,
    'EWarning',
    12);

  LError := EAMQPProtocolError.Create('protocol failure');
  try
    TAMQPLogger.Error(LLogger, lekError, 'connection-id', 1, AMQP_LOG_CONNECTION_ERROR, LError);
  finally
    LError.Free;
  end;

  TAMQPLogger.Debug(nil, lekQueue, '', 0, 'ignored', 'ignored');

  AssertEquals(4, LLogger.Count, 'In-memory logger count mismatch.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_QUEUE_DECLARE), 'In-memory logger operation missing.');
  AssertTrue(not LLogger.ContainsOperation('missing.operation'), 'In-memory logger false positive.');
  LEvents := LLogger.Events;
  AssertEquals(4, Length(LEvents), 'In-memory logger events snapshot mismatch.');
  AssertTrue(LEvents[1].Level = llInfo, 'Logger info level mismatch.');
  AssertTrue(LEvents[1].Kind = lekQueue, 'Logger kind mismatch.');
  AssertEquals('connection-id', LEvents[1].ConnectionId, 'Logger connection id mismatch.');
  AssertEquals(1, LEvents[1].ChannelId, 'Logger channel id mismatch.');
  AssertEquals(12, LEvents[2].DurationMS, 'Logger duration mismatch.');
  AssertEquals('EAMQPProtocolError', LEvents[3].ErrorClass, 'Logger error class mismatch.');
end;

procedure RunLoggingTests;
begin
  TestInMemoryLogger;
end;

end.
