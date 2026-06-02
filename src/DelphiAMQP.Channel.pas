unit DelphiAMQP.Channel;

interface

uses
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Internal.Session;

type
  TAMQPChannel = class(TInterfacedObject, IAMQPChannel)
  private
    FChannelId: UInt16;
    FLogger: IAMQPLogger;
    FSession: IAMQPFrameSession;
    function MaxContentBodyPayloadSize: UInt32;
    function GetChannelId: UInt16;
  public
    constructor Create(
      const AChannelId: UInt16;
      const ALogger: IAMQPLogger;
      const ASession: IAMQPFrameSession);

    function QueueDeclare(
      const AQueueName: string;
      const ADurable: Boolean = True;
      const AExclusive: Boolean = False;
      const AAutoDelete: Boolean = False): TAMQPQueueDeclareResult;
    procedure QueueDelete(
      const AQueueName: string;
      const AIfUnused: Boolean = False;
      const AIfEmpty: Boolean = False);
    procedure QueuePurge(const AQueueName: string);
    procedure Publish(
      const AExchange: string;
      const ARoutingKey: string;
      const AMessage: IAMQPMessage;
      const AMandatory: Boolean = False;
      const AImmediate: Boolean = False);
    function BasicConsume(
      const AQueueName: string;
      const AMessageHandler: TAMQPMessageHandler;
      const AAutoAck: Boolean = False): IAMQPConsumer;
    procedure BasicAck(const ADeliveryTag: UInt64; const AMultiple: Boolean = False);
    procedure BasicNack(
      const ADeliveryTag: UInt64;
      const AMultiple: Boolean = False;
      const ARequeue: Boolean = True);
    procedure BasicReject(const ADeliveryTag: UInt64; const ARequeue: Boolean = True);
    procedure Close;
  end;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Consumer,
  DelphiAMQP.Logging;

constructor TAMQPChannel.Create(
  const AChannelId: UInt16;
  const ALogger: IAMQPLogger;
  const ASession: IAMQPFrameSession);
begin
  inherited Create;
  if AChannelId = AMQP_CONNECTION_CHANNEL then
    raise EAMQPError.Create('Channel id must be greater than zero.');
  if ASession = nil then
    raise EAMQPError.Create('Frame session must not be nil.');
  FChannelId := AChannelId;
  FLogger := ALogger;
  FSession := ASession;
end;

procedure TAMQPChannel.BasicAck(const ADeliveryTag: UInt64; const AMultiple: Boolean);
begin
  TAMQPLogger.Emit(FLogger, llDebug, lekAck, 'basic.ack requested',
    FSession.GetConnectionId, FChannelId, '', 'basic.ack');
  FSession.SendFrame(TAMQPMethodCodec.BuildBasicAck(FChannelId, ADeliveryTag, AMultiple));
end;

function TAMQPChannel.BasicConsume(
  const AQueueName: string;
  const AMessageHandler: TAMQPMessageHandler;
  const AAutoAck: Boolean): IAMQPConsumer;
var
  LFrame: TAMQPFrame;
  LConsumerTag: string;
begin
  if AQueueName.Trim.IsEmpty then
    raise EAMQPError.Create('Queue name must not be empty.');
  TAMQPLogger.Emit(FLogger, llInfo, lekConsume, 'basic.consume prepared for queue ' + AQueueName,
    FSession.GetConnectionId, FChannelId, '', 'basic.consume');
  FSession.SendFrame(TAMQPMethodCodec.BuildBasicConsume(
    FChannelId,
    AQueueName,
    '',
    AAutoAck));
  LFrame := FSession.ReceiveExpectedMethod(AMQP_CLASS_BASIC, AMQP_BASIC_CONSUME_OK);
  LConsumerTag := TAMQPMethodCodec.ReadBasicConsumeOk(LFrame);
  Result := TAMQPConsumer.Create(
      AQueueName,
      LConsumerTag,
    Self as IAMQPChannel,
    FSession,
    AMessageHandler,
    AAutoAck,
    FLogger);
end;

procedure TAMQPChannel.BasicNack(
  const ADeliveryTag: UInt64;
  const AMultiple: Boolean;
  const ARequeue: Boolean);
begin
  TAMQPLogger.Emit(FLogger, llDebug, lekNack, 'basic.nack requested',
    FSession.GetConnectionId, FChannelId, '', 'basic.nack');
  FSession.SendFrame(TAMQPMethodCodec.BuildBasicNack(FChannelId, ADeliveryTag, AMultiple, ARequeue));
end;

procedure TAMQPChannel.BasicReject(const ADeliveryTag: UInt64; const ARequeue: Boolean);
begin
  TAMQPLogger.Emit(FLogger, llDebug, lekNack, 'basic.reject requested',
    FSession.GetConnectionId, FChannelId, '', 'basic.reject');
  FSession.SendFrame(TAMQPMethodCodec.BuildBasicReject(FChannelId, ADeliveryTag, ARequeue));
