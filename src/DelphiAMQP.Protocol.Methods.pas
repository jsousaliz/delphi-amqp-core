unit DelphiAMQP.Protocol.Methods;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame;

const
  AMQP_CLASS_CONNECTION = 10;
  AMQP_CLASS_CHANNEL = 20;
  AMQP_CLASS_QUEUE = 50;
  AMQP_CLASS_BASIC = 60;

  AMQP_CONNECTION_START = 10;
  AMQP_CONNECTION_START_OK = 11;
  AMQP_CONNECTION_TUNE = 30;
  AMQP_CONNECTION_TUNE_OK = 31;
  AMQP_CONNECTION_OPEN = 40;
  AMQP_CONNECTION_OPEN_OK = 41;
  AMQP_CONNECTION_CLOSE = 50;
  AMQP_CONNECTION_CLOSE_OK = 51;

  AMQP_CHANNEL_OPEN = 10;
  AMQP_CHANNEL_OPEN_OK = 11;
  AMQP_CHANNEL_CLOSE = 40;
  AMQP_CHANNEL_CLOSE_OK = 41;

  AMQP_QUEUE_DECLARE = 10;
  AMQP_QUEUE_DECLARE_OK = 11;
  AMQP_QUEUE_PURGE = 30;
  AMQP_QUEUE_PURGE_OK = 31;
  AMQP_QUEUE_DELETE = 40;
  AMQP_QUEUE_DELETE_OK = 41;

  AMQP_BASIC_PUBLISH = 40;
  AMQP_BASIC_CONSUME = 20;
  AMQP_BASIC_CONSUME_OK = 21;
  AMQP_BASIC_CANCEL = 30;
  AMQP_BASIC_CANCEL_OK = 31;
  AMQP_BASIC_DELIVER = 60;
  AMQP_BASIC_ACK = 80;
  AMQP_BASIC_REJECT = 90;
  AMQP_BASIC_NACK = 120;

  AMQP_REPLY_SUCCESS = 200;
  AMQP_EMPTY_FIELD_TABLE_SIZE = 0;
  AMQP_FALSE_BIT = 0;
  AMQP_SASL_PLAIN_SEPARATOR = #0;
  AMQP_SASL_MECHANISM_PLAIN = 'PLAIN';
  AMQP_LOCALE_EN_US = 'en_US';
  AMQP_CONNECTION_CLOSE_REPLY_TEXT = 'Goodbye';
  AMQP_CHANNEL_CLOSE_REPLY_TEXT = 'Goodbye';
  AMQP_RESERVED_SHORT_STRING = '';
  AMQP_RESERVED_METHOD_CLASS_ID = 0;
  AMQP_RESERVED_METHOD_ID = 0;
  AMQP_CONTENT_HEADER_WEIGHT = 0;

  AMQP_QUEUE_DECLARE_PASSIVE_BIT = 0;
  AMQP_QUEUE_DECLARE_DURABLE_BIT = 1;
  AMQP_QUEUE_DECLARE_EXCLUSIVE_BIT = 2;
  AMQP_QUEUE_DECLARE_AUTO_DELETE_BIT = 3;
  AMQP_QUEUE_DECLARE_NO_WAIT_BIT = 4;
  AMQP_QUEUE_DELETE_IF_UNUSED_BIT = 0;
  AMQP_QUEUE_DELETE_IF_EMPTY_BIT = 1;
  AMQP_QUEUE_DELETE_NO_WAIT_BIT = 2;
  AMQP_QUEUE_PURGE_NO_WAIT_BIT = 0;
  AMQP_BASIC_PUBLISH_MANDATORY_BIT = 0;
  AMQP_BASIC_PUBLISH_IMMEDIATE_BIT = 1;
  AMQP_BASIC_CONSUME_NO_LOCAL_BIT = 0;
  AMQP_BASIC_CONSUME_NO_ACK_BIT = 1;
  AMQP_BASIC_CONSUME_EXCLUSIVE_BIT = 2;
  AMQP_BASIC_CONSUME_NO_WAIT_BIT = 3;
  AMQP_BASIC_DELIVER_REDELIVERED_BIT = 0;
  AMQP_BASIC_ACK_MULTIPLE_BIT = 0;
  AMQP_BASIC_REJECT_REQUEUE_BIT = 0;
  AMQP_BASIC_NACK_MULTIPLE_BIT = 0;
  AMQP_BASIC_NACK_REQUEUE_BIT = 1;

  AMQP_BASIC_PROP_CONTENT_TYPE = $8000;
  AMQP_BASIC_PROP_CONTENT_ENCODING = $4000;
  AMQP_BASIC_PROP_DELIVERY_MODE = $1000;
  AMQP_BASIC_PROP_PRIORITY = $0800;
  AMQP_BASIC_PROP_CORRELATION_ID = $0400;
  AMQP_BASIC_PROP_REPLY_TO = $0200;
  AMQP_BASIC_PROP_EXPIRATION = $0100;
  AMQP_BASIC_PROP_MESSAGE_ID = $0080;
  AMQP_BASIC_PROP_TIMESTAMP = $0040;
  AMQP_BASIC_PROP_APP_ID = $0020;

