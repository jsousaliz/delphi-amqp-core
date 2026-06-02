unit DelphiAMQP.Tests.Channel;

interface

procedure RunChannelTests;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Message,
  DelphiAMQP.Logging,
  DelphiAMQP.Channel,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Internal.Session,
  DelphiAMQP.Tests.Assertions,
  DelphiAMQP.Tests.FakeFrameSession,
  DelphiAMQP.Tests.FrameBuilders;

function HasTimedEvent(
  const ALogger: TAMQPInMemoryLogger;
  const AOperation: string;
  const AMessagePart: string): Boolean;
var
  LEvent: TAMQPLogEvent;
begin
  Result := False;
  for LEvent in ALogger.Events do
    if SameText(LEvent.Operation, AOperation) and
       (Pos(AMessagePart, LEvent.Message) > 0) then
      Exit(True);
end;

procedure TestChannelQueueOperationsWithFakeSession;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LResult: TAMQPQueueDeclareResult;
  LMethod: TAMQPMethodId;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);

  LFake.AddReply(BuildQueueDeclareOkFrame(1, 'queue.fake', 5, 2));
  LResult := LChannel.QueueDeclare('queue.fake', True, False, False);
  AssertEquals('queue.fake', LResult.QueueName, 'Channel queue.declare result queue mismatch.');
  AssertEquals(5, LResult.MessageCount, 'Channel queue.declare result message count mismatch.');
  AssertEquals(2, LResult.ConsumerCount, 'Channel queue.declare result consumer count mismatch.');
  AssertEquals(1, LFake.SentCount, 'Channel queue.declare sent count mismatch.');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0));
  AssertEquals(AMQP_QUEUE_DECLARE, LMethod.MethodId, 'Channel queue.declare method mismatch.');

  LFake.AddReply(BuildQueuePurgeOkFrame(1, 5));
  LChannel.QueuePurge('queue.fake');
  AssertEquals(2, LFake.SentCount, 'Channel queue.purge sent count mismatch.');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(1));
  AssertEquals(AMQP_QUEUE_PURGE, LMethod.MethodId, 'Channel queue.purge method mismatch.');

  LFake.AddReply(BuildQueueDeleteOkFrame(1, 0));
  LChannel.QueueDelete('queue.fake');
  AssertEquals(3, LFake.SentCount, 'Channel queue.delete sent count mismatch.');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(2));
  AssertEquals(AMQP_QUEUE_DELETE, LMethod.MethodId, 'Channel queue.delete method mismatch.');

  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_QUEUE_DECLARE), 'Channel queue.declare log missing.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_QUEUE_PURGE), 'Channel queue.purge log missing.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_QUEUE_DELETE), 'Channel queue.delete log missing.');
  AssertTrue(HasTimedEvent(LLogger, AMQP_LOG_QUEUE_DECLARE, 'completed'), 'Channel queue.declare duration log missing.');
  AssertTrue(HasTimedEvent(LLogger, AMQP_LOG_QUEUE_PURGE, 'completed'), 'Channel queue.purge duration log missing.');
  AssertTrue(HasTimedEvent(LLogger, AMQP_LOG_QUEUE_DELETE, 'completed'), 'Channel queue.delete duration log missing.');
end;

