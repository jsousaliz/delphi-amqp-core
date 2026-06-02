unit DelphiAMQP.Connection;

interface

uses
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Transport.Tcp,
  DelphiAMQP.Internal.Session;

type
  TAMQPConnection = class(TInterfacedObject, IAMQPConnection, IAMQPFrameSession)
  private
    FOptions: IAMQPConnectionOptions;
    FLogger: IAMQPLogger;
    FState: TAMQPConnectionState;
    FNextChannelId: UInt16;
    FConnectionId: string;
    FTransport: TAMQPTcpTransport;
    FTune: TAMQPConnectionTune;
    FSendLock: TObject;
    FReceiveLock: TObject;
    class function NewConnectionId: string; static;
    function GetState: TAMQPConnectionState;
    function GetOptions: IAMQPConnectionOptions;
    function GetFrameMax: UInt32;
    function GetConnectionId: string;
    function GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
    procedure SendConnectionCloseOkIfNeeded(const AFrame: TAMQPFrame);
    procedure SetState(const AState: TAMQPConnectionState);
  public
    constructor Create(const AOptions: IAMQPConnectionOptions; const ALogger: IAMQPLogger);
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;
    function CreateChannel: IAMQPChannel;
    procedure SendFrame(const AFrame: TAMQPFrame);
    function ReceiveFrame: TAMQPFrame;
    function ReceiveExpectedMethod(const AClassId, AMethodId: UInt16): TAMQPFrame;
  end;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Channel,
  DelphiAMQP.Logging;

constructor TAMQPConnection.Create(const AOptions: IAMQPConnectionOptions; const ALogger: IAMQPLogger);
begin
  inherited Create;
  if AOptions = nil then
    raise EAMQPConnectionError.Create('Connection options must not be nil.');

  FOptions := AOptions;
  FLogger := ALogger;
  FState := csDisconnected;
  FNextChannelId := AMQP_FIRST_APPLICATION_CHANNEL;
  FConnectionId := NewConnectionId;
  FTransport := TAMQPTcpTransport.Create;
  FSendLock := TObject.Create;
  FReceiveLock := TObject.Create;
  FTune.ChannelMax := AMQP_NO_CHANNEL_MAX;
  FTune.FrameMax := AMQP_DEFAULT_FRAME_MAX;
  FTune.Heartbeat := FOptions.HeartbeatSeconds;
end;

destructor TAMQPConnection.Destroy;
begin
  Disconnect;
  FReceiveLock.Free;
  FSendLock.Free;
  FTransport.Free;
  inherited;
end;

procedure TAMQPConnection.Connect;
var
  LFrame: TAMQPFrame;
  LTune: TAMQPConnectionTune;
begin
  if FState = csConnected then
    Exit;

  SetState(csConnecting);
  TAMQPLogger.Emit(FLogger, llInfo, lekConnection,
    Format('Connecting to %s:%d', [FOptions.Host, FOptions.Port]),
    FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'tcp.connect');

  try
    FTransport.Connect(FOptions.Host, FOptions.Port, FOptions.ConnectionTimeoutMS);
    TAMQPLogger.Emit(FLogger, llInfo, lekConnection, 'TCP socket connected',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'tcp.connected');

    FTransport.SendBytes(TAMQPFrameCodec.ProtocolHeader);
    TAMQPLogger.Emit(FLogger, llDebug, lekConnection, 'AMQP protocol header sent',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'protocol.header');

    LFrame := ReceiveExpectedMethod(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_START);
    TAMQPLogger.Emit(FLogger, llDebug, lekConnection, 'connection.start received',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'connection.start');

    SendFrame(TAMQPMethodCodec.BuildConnectionStartOk(FOptions.UserName, FOptions.Password));
    TAMQPLogger.Emit(FLogger, llDebug, lekConnection, 'connection.start-ok sent',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'connection.start-ok');

    LFrame := ReceiveExpectedMethod(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_TUNE);
    LTune := TAMQPMethodCodec.ReadConnectionTune(LFrame);
    if FOptions.HeartbeatSeconds < LTune.Heartbeat then
      LTune.Heartbeat := FOptions.HeartbeatSeconds;
    FTune := LTune;

    SendFrame(TAMQPMethodCodec.BuildConnectionTuneOk(FTune));
    TAMQPLogger.Emit(FLogger, llDebug, lekConnection, 'connection.tune-ok sent',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'connection.tune-ok');

    SendFrame(TAMQPMethodCodec.BuildConnectionOpen(FOptions.VirtualHost));
    ReceiveExpectedMethod(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_OPEN_OK);

    SetState(csConnected);
    TAMQPLogger.Emit(FLogger, llInfo, lekConnection, 'AMQP connection opened',
      FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'connection.open');
  except
    on E: Exception do
    begin
      FTransport.Disconnect;
      SetState(csDisconnected);
      TAMQPLogger.Emit(FLogger, llError, lekError, E.Message,
        FConnectionId, AMQP_CONNECTION_CHANNEL, E.ClassName, 'connection.error');
      raise;
    end;
  end;
end;

function TAMQPConnection.CreateChannel: IAMQPChannel;
var
  LChannelId: UInt16;
begin
  if FState <> csConnected then
    raise EAMQPConnectionError.Create('Connection must be connected before creating a channel.');

  LChannelId := FNextChannelId;
  if (FTune.ChannelMax > AMQP_NO_CHANNEL_MAX) and (LChannelId > FTune.ChannelMax) then
    raise EAMQPConnectionError.Create('AMQP channel_max negotiated with server was reached.');

  SendFrame(TAMQPMethodCodec.BuildChannelOpen(LChannelId));
  ReceiveExpectedMethod(AMQP_CLASS_CHANNEL, AMQP_CHANNEL_OPEN_OK);
  TAMQPLogger.Emit(FLogger, llInfo, lekChannel, 'AMQP channel opened',
    FConnectionId, LChannelId, '', 'channel.open');

  Result := TAMQPChannel.Create(LChannelId, FLogger, Self as IAMQPFrameSession);
  Inc(FNextChannelId);