type
  TAMQPMethodId = record
    ClassId: UInt16;
    MethodId: UInt16;
  end;

  TAMQPConnectionTune = record
    ChannelMax: UInt16;
    FrameMax: UInt32;
    Heartbeat: UInt16;
  end;

  TAMQPConnectionStart = record
    VersionMajor: Byte;
    VersionMinor: Byte;
    Mechanisms: string;
    Locales: string;
    function SupportsMechanism(const AMechanism: string): Boolean;
    function SupportsLocale(const ALocale: string): Boolean;
  end;

  TAMQPQueueDeclareOk = record
    QueueName: string;
    MessageCount: UInt32;
    ConsumerCount: UInt32;
  end;

  TAMQPChannelClose = record
    ReplyCode: UInt16;
    ReplyText: string;
    ClassId: UInt16;
    MethodId: UInt16;
  end;

  TAMQPConnectionClose = record
    ReplyCode: UInt16;
    ReplyText: string;
    ClassId: UInt16;
    MethodId: UInt16;
  end;

  TAMQPBasicDeliver = record
    ConsumerTag: string;
    DeliveryTag: UInt64;
    Redelivered: Boolean;
    Exchange: string;
    RoutingKey: string;
  end;

  TAMQPContentHeader = record
    ClassId: UInt16;
    BodySize: UInt64;
    Properties: TAMQPBasicProperties;
  end;

  TAMQPMethodCodec = class
  private
    class function PackBits(const ABits: array of Boolean): Byte; static;
    class procedure WriteBasicProperties(
      var AWriter: TAMQPBinaryWriter;
      const AProperties: TAMQPBasicProperties); static;
  public
    class function ReadMethodId(const AFrame: TAMQPFrame): TAMQPMethodId; static;
    class function ReadConnectionStart(const AFrame: TAMQPFrame): TAMQPConnectionStart; static;
    class function BuildConnectionStartOk(
      const AUserName: string;
      const APassword: string): TAMQPFrame; static;
    class function ReadConnectionTune(const AFrame: TAMQPFrame): TAMQPConnectionTune; static;
    class function BuildConnectionTuneOk(const ATune: TAMQPConnectionTune): TAMQPFrame; static;
    class function BuildConnectionOpen(const AVirtualHost: string): TAMQPFrame; static;
    class function BuildConnectionClose: TAMQPFrame; static;
    class function BuildConnectionCloseOk: TAMQPFrame; static;
    class function ReadConnectionClose(const AFrame: TAMQPFrame): TAMQPConnectionClose; static;
    class function BuildChannelOpen(const AChannelId: UInt16): TAMQPFrame; static;
    class function BuildChannelClose(const AChannelId: UInt16): TAMQPFrame; static;
    class function BuildChannelCloseOk(const AChannelId: UInt16): TAMQPFrame; static;
    class function ReadChannelClose(const AFrame: TAMQPFrame): TAMQPChannelClose; static;
    class function BuildQueueDeclare(
      const AChannelId: UInt16;
      const AQueueName: string;
      const ADurable: Boolean;
      const AExclusive: Boolean;
      const AAutoDelete: Boolean): TAMQPFrame; static;
    class function ReadQueueDeclareOk(const AFrame: TAMQPFrame): TAMQPQueueDeclareOk; static;
    class function BuildQueueDelete(
      const AChannelId: UInt16;
      const AQueueName: string;
      const AIfUnused: Boolean;
      const AIfEmpty: Boolean): TAMQPFrame; static;
    class function ReadQueueDeleteOk(const AFrame: TAMQPFrame): UInt32; static;
    class function BuildQueuePurge(const AChannelId: UInt16; const AQueueName: string): TAMQPFrame; static;
    class function ReadQueuePurgeOk(const AFrame: TAMQPFrame): UInt32; static;
    class function BuildBasicPublish(
      const AChannelId: UInt16;
      const AExchange: string;
      const ARoutingKey: string;
      const AMandatory: Boolean;
      const AImmediate: Boolean): TAMQPFrame; static;
    class function BuildBasicConsume(
      const AChannelId: UInt16;
      const AQueueName: string;
      const AConsumerTag: string;
      const AAutoAck: Boolean;
      const AExclusive: Boolean = False): TAMQPFrame; static;
    class function ReadBasicConsumeOk(const AFrame: TAMQPFrame): string; static;
    class function BuildBasicCancel(
      const AChannelId: UInt16;
      const AConsumerTag: string): TAMQPFrame; static;
    class function ReadBasicDeliver(const AFrame: TAMQPFrame): TAMQPBasicDeliver; static;
    class function BuildBasicAck(
      const AChannelId: UInt16;
      const ADeliveryTag: UInt64;
      const AMultiple: Boolean): TAMQPFrame; static;
    class function BuildBasicNack(
      const AChannelId: UInt16;
      const ADeliveryTag: UInt64;
      const AMultiple: Boolean;
      const ARequeue: Boolean): TAMQPFrame; static;
    class function BuildBasicReject(
      const AChannelId: UInt16;
      const ADeliveryTag: UInt64;
      const ARequeue: Boolean): TAMQPFrame; static;
    class function BuildContentHeader(
      const AChannelId: UInt16;
      const ABodySize: UInt64;
      const AProperties: TAMQPBasicProperties): TAMQPFrame; static;
    class function ReadContentHeader(const AFrame: TAMQPFrame): TAMQPContentHeader; static;
    class function BuildContentBodyFrames(
      const AChannelId: UInt16;
      const ABody: TBytes;
      const AMaxPayloadSize: UInt32): TArray<TAMQPFrame>; static;
  end;

