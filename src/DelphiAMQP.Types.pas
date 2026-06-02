unit DelphiAMQP.Types;

interface

uses
  System.SysUtils;

type
  EAMQPError = class(Exception);
  EAMQPProtocolError = class(EAMQPError);
  EAMQPConnectionError = class(EAMQPError);
  EAMQPConnectionClosedError = class(EAMQPConnectionError)
  private
    FReplyCode: UInt16;
    FReplyText: string;
    FClassId: UInt16;
    FMethodId: UInt16;
  public
    constructor Create(
      const AReplyCode: UInt16;
      const AReplyText: string;
      const AClassId: UInt16;
      const AMethodId: UInt16); reintroduce;

    property ReplyCode: UInt16 read FReplyCode;
    property ReplyText: string read FReplyText;
    property ClassId: UInt16 read FClassId;
    property MethodId: UInt16 read FMethodId;
  end;

  EAMQPChannelClosedError = class(EAMQPError)
  private
    FChannelId: UInt16;
    FReplyCode: UInt16;
    FReplyText: string;
    FClassId: UInt16;
    FMethodId: UInt16;
  public
    constructor Create(
      const AChannelId: UInt16;
      const AReplyCode: UInt16;
      const AReplyText: string;
      const AClassId: UInt16;
      const AMethodId: UInt16); reintroduce;

    property ChannelId: UInt16 read FChannelId;
    property ReplyCode: UInt16 read FReplyCode;
    property ReplyText: string read FReplyText;
    property ClassId: UInt16 read FClassId;
    property MethodId: UInt16 read FMethodId;
  end;
  EAMQPNotImplementedError = class(EAMQPError);

  TAMQPConnectionState = (
    csDisconnected,
    csConnecting,
    csConnected,
    csClosing
  );

  TAMQPLogLevel = (
    llTrace,
    llDebug,
    llInfo,
    llWarning,
    llError
  );

  TAMQPLogEventKind = (
    lekConnection,
    lekChannel,
    lekQueue,
    lekPublish,
    lekConsume,
    lekAck,
    lekNack,
    lekHeartbeat,
    lekError
  );

  TAMQPConsumerDispatchMode = (
    cdmWorkerThread,
    cdmMainThread
  );

  TAMQPQueueDeclareResult = record
    QueueName: string;
    MessageCount: UInt32;
    ConsumerCount: UInt32;
  end;

  TAMQPBasicProperties = record
    ContentType: string;
    ContentEncoding: string;
    CorrelationId: string;
    ReplyTo: string;
    Expiration: string;
    MessageId: string;
    DeliveryMode: Byte;
    Priority: Byte;
    Timestamp: TDateTime;
    AppId: string;
  end;

  TAMQPLogEvent = record
    Timestamp: TDateTime;
    Level: TAMQPLogLevel;
    Kind: TAMQPLogEventKind;
    Message: string;
    Operation: string;
    ConnectionId: string;
    ChannelId: UInt16;
    ErrorClass: string;
    DurationMS: UInt64;
  end;

implementation

constructor EAMQPChannelClosedError.Create(
  const AChannelId: UInt16;
  const AReplyCode: UInt16;
  const AReplyText: string;
  const AClassId: UInt16;
  const AMethodId: UInt16);
begin
  FChannelId := AChannelId;
  FReplyCode := AReplyCode;
  FReplyText := AReplyText;
  FClassId := AClassId;
  FMethodId := AMethodId;
  inherited CreateFmt(
    'AMQP server closed channel %d: %d %s (related method %d.%d).',
    [AChannelId, AReplyCode, AReplyText, AClassId, AMethodId]);
end;

constructor EAMQPConnectionClosedError.Create(
  const AReplyCode: UInt16;
  const AReplyText: string;
  const AClassId: UInt16;
  const AMethodId: UInt16);
begin
  FReplyCode := AReplyCode;
  FReplyText := AReplyText;
  FClassId := AClassId;
  FMethodId := AMethodId;
  inherited CreateFmt(
    'AMQP server closed the connection: %d %s (related method %d.%d).',
    [AReplyCode, AReplyText, AClassId, AMethodId]);
end;

end.
