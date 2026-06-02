unit DelphiAMQP.Message;

interface

uses
  System.SysUtils,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types;

type
  TAMQPMessage = class(TInterfacedObject, IAMQPMessage)
  private
    FBody: TBytes;
    FRoutingKey: string;
    FExchange: string;
    FDeliveryTag: UInt64;
    FRedelivered: Boolean;
    FProperties: TAMQPBasicProperties;
    function GetBody: TBytes;
    function GetRoutingKey: string;
    function GetExchange: string;
    function GetDeliveryTag: UInt64;
    function GetRedelivered: Boolean;
    function GetProperties: TAMQPBasicProperties;
  public
    class function FromBytes(const ABody: TBytes): IAMQPMessage; static;
    class function FromText(const AText: string; const AEncoding: TEncoding = nil): IAMQPMessage; static;
    class function FromDelivery(
      const ABody: TBytes;
      const AExchange: string;
      const ARoutingKey: string;
      const ADeliveryTag: UInt64;
      const ARedelivered: Boolean;
      const AProperties: TAMQPBasicProperties): IAMQPMessage; static;
    constructor Create(
      const ABody: TBytes;
      const AExchange: string = '';
      const ARoutingKey: string = '';
      const ADeliveryTag: UInt64 = 0;
      const ARedelivered: Boolean = False);

    function AsText(const AEncoding: TEncoding = nil): string;
  end;

implementation

constructor TAMQPMessage.Create(
  const ABody: TBytes;
  const AExchange: string;
  const ARoutingKey: string;
  const ADeliveryTag: UInt64;
  const ARedelivered: Boolean);
begin
  inherited Create;
  FBody := Copy(ABody);
  FExchange := AExchange;
  FRoutingKey := ARoutingKey;
  FDeliveryTag := ADeliveryTag;
  FRedelivered := ARedelivered;
end;

function TAMQPMessage.AsText(const AEncoding: TEncoding): string;
var
  LEncoding: TEncoding;
begin
  LEncoding := AEncoding;
  if LEncoding = nil then
    LEncoding := TEncoding.UTF8;
  Result := LEncoding.GetString(FBody);
end;

class function TAMQPMessage.FromBytes(const ABody: TBytes): IAMQPMessage;
begin
  Result := TAMQPMessage.Create(ABody);
end;

class function TAMQPMessage.FromDelivery(
  const ABody: TBytes;
  const AExchange: string;
  const ARoutingKey: string;
  const ADeliveryTag: UInt64;
  const ARedelivered: Boolean;
  const AProperties: TAMQPBasicProperties): IAMQPMessage;
var
  LMessage: TAMQPMessage;
begin
  LMessage := TAMQPMessage.Create(ABody, AExchange, ARoutingKey, ADeliveryTag, ARedelivered);
  LMessage.FProperties := AProperties;
  Result := LMessage;
end;

class function TAMQPMessage.FromText(const AText: string; const AEncoding: TEncoding): IAMQPMessage;
var
  LEncoding: TEncoding;
begin
  LEncoding := AEncoding;
  if LEncoding = nil then
    LEncoding := TEncoding.UTF8;
  Result := TAMQPMessage.Create(LEncoding.GetBytes(AText));
end;

function TAMQPMessage.GetBody: TBytes;
begin
  Result := Copy(FBody);
end;

function TAMQPMessage.GetDeliveryTag: UInt64;
begin
  Result := FDeliveryTag;
end;

function TAMQPMessage.GetExchange: string;
begin
  Result := FExchange;
end;

function TAMQPMessage.GetProperties: TAMQPBasicProperties;
begin
  Result := FProperties;
end;

function TAMQPMessage.GetRedelivered: Boolean;
begin
  Result := FRedelivered;
end;

function TAMQPMessage.GetRoutingKey: string;
begin
  Result := FRoutingKey;
end;

end.