implementation

function ContainsToken(const AText, AToken: string): Boolean;
var
  LTokens: TArray<string>;
  LToken: string;
begin
  Result := False;
  LTokens := AText.Split([' '], TStringSplitOptions.ExcludeEmpty);
  for LToken in LTokens do
    if SameText(LToken, AToken) then
      Exit(True);
end;

class function TAMQPMethodCodec.BuildChannelOpen(const AChannelId: UInt16): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CHANNEL);
  LWriter.WriteUInt16(AMQP_CHANNEL_OPEN);
  LWriter.WriteShortString(AMQP_RESERVED_SHORT_STRING);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildChannelClose(const AChannelId: UInt16): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CHANNEL);
  LWriter.WriteUInt16(AMQP_CHANNEL_CLOSE);
  LWriter.WriteUInt16(AMQP_REPLY_SUCCESS);
  LWriter.WriteShortString(AMQP_CHANNEL_CLOSE_REPLY_TEXT);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_CLASS_ID);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildChannelCloseOk(const AChannelId: UInt16): TAMQPFrame;
begin
  Result := TAMQPFrame.Create(
    AMQP_FRAME_METHOD,
    AChannelId,
    TAMQPFrameCodec.MethodPayload(AMQP_CLASS_CHANNEL, AMQP_CHANNEL_CLOSE_OK));
end;

