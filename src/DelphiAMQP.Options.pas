unit DelphiAMQP.Options;

interface

uses
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types;

type
  TAMQPConnectionOptions = class(TInterfacedObject, IAMQPConnectionOptions)
  private
    FHost: string;
    FPort: UInt16;
    FVirtualHost: string;
    FUserName: string;
    FPassword: string;
    FHeartbeatSeconds: UInt16;
    FConnectionTimeoutMS: Cardinal;
    FUseTLS: Boolean;
    FConsumerDispatchMode: TAMQPConsumerDispatchMode;
    function GetHost: string;
    function GetPort: UInt16;
    function GetVirtualHost: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetHeartbeatSeconds: UInt16;
    function GetConnectionTimeoutMS: Cardinal;
    function GetUseTLS: Boolean;
    function GetConsumerDispatchMode: TAMQPConsumerDispatchMode;

    function SetHost(const AValue: string): IAMQPConnectionOptions;
    function SetPort(const AValue: UInt16): IAMQPConnectionOptions;
    function SetVirtualHost(const AValue: string): IAMQPConnectionOptions;
    function SetUserName(const AValue: string): IAMQPConnectionOptions;
    function SetPassword(const AValue: string): IAMQPConnectionOptions;
    function SetHeartbeatSeconds(const AValue: UInt16): IAMQPConnectionOptions;
    function SetConnectionTimeoutMS(const AValue: Cardinal): IAMQPConnectionOptions;
    function SetUseTLS(const AValue: Boolean): IAMQPConnectionOptions;
    function SetConsumerDispatchMode(const AValue: TAMQPConsumerDispatchMode): IAMQPConnectionOptions;
  public
    class function CreateDefault: IAMQPConnectionOptions; static;
    constructor Create;
  end;

implementation

uses
  System.SysUtils;

constructor TAMQPConnectionOptions.Create;
begin
  inherited Create;
  FHost := 'localhost';
  FPort := 5672;
  FVirtualHost := '/';
  FUserName := 'guest';
  FPassword := 'guest';
  FHeartbeatSeconds := 60;
  FConnectionTimeoutMS := 30000;
  FUseTLS := False;
  FConsumerDispatchMode := cdmWorkerThread;
end;

class function TAMQPConnectionOptions.CreateDefault: IAMQPConnectionOptions;
begin
  Result := TAMQPConnectionOptions.Create;
end;

function TAMQPConnectionOptions.GetConnectionTimeoutMS: Cardinal;
begin
  Result := FConnectionTimeoutMS;
end;

function TAMQPConnectionOptions.GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
begin
  Result := FConsumerDispatchMode;
end;

function TAMQPConnectionOptions.GetHeartbeatSeconds: UInt16;
begin
  Result := FHeartbeatSeconds;
end;

function TAMQPConnectionOptions.GetHost: string;
begin
  Result := FHost;
end;

function TAMQPConnectionOptions.GetPassword: string;
begin
  Result := FPassword;
end;

function TAMQPConnectionOptions.GetPort: UInt16;
begin
  Result := FPort;
end;

function TAMQPConnectionOptions.GetUseTLS: Boolean;
begin
  Result := FUseTLS;
end;

function TAMQPConnectionOptions.GetUserName: string;
begin
  Result := FUserName;
end;

function TAMQPConnectionOptions.GetVirtualHost: string;
begin
  Result := FVirtualHost;
end;

function TAMQPConnectionOptions.SetConnectionTimeoutMS(const AValue: Cardinal): IAMQPConnectionOptions;
begin
  if AValue = 0 then
    raise EAMQPConnectionError.Create('Connection timeout must be greater than zero.');
  FConnectionTimeoutMS := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetConsumerDispatchMode(
  const AValue: TAMQPConsumerDispatchMode): IAMQPConnectionOptions;
begin
  FConsumerDispatchMode := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetHeartbeatSeconds(const AValue: UInt16): IAMQPConnectionOptions;
begin
  FHeartbeatSeconds := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetHost(const AValue: string): IAMQPConnectionOptions;
begin
  if AValue.Trim.IsEmpty then
    raise EAMQPConnectionError.Create('Host must not be empty.');
  FHost := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetPassword(const AValue: string): IAMQPConnectionOptions;
begin
  FPassword := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetPort(const AValue: UInt16): IAMQPConnectionOptions;
begin
  if AValue = 0 then
    raise EAMQPConnectionError.Create('Port must be greater than zero.');
  FPort := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetUseTLS(const AValue: Boolean): IAMQPConnectionOptions;
begin
  FUseTLS := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetUserName(const AValue: string): IAMQPConnectionOptions;
begin
  if AValue.Trim.IsEmpty then
    raise EAMQPConnectionError.Create('User name must not be empty.');
  FUserName := AValue;
  Result := Self;
end;

function TAMQPConnectionOptions.SetVirtualHost(const AValue: string): IAMQPConnectionOptions;
begin
  if AValue.Trim.IsEmpty then
    raise EAMQPConnectionError.Create('Virtual host must not be empty.');
  FVirtualHost := AValue;
  Result := Self;
end;

end.