end;

procedure TAMQPChannel.Close;
begin
  TAMQPLogger.Emit(FLogger, llInfo, lekChannel, 'Channel closed',
    FSession.GetConnectionId, FChannelId, '', 'channel.close');
end;

function TAMQPChannel.GetChannelId: UInt16;
begin
  Result := FChannelId;
end;

procedure TAMQPChannel.Publish(
  const AExchange: string;
  const ARoutingKey: string;
  const AMessage: IAMQPMessage;
  const AMandatory: Boolean;
  const AImmediate: Boolean);
var
  LBody: TBytes;
  LBodyFrames: TArray<TAMQPFrame>;
  LFrame: TAMQPFrame;
begin
  if AMessage = nil then
    raise EAMQPError.Create('Message must not be nil.');
  if ARoutingKey.Trim.IsEmpty and AExchange.Trim.IsEmpty then
    raise EAMQPError.Create('Routing key or exchange must be informed.');

  TAMQPLogger.Emit(FLogger, llInfo, lekPublish, 'basic.publish requested',
    FSession.GetConnectionId, FChannelId, '', 'basic.publish');
  LBody := AMessage.Body;
  FSession.SendFrame(TAMQPMethodCodec.BuildBasicPublish(
    FChannelId,
    AExchange,
    ARoutingKey,
    AMandatory,
    AImmediate));
  FSession.SendFrame(TAMQPMethodCodec.BuildContentHeader(
    FChannelId,
    Length(LBody),
    AMessage.Properties));
  LBodyFrames := TAMQPMethodCodec.BuildContentBodyFrames(
    FChannelId,
    LBody,
    MaxContentBodyPayloadSize);
  for LFrame in LBodyFrames do
    FSession.SendFrame(LFrame);
end;

function TAMQPChannel.QueueDeclare(
  const AQueueName: string;
  const ADurable: Boolean;
  const AExclusive: Boolean;
  const AAutoDelete: Boolean): TAMQPQueueDeclareResult;
var
  LFrame: TAMQPFrame;
  LDeclareOk: TAMQPQueueDeclareOk;
begin
  if AQueueName.Trim.IsEmpty then
    raise EAMQPError.Create('Queue name must not be empty.');

  TAMQPLogger.Emit(FLogger, llInfo, lekQueue, 'queue.declare requested for ' + AQueueName,
    FSession.GetConnectionId, FChannelId, '', 'queue.declare');
  FSession.SendFrame(TAMQPMethodCodec.BuildQueueDeclare(
    FChannelId,
    AQueueName,
    ADurable,
    AExclusive,
    AAutoDelete));
  LFrame := FSession.ReceiveExpectedMethod(AMQP_CLASS_QUEUE, AMQP_QUEUE_DECLARE_OK);
  LDeclareOk := TAMQPMethodCodec.ReadQueueDeclareOk(LFrame);
  Result.QueueName := LDeclareOk.QueueName;
  Result.MessageCount := LDeclareOk.MessageCount;
  Result.ConsumerCount := LDeclareOk.ConsumerCount;
end;

procedure TAMQPChannel.QueueDelete(
  const AQueueName: string;
  const AIfUnused: Boolean;
  const AIfEmpty: Boolean);
begin
  if AQueueName.Trim.IsEmpty then
    raise EAMQPError.Create('Queue name must not be empty.');
  TAMQPLogger.Emit(FLogger, llInfo, lekQueue, 'queue.delete requested for ' + AQueueName,
    FSession.GetConnectionId, FChannelId, '', 'queue.delete');
  FSession.SendFrame(TAMQPMethodCodec.BuildQueueDelete(FChannelId, AQueueName, AIfUnused, AIfEmpty));
  TAMQPMethodCodec.ReadQueueDeleteOk(
    FSession.ReceiveExpectedMethod(AMQP_CLASS_QUEUE, AMQP_QUEUE_DELETE_OK));
end;

procedure TAMQPChannel.QueuePurge(const AQueueName: string);
begin
  if AQueueName.Trim.IsEmpty then
    raise EAMQPError.Create('Queue name must not be empty.');
  TAMQPLogger.Emit(FLogger, llInfo, lekQueue, 'queue.purge requested for ' + AQueueName,
    FSession.GetConnectionId, FChannelId, '', 'queue.purge');
  FSession.SendFrame(TAMQPMethodCodec.BuildQueuePurge(FChannelId, AQueueName));
  TAMQPMethodCodec.ReadQueuePurgeOk(
    FSession.ReceiveExpectedMethod(AMQP_CLASS_QUEUE, AMQP_QUEUE_PURGE_OK));
end;

function TAMQPChannel.MaxContentBodyPayloadSize: UInt32;
begin
  Result := FSession.GetFrameMax;
  if Result = 0 then
    Result := AMQP_DEFAULT_FRAME_MAX;
end;

end.
