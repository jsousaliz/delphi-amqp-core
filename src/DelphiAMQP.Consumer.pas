unit DelphiAMQP.Consumer;

interface

uses
  System.Classes,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Internal.Session;

type
  TAMQPConsumerContext = class(TInterfacedObject, IAMQPConsumerContext)
  private
    FChannel: IAMQPChannel;
    FDeliveryTag: UInt64;
    FAutoAck: Boolean;
  public
    constructor Create(
      const AChannel: IAMQPChannel;
      const ADeliveryTag: UInt64;
      const AAutoAck: Boolean);
    procedure Ack;
    procedure Nack(const ARequeue: Boolean);
    procedure Reject(const ARequeue: Boolean);
  end;

  TAMQPConsumer = class(TInterfacedObject, IAMQPConsumer)
  private
    FQueueName: string;
    FConsumerTag: string;
    FChannel: IAMQPChannel;
    FSession: IAMQPFrameSession;
    FMessageHandler: TAMQPMessageHandler;
    FAutoAck: Boolean;
    FLogger: IAMQPLogger;
    FThread: TThread;
    FLock: TObject;
    FRunning: Boolean;
    function ChannelId: UInt16;
    function GetQueueName: string;
    procedure DispatchMessage(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext);
    procedure Execute;
    function ReceiveMessageFromDeliver(const ADeliverFrame: TAMQPFrame): IAMQPMessage;
    procedure SetRunning(const AValue: Boolean);
  public
    constructor Create(
      const AQueueName: string;
      const AConsumerTag: string;
      const AChannel: IAMQPChannel;
      const ASession: IAMQPFrameSession;
      const AMessageHandler: TAMQPMessageHandler;
      const AAutoAck: Boolean;
      const ALogger: IAMQPLogger);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    function IsRunning: Boolean;
  end;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Message,
  DelphiAMQP.Logging;

constructor TAMQPConsumerContext.Create(
  const AChannel: IAMQPChannel;
  const ADeliveryTag: UInt64;
  const AAutoAck: Boolean);
begin
  inherited Create;
  FChannel := AChannel;
  FDeliveryTag := ADeliveryTag;
  FAutoAck := AAutoAck;
end;

procedure TAMQPConsumerContext.Ack;
begin
  if FAutoAck then
    Exit;
  FChannel.BasicAck(FDeliveryTag);
end;

procedure TAMQPConsumerContext.Nack(const ARequeue: Boolean);
begin
  if FAutoAck then
    raise EAMQPError.Create('Cannot nack a message consumed with autoAck=True.');
  FChannel.BasicNack(FDeliveryTag, False, ARequeue);
end;

procedure TAMQPConsumerContext.Reject(const ARequeue: Boolean);
begin
  if FAutoAck then
    raise EAMQPError.Create('Cannot reject a message consumed with autoAck=True.');
  FChannel.BasicReject(FDeliveryTag, ARequeue);
end;

constructor TAMQPConsumer.Create(
  const AQueueName: string;
  const AConsumerTag: string;
  const AChannel: IAMQPChannel;
  const ASession: IAMQPFrameSession;
  const AMessageHandler: TAMQPMessageHandler;
  const AAutoAck: Boolean;
  const ALogger: IAMQPLogger);
begin
  inherited Create;
  if AQueueName.Trim.IsEmpty then
    raise EAMQPError.Create('Queue name must not be empty.');
  if not Assigned(AMessageHandler) then
    raise EAMQPError.Create('Message handler must be assigned.');
  if ASession = nil then
    raise EAMQPError.Create('Frame session must not be nil.');
  if AChannel = nil then
    raise EAMQPError.Create('Channel must not be nil.');

  FQueueName := AQueueName;
  FConsumerTag := AConsumerTag;
  FChannel := AChannel;
  FSession := ASession;
  FMessageHandler := AMessageHandler;
  FAutoAck := AAutoAck;
  FLogger := ALogger;
  FLock := TObject.Create;
end;

function TAMQPConsumer.ChannelId: UInt16;
begin
  Result := FChannel.ChannelId;
end;

procedure TAMQPConsumer.DispatchMessage(
  const AMessage: IAMQPMessage;
  const AContext: IAMQPConsumerContext);
begin
  if FSession.GetConsumerDispatchMode = cdmMainThread then
    TThread.Queue(nil,
      procedure
      begin
        FMessageHandler(AMessage, AContext);
      end)
  else
    FMessageHandler(AMessage, AContext);
end;

procedure TAMQPConsumer.Execute;
var
  LFrame: TAMQPFrame;
  LMethod: TAMQPMethodId;
  LMessage: IAMQPMessage;
  LContext: IAMQPConsumerContext;
