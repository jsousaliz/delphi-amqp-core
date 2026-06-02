unit DelphiAMQP.Tests.FrameBuilders;

interface

uses
  DelphiAMQP.Protocol.Frame;

function BuildQueueDeclareOkFrame(
  const AChannelId: UInt16;
  const AQueueName: string;
  const AMessageCount: UInt32;
  const AConsumerCount: UInt32): TAMQPFrame;
function BuildQueueDeleteOkFrame(const AChannelId: UInt16; const AMessageCount: UInt32): TAMQPFrame;
function BuildQueuePurgeOkFrame(const AChannelId: UInt16; const AMessageCount: UInt32): TAMQPFrame;
function BuildBasicConsumeOkFrame(const AChannelId: UInt16; const AConsumerTag: string): TAMQPFrame;
function BuildBasicDeliverFrame(
  const AChannelId: UInt16;
  const AConsumerTag: string;
  const ADeliveryTag: UInt64;
  const AExchange: string;
  const ARoutingKey: string;
  const ARedelivered: Boolean): TAMQPFrame;
function BuildBasicCancelOkFrame(const AChannelId: UInt16): TAMQPFrame;

implementation

uses
  DelphiAMQP.Protocol.Methods;

function BuildQueueDeclareOkFrame(
  const AChannelId: UInt16;
  const AQueueName: string;
  const AMessageCount: UInt32;
  const AConsumerCount: UInt32): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DECLARE_OK);
  LWriter.WriteShortString(AQueueName);
  LWriter.WriteUInt32(AMessageCount);
  LWriter.WriteUInt32(AConsumerCount);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

function BuildQueueDeleteOkFrame(const AChannelId: UInt16; const AMessageCount: UInt32): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DELETE_OK);
  LWriter.WriteUInt32(AMessageCount);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

function BuildQueuePurgeOkFrame(const AChannelId: UInt16; const AMessageCount: UInt32): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_PURGE_OK);
  LWriter.WriteUInt32(AMessageCount);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

function BuildBasicConsumeOkFrame(const AChannelId: UInt16; const AConsumerTag: string): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_CONSUME_OK);
  LWriter.WriteShortString(AConsumerTag);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

function BuildBasicCancelOkFrame(const AChannelId: UInt16): TAMQPFrame;
begin
  Result := TAMQPFrame.Create(
    AMQP_FRAME_METHOD,
    AChannelId,
    TAMQPFrameCodec.MethodPayload(AMQP_CLASS_BASIC, AMQP_BASIC_CANCEL_OK));
end;

function BuildBasicDeliverFrame(
  const AChannelId: UInt16;
  const AConsumerTag: string;
  const ADeliveryTag: UInt64;
  const AExchange: string;
  const ARoutingKey: string;
  const ARedelivered: Boolean): TAMQPFrame;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_DELIVER);
  LWriter.WriteShortString(AConsumerTag);
  LWriter.WriteUInt64(ADeliveryTag);
  if ARedelivered then
    LWriter.WriteUInt8(1)
  else
    LWriter.WriteUInt8(0);
  LWriter.WriteShortString(AExchange);
  LWriter.WriteShortString(ARoutingKey);
  Result := TAMQPFrame.Create(AMQP_FRAME_METHOD, AChannelId, LWriter.ToBytes);
end;

end.
