unit DelphiAMQP.Interfaces;

interface

uses
  System.SysUtils,
  System.TypInfo,
  DelphiAMQP.Types;

type
  IAMQPConnectionOptions = interface
    ['{B399E9CF-5744-4F15-905B-C8F96304E7C7}']
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

    property Host: string read GetHost;
    property Port: UInt16 read GetPort;
    property VirtualHost: string read GetVirtualHost;
    property UserName: string read GetUserName;
    property Password: string read GetPassword;
    property HeartbeatSeconds: UInt16 read GetHeartbeatSeconds;
    property ConnectionTimeoutMS: Cardinal read GetConnectionTimeoutMS;
    property UseTLS: Boolean read GetUseTLS;
    property ConsumerDispatchMode: TAMQPConsumerDispatchMode read GetConsumerDispatchMode;
  end;

  IAMQPMessage = interface
    ['{9EE68FC3-B5D3-473A-8A1C-1AB9237F57A4}']
    function GetBody: TBytes;
    function GetRoutingKey: string;
    function GetExchange: string;
    function GetDeliveryTag: UInt64;
    function GetRedelivered: Boolean;
    function GetProperties: TAMQPBasicProperties;
    function AsText(const AEncoding: TEncoding = nil): string;

    property Body: TBytes read GetBody;
    property RoutingKey: string read GetRoutingKey;
    property Exchange: string read GetExchange;
    property DeliveryTag: UInt64 read GetDeliveryTag;
    property Redelivered: Boolean read GetRedelivered;
    property Properties: TAMQPBasicProperties read GetProperties;
  end;

  IAMQPLogger = interface
    ['{11757F26-7B6A-487E-ACF1-BCDFE6BC2049}']
    procedure Log(const AEvent: TAMQPLogEvent);
  end;

  IAMQPConsumerContext = interface
    ['{A930996D-95C9-4F5D-B10F-A73EBD3D6CF0}']
    procedure Ack;
    procedure Nack(const ARequeue: Boolean);
    procedure Reject(const ARequeue: Boolean);
  end;

  TAMQPMessageHandler = reference to procedure(
    const AMessage: IAMQPMessage;
    const AContext: IAMQPConsumerContext);

  IAMQPConsumer = interface
    ['{316E2B9D-4C6F-4A52-BF82-F5570304F554}']
    procedure Start;
    procedure Stop;
    function IsRunning: Boolean;
    function GetQueueName: string;

    property QueueName: string read GetQueueName;
  end;

  IAMQPChannel = interface
    ['{73231AB1-7EE7-47CC-8BA9-92D2579717DA}']
    function GetChannelId: UInt16;
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

    property ChannelId: UInt16 read GetChannelId;
  end;

  IAMQPConnection = interface
    ['{6D2E4E61-D149-4C45-9AFD-8CA319895166}']
    procedure Connect;
    procedure Disconnect;
    function CreateChannel: IAMQPChannel;
    function GetState: TAMQPConnectionState;
    function GetOptions: IAMQPConnectionOptions;

    property State: TAMQPConnectionState read GetState;
    property Options: IAMQPConnectionOptions read GetOptions;
  end;

  IAMQPConnectionFactory = interface
    ['{0D8EBBB3-0F92-4331-8509-48450A05F2F3}']
    function CreateConnection(const AOptions: IAMQPConnectionOptions): IAMQPConnection;
  end;

implementation

end.