begin
  while True do
  begin
    LFrame := FSession.ReceiveFrame;
    if LFrame.FrameType = AMQP_FRAME_HEARTBEAT then
      Continue;
    if LFrame.Channel <> ChannelId then
      raise EAMQPProtocolError.Create('Received frame for an unexpected channel.');

    LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
    if (LMethod.ClassId = AMQP_CLASS_BASIC) and
       (LMethod.MethodId = AMQP_BASIC_DELIVER) then
    begin
      LMessage := ReceiveMessageFromDeliver(LFrame);
      LContext := TAMQPConsumerContext.Create(FChannel, LMessage.DeliveryTag, FAutoAck);
      DispatchMessage(LMessage, LContext);
    end
    else if (LMethod.ClassId = AMQP_CLASS_BASIC) and
            ((LMethod.MethodId = AMQP_BASIC_CANCEL) or
             (LMethod.MethodId = AMQP_BASIC_CANCEL_OK)) then
      Break
    else
      raise EAMQPProtocolError.CreateFmt(
        'Unexpected AMQP method frame %d.%d while consuming.',
        [LMethod.ClassId, LMethod.MethodId]);
  end;
end;

destructor TAMQPConsumer.Destroy;
begin
  Stop;
  FLock.Free;
  inherited;
end;

function TAMQPConsumer.GetQueueName: string;
begin
  Result := FQueueName;
end;

function TAMQPConsumer.IsRunning: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TAMQPConsumer.SetRunning(const AValue: Boolean);
begin
  TMonitor.Enter(FLock);
  try
    FRunning := AValue;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TAMQPConsumer.Start;
begin
  if IsRunning then
    Exit;

  SetRunning(True);
  TAMQPLogger.Info(
    FLogger,
    lekConsume,
    FSession.GetConnectionId,
    ChannelId,
    Format('Consumer started for queue %s', [FQueueName]),
    AMQP_LOG_CONSUMER_START);

  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        try
          Execute;
        except
          on E: Exception do
            TAMQPLogger.Error(
              FLogger,
              lekError,
              FSession.GetConnectionId,
              ChannelId,
              AMQP_LOG_CONSUMER_ERROR,
              E);
        end;
      finally
        SetRunning(False);
      end;
    end);
  FThread.FreeOnTerminate := False;
  FThread.Start;
end;

procedure TAMQPConsumer.Stop;
begin
  if not IsRunning then
    Exit;

  if FSession <> nil then
  begin
    try
      FSession.SendFrame(TAMQPMethodCodec.BuildBasicCancel(ChannelId, FConsumerTag));
    except
      on E: Exception do
        TAMQPLogger.Warning(
          FLogger,
          lekError,
          FSession.GetConnectionId,
          ChannelId,
          E.Message,
          AMQP_LOG_BASIC_CANCEL_ERROR,
          E.ClassName);
    end;
  end;
  if FThread <> nil then
  begin
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
  SetRunning(False);
  TAMQPLogger.Info(
    FLogger,
    lekConsume,
    FSession.GetConnectionId,
    ChannelId,
    Format('Consumer stopped for queue %s', [FQueueName]),
    AMQP_LOG_CONSUMER_STOP);
end;

function TAMQPConsumer.ReceiveMessageFromDeliver(const ADeliverFrame: TAMQPFrame): IAMQPMessage;
var
  LDeliver: TAMQPBasicDeliver;
  LHeader: TAMQPContentHeader;
  LHeaderFrame: TAMQPFrame;
  LBodyFrame: TAMQPFrame;
  LBody: TBytes;
  LOffset: Integer;
  LCopySize: Integer;
begin
  LDeliver := TAMQPMethodCodec.ReadBasicDeliver(ADeliverFrame);
  LHeaderFrame := FSession.ReceiveFrame;
  if LHeaderFrame.Channel <> ChannelId then
    raise EAMQPProtocolError.Create('Received content header for an unexpected channel.');
  LHeader := TAMQPMethodCodec.ReadContentHeader(LHeaderFrame);
  if LHeader.ClassId <> AMQP_CLASS_BASIC then
    raise EAMQPProtocolError.Create('Expected basic content header.');

  SetLength(LBody, Integer(LHeader.BodySize));
  LOffset := 0;
  while UInt64(LOffset) < LHeader.BodySize do
  begin
    LBodyFrame := FSession.ReceiveFrame;
    if LBodyFrame.Channel <> ChannelId then
      raise EAMQPProtocolError.Create('Received content body for an unexpected channel.');
    if LBodyFrame.FrameType <> AMQP_FRAME_BODY then
      raise EAMQPProtocolError.Create('Expected AMQP content body frame.');

    LCopySize := Length(LBodyFrame.Payload);
    if LOffset + LCopySize > Length(LBody) then
      raise EAMQPProtocolError.Create('Received more body bytes than expected.');
    if LCopySize > 0 then
      Move(LBodyFrame.Payload[0], LBody[LOffset], LCopySize);
    Inc(LOffset, LCopySize);
  end;

  Result := TAMQPMessage.FromDelivery(
    LBody,
    LDeliver.Exchange,
    LDeliver.RoutingKey,
    LDeliver.DeliveryTag,
    LDeliver.Redelivered,
    LHeader.Properties);
end;

end.
