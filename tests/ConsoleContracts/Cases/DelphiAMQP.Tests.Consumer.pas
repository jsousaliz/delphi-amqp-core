unit DelphiAMQP.Tests.Consumer;

interface

procedure RunConsumerTests;

implementation

uses
  System.SysUtils,
  System.SyncObjs,
  DelphiAMQP.Types,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Logging,
  DelphiAMQP.Channel,
  DelphiAMQP.Consumer,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Internal.Session,
  DelphiAMQP.Tests.Assertions,
  DelphiAMQP.Tests.FakeFrameSession,
  DelphiAMQP.Tests.FrameBuilders;

procedure TestConsumerContextManualAckNackReject;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LContext: IAMQPConsumerContext;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);
  LContext := TAMQPConsumerContext.Create(LChannel, 42, False);

  LContext.Ack;
  AssertEquals(
    AMQP_BASIC_ACK,
    TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0)).MethodId,
    'Consumer context ack method mismatch.');

  LContext.Nack(True);
  AssertEquals(
    AMQP_BASIC_NACK,
    TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(1)).MethodId,
    'Consumer context nack method mismatch.');

  LContext.Reject(False);
  AssertEquals(
    AMQP_BASIC_REJECT,
    TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(2)).MethodId,
    'Consumer context reject method mismatch.');
end;

procedure TestConsumerContextAutoAck;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LContext: IAMQPConsumerContext;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);
  LContext := TAMQPConsumerContext.Create(LChannel, 42, True);

  LContext.Ack;
  AssertEquals(0, LFake.SentCount, 'Auto-ack context must not send ack.');

  AssertRaises(EAMQPError,
    procedure
    begin
      LContext.Nack(True);
    end,
    'Auto-ack nack validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LContext.Reject(False);
    end,
    'Auto-ack reject validation failed.');
end;

procedure TestConsumerStartStopWithFakeSession;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LConsumer: IAMQPConsumer;
  LReceived: TEvent;
  LReceivedText: string;
  LProperties: TAMQPBasicProperties;
  LBody: TBytes;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);
  LReceived := TEvent.Create(nil, True, False, '');
  try
    LBody := TEncoding.UTF8.GetBytes('consumer-message');
    LProperties.ContentType := 'text/plain';
    LFake.AddReply(BuildBasicDeliverFrame(1, 'consumer-1', 42, '', 'queue.fake', False));
    LFake.AddReply(TAMQPMethodCodec.BuildContentHeader(1, Length(LBody), LProperties));
    LFake.AddReply(TAMQPFrame.Create(AMQP_FRAME_BODY, 1, LBody));

    LConsumer := TAMQPConsumer.Create(
      'queue.fake',
      'consumer-1',
      LChannel,
      LSession,
      procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
      begin
        LReceivedText := AMessage.AsText;
        AContext.Ack;
        LReceived.SetEvent;
      end,
      False,
      LLogger);

    LConsumer.Start;
    AssertTrue(LReceived.WaitFor(5000) = wrSignaled, 'Consumer fake message was not received.');
    LConsumer.Stop;

    AssertEquals('consumer-message', LReceivedText, 'Consumer received text mismatch.');
    AssertTrue(not LConsumer.IsRunning, 'Consumer must not be running after stop.');
    AssertTrue(LLogger.ContainsOperation(AMQP_LOG_CONSUMER_START), 'Consumer start log missing.');
    AssertTrue(LLogger.ContainsOperation(AMQP_LOG_CONSUMER_STOP), 'Consumer stop log missing.');
    AssertTrue(LFake.SentCount >= 2, 'Consumer should send ack and basic.cancel.');
    AssertEquals(
      AMQP_BASIC_ACK,
      TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0)).MethodId,
      'Consumer handler ack frame mismatch.');
    AssertEquals(
      AMQP_BASIC_CANCEL,
      TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(LFake.SentCount - 1)).MethodId,
      'Consumer stop cancel frame mismatch.');
  finally
    LReceived.Free;
  end;
end;

procedure TestConsumerValidation;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);

  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPConsumer.Create('', 'consumer-1', LChannel, LSession,
        procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
        begin
        end,
        False,
        LLogger);
    end,
    'Consumer empty queue validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPConsumer.Create('queue.fake', 'consumer-1', LChannel, LSession, nil, False, LLogger);
    end,
    'Consumer nil handler validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPConsumer.Create('queue.fake', 'consumer-1', LChannel, nil,
        procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
        begin
        end,
        False,
        LLogger);
    end,
    'Consumer nil session validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPConsumer.Create('queue.fake', 'consumer-1', nil, LSession,
        procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
        begin
        end,
        False,
        LLogger);
    end,
    'Consumer nil channel validation failed.');
end;

procedure RunConsumerTests;
begin
  TestConsumerContextManualAckNackReject;
  TestConsumerContextAutoAck;
  TestConsumerStartStopWithFakeSession;
  TestConsumerValidation;
end;

end.