class function TAMQPMethodCodec.BuildBasicPublish(
  const AChannelId: UInt16;
  const AExchange: string;
  const ARoutingKey: string;
  const AMandatory: Boolean;
  const AImmediate: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_PUBLISH);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  LWriter.WriteShortString(AExchange);
  LWriter.WriteShortString(ARoutingKey);
  LWriter.WriteUInt8(PackBits([AMandatory, AImmediate]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildBasicAck(
  const AChannelId: UInt16;
  const ADeliveryTag: UInt64;
  const AMultiple: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_ACK);
  LWriter.WriteUInt64(ADeliveryTag);
  LWriter.WriteUInt8(PackBits([AMultiple]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildBasicCancel(
  const AChannelId: UInt16;
  const AConsumerTag: string): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_CANCEL);
  LWriter.WriteShortString(AConsumerTag);
  LWriter.WriteUInt8(PackBits([False]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildBasicConsume(
  const AChannelId: UInt16;
  const AQueueName: string;
  const AConsumerTag: string;
  const AAutoAck: Boolean;
  const AExclusive: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_CONSUME);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  LWriter.WriteShortString(AQueueName);
  LWriter.WriteShortString(AConsumerTag);
  LWriter.WriteUInt8(PackBits([False, AAutoAck, AExclusive, False]));
  LWriter.WriteUInt32(AMQP_EMPTY_FIELD_TABLE_SIZE);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildBasicNack(
  const AChannelId: UInt16;
  const ADeliveryTag: UInt64;
  const AMultiple: Boolean;
  const ARequeue: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_NACK);
  LWriter.WriteUInt64(ADeliveryTag);
  LWriter.WriteUInt8(PackBits([AMultiple, ARequeue]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildBasicReject(
  const AChannelId: UInt16;
  const ADeliveryTag: UInt64;
  const ARequeue: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_REJECT);
  LWriter.WriteUInt64(ADeliveryTag);
  LWriter.WriteUInt8(PackBits([ARequeue]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildContentBodyFrames(
  const AChannelId: UInt16;
  const ABody: TBytes;
  const AMaxPayloadSize: UInt32): TArray<TAMQPFrame>;
var
  LOffset: Integer;
  LChunkSize: Integer;
  LIndex: Integer;
  LMaxPayloadSize: Integer;
begin
  if AMaxPayloadSize = 0 then
    raise EAMQPProtocolError.Create('AMQP max payload size must be greater than zero.');

  LMaxPayloadSize := Integer(AMaxPayloadSize);
  SetLength(Result, (Length(ABody) + LMaxPayloadSize - 1) div LMaxPayloadSize);
  LOffset := 0;
  LIndex := 0;
  while LOffset < Length(ABody) do
  begin
    LChunkSize := Length(ABody) - LOffset;
    if LChunkSize > LMaxPayloadSize then
      LChunkSize := LMaxPayloadSize;
    Result[LIndex] := TAMQPFrame.Create(
      AMQP_FRAME_BODY,
      AChannelId,
      Copy(ABody, LOffset, LChunkSize));
    Inc(LOffset, LChunkSize);
    Inc(LIndex);
  end;
end;

class function TAMQPMethodCodec.BuildContentHeader(
  const AChannelId: UInt16;
  const ABodySize: UInt64;
  const AProperties: TAMQPBasicProperties): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_CONTENT_HEADER_WEIGHT);
  LWriter.WriteUInt64(ABodySize);
  WriteBasicProperties(LWriter, AProperties);
  Result := TAMQPFrame.Create(AMQP_FRAME_HEADER, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildConnectionClose: TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_CLOSE);
  LWriter.WriteUInt16(AMQP_REPLY_SUCCESS);
  LWriter.WriteShortString(AMQP_CONNECTION_CLOSE_REPLY_TEXT);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_CLASS_ID);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildConnectionCloseOk: TAMQPFrame;
begin
  Result := TAMQPFrame.Create(
    AMQP_FRAME_METHOD,
    AMQP_CONNECTION_CHANNEL,
    TAMQPFrameCodec.MethodPayload(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_CLOSE_OK));
end;

class function TAMQPMethodCodec.BuildConnectionOpen(const AVirtualHost: string): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_OPEN);
  LWriter.WriteShortString(AVirtualHost);
  LWriter.WriteShortString(AMQP_RESERVED_SHORT_STRING);
  LWriter.WriteUInt8(AMQP_FALSE_BIT);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildConnectionStartOk(
  const AUserName: string;
  const APassword: string): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
  LResponse: TBytes;
begin
  LResponse := TEncoding.UTF8.GetBytes(
    AMQP_SASL_PLAIN_SEPARATOR + AUserName +
    AMQP_SASL_PLAIN_SEPARATOR + APassword);
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_START_OK);
  LWriter.WriteUInt32(AMQP_EMPTY_FIELD_TABLE_SIZE);
  LWriter.WriteShortString(AMQP_SASL_MECHANISM_PLAIN);
  LWriter.WriteLongString(LResponse);
  LWriter.WriteShortString(AMQP_LOCALE_EN_US);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildConnectionTuneOk(const ATune: TAMQPConnectionTune): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_TUNE_OK);
  LWriter.WriteUInt16(ATune.ChannelMax);
  LWriter.WriteUInt32(ATune.FrameMax);
  LWriter.WriteUInt16(ATune.Heartbeat);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildQueueDeclare(
  const AChannelId: UInt16;
  const AQueueName: string;
  const ADurable: Boolean;
  const AExclusive: Boolean;
  const AAutoDelete: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DECLARE);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  LWriter.WriteShortString(AQueueName);
  LWriter.WriteUInt8(PackBits([False, ADurable, AExclusive, AAutoDelete, False]));
  LWriter.WriteUInt32(AMQP_EMPTY_FIELD_TABLE_SIZE);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildQueueDelete(
  const AChannelId: UInt16;
  const AQueueName: string;
  const AIfUnused: Boolean;
  const AIfEmpty: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DELETE);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  LWriter.WriteShortString(AQueueName);
  LWriter.WriteUInt8(PackBits([AIfUnused, AIfEmpty, False]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.BuildQueuePurge(
  const AChannelId: UInt16;
  const AQueueName: string): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_PURGE);
  LWriter.WriteUInt16(AMQP_RESERVED_METHOD_ID);
  LWriter.WriteShortString(AQueueName);
  LWriter.WriteUInt8(PackBits([False]));
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

class function TAMQPMethodCodec.PackBits(const ABits: array of Boolean): Byte;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := Low(ABits) to High(ABits) do
    if ABits[LIndex] then
      Result := Result or Byte(1 shl LIndex);
end;

class function TAMQPMethodCodec.ReadConnectionTune(const AFrame: TAMQPFrame): TAMQPConnectionTune;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_CONNECTION) or
     (LMethod.MethodId <> AMQP_CONNECTION_TUNE) then
    raise EAMQPProtocolError.Create('Expected connection.tune frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.ChannelMax := LReader.ReadUInt16;
  Result.FrameMax := LReader.ReadUInt32;
  Result.Heartbeat := LReader.ReadUInt16;
end;

class function TAMQPMethodCodec.ReadConnectionStart(const AFrame: TAMQPFrame): TAMQPConnectionStart;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_CONNECTION) or
     (LMethod.MethodId <> AMQP_CONNECTION_START) then
    raise EAMQPProtocolError.Create('Expected connection.start frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.VersionMajor := LReader.ReadUInt8;
  Result.VersionMinor := LReader.ReadUInt8;
  LReader.ReadLongString;
  Result.Mechanisms := TEncoding.UTF8.GetString(LReader.ReadLongString);
  Result.Locales := TEncoding.UTF8.GetString(LReader.ReadLongString);
end;

class function TAMQPMethodCodec.ReadConnectionClose(const AFrame: TAMQPFrame): TAMQPConnectionClose;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_CONNECTION) or
     (LMethod.MethodId <> AMQP_CONNECTION_CLOSE) then
    raise EAMQPProtocolError.Create('Expected connection.close frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.ReplyCode := LReader.ReadUInt16;
  Result.ReplyText := LReader.ReadShortString;
  Result.ClassId := LReader.ReadUInt16;
  Result.MethodId := LReader.ReadUInt16;
end;

class function TAMQPMethodCodec.ReadMethodId(const AFrame: TAMQPFrame): TAMQPMethodId;
var
  LReader: TAMQPBinaryReader;
begin
  if AFrame.FrameType <> AMQP_FRAME_METHOD then
    raise EAMQPProtocolError.Create('Expected AMQP method frame.');
  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  Result.ClassId := LReader.ReadUInt16;
  Result.MethodId := LReader.ReadUInt16;
end;

class function TAMQPMethodCodec.ReadBasicConsumeOk(const AFrame: TAMQPFrame): string;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_BASIC) or
     (LMethod.MethodId <> AMQP_BASIC_CONSUME_OK) then
    raise EAMQPProtocolError.Create('Expected basic.consume-ok frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result := LReader.ReadShortString;
end;

class function TAMQPMethodCodec.ReadChannelClose(const AFrame: TAMQPFrame): TAMQPChannelClose;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_CHANNEL) or
     (LMethod.MethodId <> AMQP_CHANNEL_CLOSE) then
    raise EAMQPProtocolError.Create('Expected channel.close frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.ReplyCode := LReader.ReadUInt16;
  Result.ReplyText := LReader.ReadShortString;
  Result.ClassId := LReader.ReadUInt16;
  Result.MethodId := LReader.ReadUInt16;
end;

class function TAMQPMethodCodec.ReadBasicDeliver(const AFrame: TAMQPFrame): TAMQPBasicDeliver;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_BASIC) or
     (LMethod.MethodId <> AMQP_BASIC_DELIVER) then
    raise EAMQPProtocolError.Create('Expected basic.deliver frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.ConsumerTag := LReader.ReadShortString;
  Result.DeliveryTag := LReader.ReadUInt64;
  Result.Redelivered := (LReader.ReadUInt8 and (1 shl AMQP_BASIC_DELIVER_REDELIVERED_BIT)) <> 0;
  Result.Exchange := LReader.ReadShortString;
  Result.RoutingKey := LReader.ReadShortString;
end;

class function TAMQPMethodCodec.ReadContentHeader(const AFrame: TAMQPFrame): TAMQPContentHeader;
var
  LReader: TAMQPBinaryReader;
  LFlags: UInt16;
begin
  if AFrame.FrameType <> AMQP_FRAME_HEADER then
    raise EAMQPProtocolError.Create('Expected AMQP content header frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  Result.ClassId := LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.BodySize := LReader.ReadUInt64;
  LFlags := LReader.ReadUInt16;

  if (LFlags and AMQP_BASIC_PROP_CONTENT_TYPE) <> 0 then
    Result.Properties.ContentType := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_CONTENT_ENCODING) <> 0 then
    Result.Properties.ContentEncoding := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_DELIVERY_MODE) <> 0 then
    Result.Properties.DeliveryMode := LReader.ReadUInt8;
  if (LFlags and AMQP_BASIC_PROP_PRIORITY) <> 0 then
    Result.Properties.Priority := LReader.ReadUInt8;
  if (LFlags and AMQP_BASIC_PROP_CORRELATION_ID) <> 0 then
    Result.Properties.CorrelationId := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_REPLY_TO) <> 0 then
    Result.Properties.ReplyTo := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_EXPIRATION) <> 0 then
    Result.Properties.Expiration := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_MESSAGE_ID) <> 0 then
    Result.Properties.MessageId := LReader.ReadShortString;
  if (LFlags and AMQP_BASIC_PROP_TIMESTAMP) <> 0 then
    Result.Properties.Timestamp := UnixToDateTime(LReader.ReadUInt64);
  if (LFlags and AMQP_BASIC_PROP_APP_ID) <> 0 then
    Result.Properties.AppId := LReader.ReadShortString;
end;

class function TAMQPMethodCodec.ReadQueueDeclareOk(const AFrame: TAMQPFrame): TAMQPQueueDeclareOk;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_QUEUE) or
     (LMethod.MethodId <> AMQP_QUEUE_DECLARE_OK) then
    raise EAMQPProtocolError.Create('Expected queue.declare-ok frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result.QueueName := LReader.ReadShortString;
  Result.MessageCount := LReader.ReadUInt32;
  Result.ConsumerCount := LReader.ReadUInt32;
end;

class function TAMQPMethodCodec.ReadQueueDeleteOk(const AFrame: TAMQPFrame): UInt32;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_QUEUE) or
     (LMethod.MethodId <> AMQP_QUEUE_DELETE_OK) then
    raise EAMQPProtocolError.Create('Expected queue.delete-ok frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result := LReader.ReadUInt32;
end;

class function TAMQPMethodCodec.ReadQueuePurgeOk(const AFrame: TAMQPFrame): UInt32;
var
  LReader: TAMQPBinaryReader;
  LMethod: TAMQPMethodId;
begin
  LMethod := ReadMethodId(AFrame);
  if (LMethod.ClassId <> AMQP_CLASS_QUEUE) or
     (LMethod.MethodId <> AMQP_QUEUE_PURGE_OK) then
    raise EAMQPProtocolError.Create('Expected queue.purge-ok frame.');

  LReader := TAMQPBinaryReader.Create(AFrame.Payload);
  LReader.ReadUInt16;
  LReader.ReadUInt16;
  Result := LReader.ReadUInt32;
end;

class procedure TAMQPMethodCodec.WriteBasicProperties(
  var AWriter: TAMQPBinaryWriter;
  const AProperties: TAMQPBasicProperties);
var
  LFlags: UInt16;
begin
  LFlags := 0;
  if not AProperties.ContentType.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_CONTENT_TYPE;
  if not AProperties.ContentEncoding.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_CONTENT_ENCODING;
  if AProperties.DeliveryMode > 0 then
    LFlags := LFlags or AMQP_BASIC_PROP_DELIVERY_MODE;
  if AProperties.Priority > 0 then
    LFlags := LFlags or AMQP_BASIC_PROP_PRIORITY;
  if not AProperties.CorrelationId.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_CORRELATION_ID;
  if not AProperties.ReplyTo.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_REPLY_TO;
  if not AProperties.Expiration.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_EXPIRATION;
  if not AProperties.MessageId.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_MESSAGE_ID;
  if AProperties.Timestamp > 0 then
    LFlags := LFlags or AMQP_BASIC_PROP_TIMESTAMP;
  if not AProperties.AppId.IsEmpty then
    LFlags := LFlags or AMQP_BASIC_PROP_APP_ID;

  AWriter.WriteUInt16(LFlags);
  if not AProperties.ContentType.IsEmpty then
    AWriter.WriteShortString(AProperties.ContentType);
  if not AProperties.ContentEncoding.IsEmpty then
    AWriter.WriteShortString(AProperties.ContentEncoding);
  if AProperties.DeliveryMode > 0 then
    AWriter.WriteUInt8(AProperties.DeliveryMode);
  if AProperties.Priority > 0 then
    AWriter.WriteUInt8(AProperties.Priority);
  if not AProperties.CorrelationId.IsEmpty then
    AWriter.WriteShortString(AProperties.CorrelationId);
  if not AProperties.ReplyTo.IsEmpty then
    AWriter.WriteShortString(AProperties.ReplyTo);
  if not AProperties.Expiration.IsEmpty then
    AWriter.WriteShortString(AProperties.Expiration);
  if not AProperties.MessageId.IsEmpty then
    AWriter.WriteShortString(AProperties.MessageId);
  if AProperties.Timestamp > 0 then
    AWriter.WriteUInt64(DateTimeToUnix(AProperties.Timestamp));
  if not AProperties.AppId.IsEmpty then
    AWriter.WriteShortString(AProperties.AppId);
end;

function TAMQPConnectionStart.SupportsLocale(const ALocale: string): Boolean;
begin
  Result := ContainsToken(Locales, ALocale);
end;

function TAMQPConnectionStart.SupportsMechanism(const AMechanism: string): Boolean;
begin
  Result := ContainsToken(Mechanisms, AMechanism);
end;

end.
