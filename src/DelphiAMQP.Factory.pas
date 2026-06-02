unit DelphiAMQP.Factory;

interface

uses
  DelphiAMQP.Interfaces;

type
  TAMQPConnectionFactory = class(TInterfacedObject, IAMQPConnectionFactory)
  private
    FLogger: IAMQPLogger;
  public
    constructor Create(const ALogger: IAMQPLogger = nil);
    function CreateConnection(const AOptions: IAMQPConnectionOptions): IAMQPConnection;
  end;

implementation

uses
  DelphiAMQP.Connection,
  DelphiAMQP.Logging;

constructor TAMQPConnectionFactory.Create(const ALogger: IAMQPLogger);
begin
  inherited Create;
  if ALogger = nil then
    FLogger := TAMQPLogger.Null
  else
    FLogger := ALogger;
end;

function TAMQPConnectionFactory.CreateConnection(const AOptions: IAMQPConnectionOptions): IAMQPConnection;
begin
  Result := TAMQPConnection.Create(AOptions, FLogger);
end;

end.