end;

procedure TAMQPConnection.Disconnect;
begin
  if FState = csDisconnected then
    Exit;
  SetState(csClosing);
  TAMQPLogger.Emit(FLogger, llInfo, lekConnection, 'Disconnecting',
    FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'connection.close');
  if FTransport.Connected then
  begin
    try
      if FState <> csDisconnected then
      begin
        SendFrame(TAMQPMethodCodec.BuildConnectionClose);
        ReceiveExpectedMethod(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_CLOSE_OK);
      end;
    except
      on E: Exception do
        TAMQPLogger.Emit(FLogger, llWarning, lekError, E.Message,
          FConnectionId, AMQP_CONNECTION_CHANNEL, E.ClassName, 'connection.close-error');
    end;
    FTransport.Disconnect;
  end;
  SetState(csDisconnected);
end;

function TAMQPConnection.GetOptions: IAMQPConnectionOptions;
begin
  Result := FOptions;
end;

function TAMQPConnection.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function TAMQPConnection.GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
begin
  Result := FOptions.ConsumerDispatchMode;
end;

function TAMQPConnection.GetFrameMax: UInt32;
begin
  Result := FTune.FrameMax;
end;

function TAMQPConnection.GetState: TAMQPConnectionState;
begin
  Result := FState;
end;

procedure TAMQPConnection.SetState(const AState: TAMQPConnectionState);
begin
  FState := AState;
end;

class function TAMQPConnection.NewConnectionId: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
end;

function TAMQPConnection.ReceiveExpectedMethod(const AClassId, AMethodId: UInt16): TAMQPFrame;
var
  LMethod: TAMQPMethodId;
begin
  repeat
    Result := ReceiveFrame;
    if Result.FrameType = AMQP_FRAME_HEARTBEAT then
    begin
      TAMQPLogger.Emit(FLogger, llTrace, lekHeartbeat, 'Heartbeat received',
        FConnectionId, AMQP_CONNECTION_CHANNEL, '', 'heartbeat.receive');
      Continue;
    end;

    LMethod := TAMQPMethodCodec.ReadMethodId(Result);
    if (LMethod.ClassId = AMQP_CLASS_CONNECTION) and
       (LMethod.MethodId = AMQP_CONNECTION_CLOSE) then
    begin
      SendConnectionCloseOkIfNeeded(Result);
      raise EAMQPConnectionError.Create('AMQP server closed the connection during handshake.');
    end;

    if (LMethod.ClassId = AMQP_CLASS_CHANNEL) and
       (LMethod.MethodId = AMQP_CHANNEL_CLOSE) then
      raise EAMQPConnectionError.Create('AMQP server closed the channel during open.');

    if (LMethod.ClassId = AClassId) and (LMethod.MethodId = AMethodId) then
      Exit;

    raise EAMQPProtocolError.CreateFmt(
      'Unexpected AMQP method frame %d.%d; expected %d.%d.',
      [LMethod.ClassId, LMethod.MethodId, AClassId, AMethodId]);
  until False;
end;

function TAMQPConnection.ReceiveFrame: TAMQPFrame;
var
  LHeader: TBytes;
  LPayloadSize: UInt32;
  LFrameBytes: TBytes;
  LPayloadAndEnd: TBytes;
begin
  TMonitor.Enter(FReceiveLock);
  try
    LHeader := FTransport.ReceiveBytes(AMQP_FRAME_HEADER_SIZE);
    LPayloadSize :=
      (UInt32(LHeader[AMQP_FRAME_PAYLOAD_SIZE_OFFSET]) shl 24) or
      (UInt32(LHeader[AMQP_FRAME_PAYLOAD_SIZE_OFFSET + 1]) shl 16) or
      (UInt32(LHeader[AMQP_FRAME_PAYLOAD_SIZE_OFFSET + 2]) shl 8) or
      UInt32(LHeader[AMQP_FRAME_PAYLOAD_SIZE_OFFSET + 3]);
    if LPayloadSize > FTune.FrameMax then
      raise EAMQPProtocolError.Create('Received AMQP frame exceeds negotiated frame_max.');

    LPayloadAndEnd := FTransport.ReceiveBytes(Integer(LPayloadSize) + AMQP_FRAME_END_SIZE);
    SetLength(LFrameBytes, Length(LHeader) + Length(LPayloadAndEnd));
    Move(LHeader[0], LFrameBytes[0], Length(LHeader));
    Move(LPayloadAndEnd[0], LFrameBytes[Length(LHeader)], Length(LPayloadAndEnd));
    Result := TAMQPFrameCodec.DecodeFrame(LFrameBytes);
  finally
    TMonitor.Exit(FReceiveLock);
  end;
end;

procedure TAMQPConnection.SendConnectionCloseOkIfNeeded(const AFrame: TAMQPFrame);
begin
  if FTransport.Connected then
    SendFrame(TAMQPMethodCodec.BuildConnectionCloseOk);
end;

procedure TAMQPConnection.SendFrame(const AFrame: TAMQPFrame);
begin
  TMonitor.Enter(FSendLock);
  try
    FTransport.SendBytes(TAMQPFrameCodec.EncodeFrame(AFrame));
  finally
    TMonitor.Exit(FSendLock);
  end;
end;

end.
