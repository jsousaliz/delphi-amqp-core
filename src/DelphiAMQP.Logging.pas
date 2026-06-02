unit DelphiAMQP.Logging;

interface

uses
  System.SysUtils,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types;

const
  AMQP_LOG_TCP_CONNECT = 'tcp.connect';
  AMQP_LOG_TCP_CONNECTED = 'tcp.connected';
  AMQP_LOG_PROTOCOL_HEADER = 'protocol.header';
  AMQP_LOG_CONNECTION_START = 'connection.start';
  AMQP_LOG_CONNECTION_START_OK = 'connection.start-ok';
  AMQP_LOG_CONNECTION_TUNE_OK = 'connection.tune-ok';
  AMQP_LOG_CONNECTION_OPEN = 'connection.open';
  AMQP_LOG_CONNECTION_CLOSE = 'connection.close';
  AMQP_LOG_CONNECTION_ERROR = 'connection.error';
  AMQP_LOG_CONNECTION_CLOSE_ERROR = 'connection.close-error';
  AMQP_LOG_CHANNEL_OPEN = 'channel.open';
  AMQP_LOG_CHANNEL_CLOSE = 'channel.close';
  AMQP_LOG_QUEUE_DECLARE = 'queue.declare';
  AMQP_LOG_QUEUE_DELETE = 'queue.delete';
  AMQP_LOG_QUEUE_PURGE = 'queue.purge';
  AMQP_LOG_BASIC_PUBLISH = 'basic.publish';
  AMQP_LOG_BASIC_CONSUME = 'basic.consume';
  AMQP_LOG_BASIC_ACK = 'basic.ack';
  AMQP_LOG_BASIC_NACK = 'basic.nack';
  AMQP_LOG_BASIC_REJECT = 'basic.reject';
  AMQP_LOG_BASIC_CANCEL_ERROR = 'basic.cancel-error';
  AMQP_LOG_CONSUMER_START = 'consumer.start';
  AMQP_LOG_CONSUMER_STOP = 'consumer.stop';
  AMQP_LOG_CONSUMER_ERROR = 'consumer.error';
  AMQP_LOG_HEARTBEAT_RECEIVE = 'heartbeat.receive';

type
  TAMQPLogEventArray = TArray<TAMQPLogEvent>;

  TAMQPNullLogger = class(TInterfacedObject, IAMQPLogger)
  public
    procedure Log(const AEvent: TAMQPLogEvent);
  end;

  TAMQPInMemoryLogger = class(TInterfacedObject, IAMQPLogger)
  private
    FLock: TObject;
    FEvents: TAMQPLogEventArray;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AEvent: TAMQPLogEvent);
    function Events: TAMQPLogEventArray;
    function Count: Integer;
    function ContainsOperation(const AOperation: string): Boolean;
  end;

  TAMQPLogger = class
  public
    class function Null: IAMQPLogger; static;
    class procedure Trace(
      const ALogger: IAMQPLogger;
      const AKind: TAMQPLogEventKind;
      const AConnectionId: string;
      const AChannelId: UInt16;
      const AMessage: string;
      const AOperation: string;
      const ADurationMS: UInt64 = 0); static;
    class procedure Debug(
      const ALogger: IAMQPLogger;
      const AKind: TAMQPLogEventKind;
      const AConnectionId: string;
      const AChannelId: UInt16;
      const AMessage: string;
      const AOperation: string;
      const ADurationMS: UInt64 = 0); static;
    class procedure Info(
      const ALogger: IAMQPLogger;
      const AKind: TAMQPLogEventKind;
      const AConnectionId: string;
      const AChannelId: UInt16;
      const AMessage: string;
      const AOperation: string;
      const ADurationMS: UInt64 = 0); static;
    class procedure Warning(
      const ALogger: IAMQPLogger;
      const AKind: TAMQPLogEventKind;
      const AConnectionId: string;
      const AChannelId: UInt16;
      const AMessage: string;
      const AOperation: string;
      const AErrorClass: string = '';
      const ADurationMS: UInt64 = 0); static;
    class procedure Error(
      const ALogger: IAMQPLogger;
      const AKind: TAMQPLogEventKind;
      const AConnectionId: string;
      const AChannelId: UInt16;
      const AOperation: string;
      const AException: Exception); static;
    class procedure Emit(
      const ALogger: IAMQPLogger;
      const ALevel: TAMQPLogLevel;
      const AKind: TAMQPLogEventKind;
      const AMessage: string;
      const AConnectionId: string = '';
      const AChannelId: UInt16 = 0;
      const AErrorClass: string = '';
      const AOperation: string = '';
      const ADurationMS: UInt64 = 0); static;
  end;

