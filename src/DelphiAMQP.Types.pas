unit DelphiAMQP.Types;

interface

uses
  System.SysUtils;

type
  EAMQPError = class(Exception);
  EAMQPProtocolError = class(EAMQPError);
  EAMQPConnectionError = class(EAMQPError);
  EAMQPChannelClosedError = class(EAMQPError);
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

end.