procedure TestChannelPublishAndAckWithFakeSession;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LMethod: TAMQPMethodId;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);

  LChannel.Publish('', 'queue.fake', TAMQPMessage.FromText('hello world'));
  AssertEquals(4, LFake.SentCount, 'Channel publish frame count mismatch.');

  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0));
  AssertEquals(AMQP_BASIC_PUBLISH, LMethod.MethodId, 'Channel publish method mismatch.');
  AssertEquals(AMQP_FRAME_HEADER, LFake.SentFrame(1).FrameType, 'Channel publish content header mismatch.');
  AssertEquals(AMQP_FRAME_BODY, LFake.SentFrame(2).FrameType, 'Channel publish first body frame mismatch.');
  AssertEquals(AMQP_FRAME_BODY, LFake.SentFrame(3).FrameType, 'Channel publish second body frame mismatch.');

  LChannel.BasicAck(42);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(4));
  AssertEquals(AMQP_BASIC_ACK, LMethod.MethodId, 'Channel basic.ack method mismatch.');

  LChannel.BasicNack(43, False, True);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(5));
  AssertEquals(AMQP_BASIC_NACK, LMethod.MethodId, 'Channel basic.nack method mismatch.');

  LChannel.BasicReject(44, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(6));
  AssertEquals(AMQP_BASIC_REJECT, LMethod.MethodId, 'Channel basic.reject method mismatch.');

  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_BASIC_PUBLISH), 'Channel publish log missing.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_BASIC_ACK), 'Channel ack log missing.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_BASIC_NACK), 'Channel nack log missing.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_BASIC_REJECT), 'Channel reject log missing.');
end;

procedure TestChannelConsumeAndValidationWithFakeSession;
var
  LFake: TFakeAMQPFrameSession;
  LSession: IAMQPFrameSession;
  LLogger: TAMQPInMemoryLogger;
  LChannel: IAMQPChannel;
  LConsumer: IAMQPConsumer;
begin
  LFake := TFakeAMQPFrameSession.Create;
  LSession := LFake as IAMQPFrameSession;
  LLogger := TAMQPInMemoryLogger.Create;
  LChannel := TAMQPChannel.Create(1, LLogger, LSession);

  LFake.AddReply(BuildBasicConsumeOkFrame(1, 'consumer-1'));
  LConsumer := LChannel.BasicConsume(
    'queue.fake',
    procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
    begin
    end);
  AssertEquals('queue.fake', LConsumer.QueueName, 'Consumer queue name mismatch.');
  AssertEquals(1, LFake.SentCount, 'Channel basic.consume sent count mismatch.');
  AssertEquals(
    AMQP_BASIC_CONSUME,
    TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0)).MethodId,
    'Channel basic.consume method mismatch.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_BASIC_CONSUME), 'Channel basic.consume log missing.');
  AssertTrue(HasTimedEvent(LLogger, AMQP_LOG_BASIC_CONSUME, 'opened'), 'Channel basic.consume duration log missing.');

  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.QueueDeclare('');
    end,
    'Channel empty queue declare validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.QueuePurge('');
    end,
    'Channel empty queue purge validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.QueueDelete('');
    end,
    'Channel empty queue delete validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.BasicConsume('', nil);
    end,
    'Channel empty basic.consume validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.Publish('', 'queue.fake', nil);
    end,
    'Channel nil message validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      LChannel.Publish('', '', TAMQPMessage.FromText('message'));
    end,
    'Channel empty routing validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPChannel.Create(0, LLogger, LSession);
    end,
    'Channel id validation failed.');
  AssertRaises(EAMQPError,
    procedure
    begin
      TAMQPChannel.Create(1, LLogger, nil);
    end,
    'Channel nil session validation failed.');
end;

procedure TestChannelCloseWithFakeSession;
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

  LFake.AddReply(TAMQPFrame.Create(
    AMQP_FRAME_METHOD,
    1,
    TAMQPFrameCodec.MethodPayload(AMQP_CLASS_CHANNEL, AMQP_CHANNEL_CLOSE_OK)));
  LChannel.Close;

  AssertEquals(
    AMQP_CHANNEL_CLOSE,
    TAMQPMethodCodec.ReadMethodId(LFake.SentFrame(0)).MethodId,
    'Channel close method mismatch.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_CHANNEL_CLOSE), 'Channel close log missing.');
end;

procedure RunChannelTests;
begin
  TestChannelQueueOperationsWithFakeSession;
  TestChannelPublishAndAckWithFakeSession;
  TestChannelConsumeAndValidationWithFakeSession;
  TestChannelCloseWithFakeSession;
end;

end.
