unit DelphiAMQP.Tests.FakeFrameSession;

interface

uses
  System.SyncObjs,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Internal.Session;

type
  TFakeAMQPFrameSession = class(TInterfacedObject, IAMQPFrameSession)
  private
    FSentFrames: TArray<TAMQPFrame>;
    FReplyFrames: TArray<TAMQPFrame>;
    FConnectionId: string;
    FFrameMax: UInt32;
    FDispatchMode: TAMQPConsumerDispatchMode;
    FLock: TObject;
    FReplyAvailable: TEvent;
    function PopReply: TAMQPFrame;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddReply(const AFrame: TAMQPFrame);
    function SentCount: Integer;
    function SentFrame(const AIndex: Integer): TAMQPFrame;

    procedure SendFrame(const AFrame: TAMQPFrame);
    function ReceiveFrame: TAMQPFrame;
    function ReceiveExpectedMethod(const AClassId, AMethodId: UInt16): TAMQPFrame;
    function GetFrameMax: UInt32;
    function GetConnectionId: string;
    function GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
  end;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Protocol.Methods;

const
  FAKE_RECEIVE_TIMEOUT_MS = 5000;

procedure TFakeAMQPFrameSession.AddReply(const AFrame: TAMQPFrame);
var
  LIndex: Integer;
begin
  TMonitor.Enter(FLock);
  try
    LIndex := Length(FReplyFrames);
    SetLength(FReplyFrames, LIndex + 1);
    FReplyFrames[LIndex] := AFrame;
    FReplyAvailable.SetEvent;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TFakeAMQPFrameSession.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FReplyAvailable := TEvent.Create(nil, True, False, '');
  FConnectionId := 'fake-connection';
  FFrameMax := 8;
  FDispatchMode := cdmWorkerThread;
end;

destructor TFakeAMQPFrameSession.Destroy;
begin
  FReplyAvailable.Free;
  FLock.Free;
  inherited;
end;

function TFakeAMQPFrameSession.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function TFakeAMQPFrameSession.GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
begin
  Result := FDispatchMode;
end;

function TFakeAMQPFrameSession.GetFrameMax: UInt32;
begin
  Result := FFrameMax;
end;

function TFakeAMQPFrameSession.ReceiveExpectedMethod(
  const AClassId, AMethodId: UInt16): TAMQPFrame;
var
  LMethod: TAMQPMethodId;
begin
  Result := PopReply;
  LMethod := TAMQPMethodCodec.ReadMethodId(Result);
  if (LMethod.ClassId <> AClassId) or (LMethod.MethodId <> AMethodId) then
    raise EAMQPProtocolError.CreateFmt(
      'Fake reply method mismatch. Expected %d.%d, got %d.%d.',
      [AClassId, AMethodId, LMethod.ClassId, LMethod.MethodId]);
end;

function TFakeAMQPFrameSession.ReceiveFrame: TAMQPFrame;
begin
  Result := PopReply;
end;

function TFakeAMQPFrameSession.PopReply: TAMQPFrame;
var
  LIndex: Integer;
begin
  if FReplyAvailable.WaitFor(FAKE_RECEIVE_TIMEOUT_MS) <> wrSignaled then
    raise EAMQPProtocolError.Create('Fake frame session has no reply frame queued.');

  TMonitor.Enter(FLock);
  try
    if Length(FReplyFrames) = 0 then
      raise EAMQPProtocolError.Create('Fake frame session has no reply frame queued.');
    Result := FReplyFrames[0];
    for LIndex := 0 to High(FReplyFrames) - 1 do
      FReplyFrames[LIndex] := FReplyFrames[LIndex + 1];
    SetLength(FReplyFrames, Length(FReplyFrames) - 1);
    if Length(FReplyFrames) = 0 then
      FReplyAvailable.ResetEvent;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TFakeAMQPFrameSession.SendFrame(const AFrame: TAMQPFrame);
var
  LIndex: Integer;
  LMethod: TAMQPMethodId;
begin
  TMonitor.Enter(FLock);
  try
    LIndex := Length(FSentFrames);
    SetLength(FSentFrames, LIndex + 1);
    FSentFrames[LIndex] := AFrame;
  finally
    TMonitor.Exit(FLock);
  end;

  if AFrame.FrameType = AMQP_FRAME_METHOD then
  begin
    LMethod := TAMQPMethodCodec.ReadMethodId(AFrame);
    if (LMethod.ClassId = AMQP_CLASS_BASIC) and (LMethod.MethodId = AMQP_BASIC_CANCEL) then
      AddReply(TAMQPFrame.Create(
        AMQP_FRAME_METHOD,
        AFrame.Channel,
        TAMQPFrameCodec.MethodPayload(AMQP_CLASS_BASIC, AMQP_BASIC_CANCEL_OK)));
  end;
end;

function TFakeAMQPFrameSession.SentCount: Integer;
begin
  TMonitor.Enter(FLock);
  try
    Result := Length(FSentFrames);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TFakeAMQPFrameSession.SentFrame(const AIndex: Integer): TAMQPFrame;
begin
  TMonitor.Enter(FLock);
  try
    if (AIndex < 0) or (AIndex >= Length(FSentFrames)) then
      raise Exception.Create('Sent frame index out of range.');
    Result := FSentFrames[AIndex];
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
