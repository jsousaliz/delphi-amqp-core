unit DelphiAMQP.Logging;

interface

uses
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types;

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

uses
  System.SysUtils;

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

class function TAMQPLogger.Null: IAMQPLogger;
begin
  Result := TAMQPNullLogger.Create;
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