implementation

class procedure TAMQPLogger.Debug(
  const ALogger: IAMQPLogger;
  const AKind: TAMQPLogEventKind;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AMessage: string;
  const AOperation: string;
  const ADurationMS: UInt64);
begin
  Emit(ALogger, llDebug, AKind, AMessage, AConnectionId, AChannelId, '', AOperation, ADurationMS);
end;

class procedure TAMQPLogger.Emit(
  const ALogger: IAMQPLogger;
  const ALevel: TAMQPLogLevel;
  const AKind: TAMQPLogEventKind;
  const AMessage: string;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AErrorClass: string;
  const AOperation: string;
  const ADurationMS: UInt64);
var
  LEvent: TAMQPLogEvent;
begin
  if ALogger = nil then
    Exit;

  LEvent.Timestamp := Now;
  LEvent.Level := ALevel;
  LEvent.Kind := AKind;
  LEvent.Message := AMessage;
  LEvent.Operation := AOperation;
  LEvent.ConnectionId := AConnectionId;
  LEvent.ChannelId := AChannelId;
  LEvent.ErrorClass := AErrorClass;
  LEvent.DurationMS := ADurationMS;
  ALogger.Log(LEvent);
end;

class procedure TAMQPLogger.Error(
  const ALogger: IAMQPLogger;
  const AKind: TAMQPLogEventKind;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AOperation: string;
  const AException: Exception);
begin
  Emit(
    ALogger,
    llError,
    AKind,
    AException.Message,
    AConnectionId,
    AChannelId,
    AException.ClassName,
    AOperation);
end;

class procedure TAMQPLogger.Info(
  const ALogger: IAMQPLogger;
  const AKind: TAMQPLogEventKind;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AMessage: string;
  const AOperation: string;
  const ADurationMS: UInt64);
begin
  Emit(
    ALogger,
    llInfo,
    AKind,
    AMessage,
    AConnectionId,
    AChannelId,
    '',
    AOperation,
    ADurationMS);
end;

class function TAMQPLogger.Null: IAMQPLogger;
begin
  Result := TAMQPNullLogger.Create;
end;

class procedure TAMQPLogger.Trace(
  const ALogger: IAMQPLogger;
  const AKind: TAMQPLogEventKind;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AMessage: string;
  const AOperation: string;
  const ADurationMS: UInt64);
begin
  Emit(
    ALogger,
    llTrace,
    AKind,
    AMessage,
    AConnectionId,
    AChannelId,
    '',
    AOperation,
    ADurationMS);
end;

class procedure TAMQPLogger.Warning(
  const ALogger: IAMQPLogger;
  const AKind: TAMQPLogEventKind;
  const AConnectionId: string;
  const AChannelId: UInt16;
  const AMessage: string;
  const AOperation: string;
  const AErrorClass: string;
  const ADurationMS: UInt64);
begin
  Emit(
    ALogger,
    llWarning,
    AKind,
    AMessage,
    AConnectionId,
    AChannelId,
    AErrorClass,
    AOperation,
    ADurationMS);
end;

procedure TAMQPNullLogger.Log(const AEvent: TAMQPLogEvent);
begin
end;

function TAMQPInMemoryLogger.ContainsOperation(const AOperation: string): Boolean;
var
  LEvent: TAMQPLogEvent;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    for LEvent in FEvents do
      if SameText(LEvent.Operation, AOperation) then
        Exit(True);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TAMQPInMemoryLogger.Count: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := Length(FEvents);
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TAMQPInMemoryLogger.Create;
begin
  inherited Create;
  FLock := TObject.Create;
end;

destructor TAMQPInMemoryLogger.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TAMQPInMemoryLogger.Events: TAMQPLogEventArray;
begin
  TMonitor.Enter(FLock);
  try
    Result := Copy(FEvents);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TAMQPInMemoryLogger.Log(const AEvent: TAMQPLogEvent);
var
  LIndex: Integer;
begin
  TMonitor.Enter(FLock);
  try
    LIndex := Length(FEvents);
    SetLength(FEvents, LIndex + 1);
    FEvents[LIndex] := AEvent;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
