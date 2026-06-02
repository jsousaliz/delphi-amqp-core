unit DelphiAMQP.Tests.MethodCodec;

interface

procedure RunMethodCodecTests;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Protocol.Methods,
  DelphiAMQP.Tests.Assertions;

procedure TestHandshakePayloads;
var
  LFrame: TAMQPFrame;
  LMethod: TAMQPMethodId;
  LStart: TAMQPConnectionStart;
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_START);
  LWriter.WriteUInt8(0);
  LWriter.WriteUInt8(9);
  LWriter.WriteUInt32(0);
  LWriter.WriteLongString(TEncoding.UTF8.GetBytes('AMQPLAIN PLAIN'));
  LWriter.WriteLongString(TEncoding.UTF8.GetBytes('en_US pt_BR'));
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
  LStart := TAMQPMethodCodec.ReadConnectionStart(LFrame);
  AssertEquals(0, LStart.VersionMajor, 'connection.start major version mismatch.');
  AssertEquals(9, LStart.VersionMinor, 'connection.start minor version mismatch.');
  AssertEquals('AMQPLAIN PLAIN', LStart.Mechanisms, 'connection.start mechanisms mismatch.');
  AssertEquals('en_US pt_BR', LStart.Locales, 'connection.start locales mismatch.');
  AssertTrue(LStart.SupportsMechanism(AMQP_SASL_MECHANISM_PLAIN), 'connection.start PLAIN support missing.');
  AssertTrue(not LStart.SupportsMechanism('EXTERNAL'), 'connection.start mechanism false positive.');
  AssertTrue(LStart.SupportsLocale(AMQP_LOCALE_EN_US), 'connection.start en_US support missing.');
  AssertTrue(not LStart.SupportsLocale('fr_FR'), 'connection.start locale false positive.');

  LFrame := TAMQPMethodCodec.BuildConnectionStartOk('guest', 'guest');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CLASS_CONNECTION, LMethod.ClassId, 'start-ok class mismatch.');
  AssertEquals(AMQP_CONNECTION_START_OK, LMethod.MethodId, 'start-ok method mismatch.');

  LFrame := TAMQPMethodCodec.BuildConnectionOpen('/');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CONNECTION_OPEN, LMethod.MethodId, 'connection.open method mismatch.');

  LFrame := TAMQPMethodCodec.BuildChannelOpen(1);
  AssertEquals(1, LFrame.Channel, 'channel.open channel mismatch.');

  LFrame := TAMQPMethodCodec.BuildChannelClose(1);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CLASS_CHANNEL, LMethod.ClassId, 'channel.close class mismatch.');
  AssertEquals(AMQP_CHANNEL_CLOSE, LMethod.MethodId, 'channel.close method mismatch.');
end;

procedure TestConnectionTuneRoundTrip;
var
  LTune: TAMQPConnectionTune;
  LFrame: TAMQPFrame;
  LReadTune: TAMQPConnectionTune;
  LMethod: TAMQPMethodId;
begin
  LTune.ChannelMax := 10;
  LTune.FrameMax := 4096;
  LTune.Heartbeat := 30;

  LFrame := TAMQPFrame.Create(
    AMQP_FRAME_METHOD,
    AMQP_CONNECTION_CHANNEL,
    TAMQPFrameCodec.MethodPayload(AMQP_CLASS_CONNECTION, AMQP_CONNECTION_TUNE) +
      TBytes.Create(0, 10, 0, 0, 16, 0, 0, 30));
  LReadTune := TAMQPMethodCodec.ReadConnectionTune(LFrame);
  AssertEquals(10, LReadTune.ChannelMax, 'connection.tune channel max mismatch.');
  AssertEquals(4096, LReadTune.FrameMax, 'connection.tune frame max mismatch.');
  AssertEquals(30, LReadTune.Heartbeat, 'connection.tune heartbeat mismatch.');

  LFrame := TAMQPMethodCodec.BuildConnectionTuneOk(LTune);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CONNECTION_TUNE_OK, LMethod.MethodId, 'connection.tune-ok method mismatch.');
end;

procedure TestQueueAndPublishPayloads;
var
  LFrame: TAMQPFrame;
  LMethod: TAMQPMethodId;
  LBodyFrames: TArray<TAMQPFrame>;
  LProperties: TAMQPBasicProperties;
begin
  LFrame := TAMQPMethodCodec.BuildQueueDeclare(1, 'queue.test', True, False, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CLASS_QUEUE, LMethod.ClassId, 'queue.declare class mismatch.');
  AssertEquals(AMQP_QUEUE_DECLARE, LMethod.MethodId, 'queue.declare method mismatch.');

  LFrame := TAMQPMethodCodec.BuildQueueDelete(1, 'queue.test', True, True);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_QUEUE_DELETE, LMethod.MethodId, 'queue.delete method mismatch.');

  LFrame := TAMQPMethodCodec.BuildQueuePurge(1, 'queue.test');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_QUEUE_PURGE, LMethod.MethodId, 'queue.purge method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicPublish(1, '', 'queue.test', False, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_CLASS_BASIC, LMethod.ClassId, 'basic.publish class mismatch.');
  AssertEquals(AMQP_BASIC_PUBLISH, LMethod.MethodId, 'basic.publish method mismatch.');

  LProperties.ContentType := 'text/plain';
  LProperties.ContentEncoding := 'utf-8';
  LProperties.DeliveryMode := 2;
  LProperties.Priority := 1;
  LProperties.CorrelationId := 'correlation-1';
  LProperties.ReplyTo := 'reply.queue';
  LProperties.Expiration := '60000';
  LProperties.MessageId := 'message-1';
  LProperties.Timestamp := EncodeDate(2026, 6, 2);
  LProperties.AppId := 'tests';
  LFrame := TAMQPMethodCodec.BuildContentHeader(1, 5, LProperties);
  AssertEquals(AMQP_FRAME_HEADER, LFrame.FrameType, 'content header frame type mismatch.');
  AssertEquals('text/plain', TAMQPMethodCodec.ReadContentHeader(LFrame).Properties.ContentType, 'content header content type mismatch.');
  AssertEquals('utf-8', TAMQPMethodCodec.ReadContentHeader(LFrame).Properties.ContentEncoding, 'content header encoding mismatch.');
  AssertEquals(2, TAMQPMethodCodec.ReadContentHeader(LFrame).Properties.DeliveryMode, 'content header delivery mode mismatch.');

  LBodyFrames := TAMQPMethodCodec.BuildContentBodyFrames(1, TEncoding.UTF8.GetBytes('hello'), 2);
  AssertEquals(3, Length(LBodyFrames), 'content body chunk count mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicConsume(1, 'queue.test', '', False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_BASIC_CONSUME, LMethod.MethodId, 'basic.consume method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicCancel(1, 'consumer-1');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_BASIC_CANCEL, LMethod.MethodId, 'basic.cancel method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicAck(1, 42, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_BASIC_ACK, LMethod.MethodId, 'basic.ack method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicNack(1, 42, False, True);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_BASIC_NACK, LMethod.MethodId, 'basic.nack method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicReject(1, 42, True);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertEquals(AMQP_BASIC_REJECT, LMethod.MethodId, 'basic.reject method mismatch.');

  AssertRaises(EAMQPProtocolError,
    procedure
    begin
      TAMQPMethodCodec.BuildContentBodyFrames(1, TBytes.Create(1), 0);
    end,
    'Content body max payload validation failed.');
end;

procedure TestMethodReaders;
var
  LWriter: TAMQPBinaryWriter;
  LFrame: TAMQPFrame;
  LQueueDeclare: TAMQPQueueDeclareOk;
  LDeliver: TAMQPBasicDeliver;
  LConnectionClose: TAMQPConnectionClose;
  LClose: TAMQPChannelClose;
begin
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DECLARE_OK);
  LWriter.WriteShortString('queue.test');
  LWriter.WriteUInt32(7);
  LWriter.WriteUInt32(2);
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  LQueueDeclare := TAMQPMethodCodec.ReadQueueDeclareOk(LFrame);
  AssertEquals('queue.test', LQueueDeclare.QueueName, 'queue.declare-ok queue name mismatch.');
  AssertEquals(7, LQueueDeclare.MessageCount, 'queue.declare-ok message count mismatch.');
  AssertEquals(2, LQueueDeclare.ConsumerCount, 'queue.declare-ok consumer count mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DELETE_OK);
  LWriter.WriteUInt32(3);
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  AssertEquals(3, TAMQPMethodCodec.ReadQueueDeleteOk(LFrame), 'queue.delete-ok count mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_PURGE_OK);
  LWriter.WriteUInt32(4);
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  AssertEquals(4, TAMQPMethodCodec.ReadQueuePurgeOk(LFrame), 'queue.purge-ok count mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_CONSUME_OK);
  LWriter.WriteShortString('consumer-1');
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  AssertEquals('consumer-1', TAMQPMethodCodec.ReadBasicConsumeOk(LFrame), 'basic.consume-ok tag mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_BASIC);
  LWriter.WriteUInt16(AMQP_BASIC_DELIVER);
  LWriter.WriteShortString('consumer-1');
  LWriter.WriteUInt64(42);
  LWriter.WriteUInt8(1);
  LWriter.WriteShortString('exchange');
  LWriter.WriteShortString('queue.test');
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  LDeliver := TAMQPMethodCodec.ReadBasicDeliver(LFrame);
  AssertEquals('consumer-1', LDeliver.ConsumerTag, 'basic.deliver consumer tag mismatch.');
  AssertEqualsUInt64(42, LDeliver.DeliveryTag, 'basic.deliver delivery tag mismatch.');
  AssertTrue(LDeliver.Redelivered, 'basic.deliver redelivered mismatch.');
  AssertEquals('exchange', LDeliver.Exchange, 'basic.deliver exchange mismatch.');
  AssertEquals('queue.test', LDeliver.RoutingKey, 'basic.deliver routing key mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_CLOSE);
  LWriter.WriteUInt16(403);
  LWriter.WriteShortString('ACCESS_REFUSED');
  LWriter.WriteUInt16(AMQP_CLASS_CONNECTION);
  LWriter.WriteUInt16(AMQP_CONNECTION_OPEN);
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, AMQP_CONNECTION_CHANNEL, LWriter.ToBytes);
  LConnectionClose := TAMQPMethodCodec.ReadConnectionClose(LFrame);
  AssertEquals(403, LConnectionClose.ReplyCode, 'connection.close reply code mismatch.');
  AssertEquals('ACCESS_REFUSED', LConnectionClose.ReplyText, 'connection.close reply text mismatch.');
  AssertEquals(AMQP_CLASS_CONNECTION, LConnectionClose.ClassId, 'connection.close class id mismatch.');
  AssertEquals(AMQP_CONNECTION_OPEN, LConnectionClose.MethodId, 'connection.close method id mismatch.');

  LWriter := Default(TAMQPBinaryWriter);
  LWriter.WriteUInt16(AMQP_CLASS_CHANNEL);
  LWriter.WriteUInt16(AMQP_CHANNEL_CLOSE);
  LWriter.WriteUInt16(404);
  LWriter.WriteShortString('NOT_FOUND');
  LWriter.WriteUInt16(AMQP_CLASS_QUEUE);
  LWriter.WriteUInt16(AMQP_QUEUE_DECLARE);
  LFrame := TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LWriter.ToBytes);
  LClose := TAMQPMethodCodec.ReadChannelClose(LFrame);
  AssertEquals(404, LClose.ReplyCode, 'channel.close reply code mismatch.');
  AssertEquals('NOT_FOUND', LClose.ReplyText, 'channel.close reply text mismatch.');
  AssertEquals(AMQP_CLASS_QUEUE, LClose.ClassId, 'channel.close class id mismatch.');
  AssertEquals(AMQP_QUEUE_DECLARE, LClose.MethodId, 'channel.close method id mismatch.');

  AssertRaises(EAMQPProtocolError,
    procedure
    begin
      TAMQPMethodCodec.ReadQueueDeclareOk(TAMQPMethodCodec.BuildBasicAck(1, 1, False));
    end,
    'Reader expected-method validation failed.');
end;

procedure TestTypedCloseExceptions;
var
  LConnectionError: EAMQPConnectionClosedError;
  LChannelError: EAMQPChannelClosedError;
begin
  LConnectionError := EAMQPConnectionClosedError.Create(
    403,
    'ACCESS_REFUSED',
    AMQP_CLASS_CONNECTION,
    AMQP_CONNECTION_OPEN);
  try
    AssertEquals(403, LConnectionError.ReplyCode, 'connection close exception reply code mismatch.');
    AssertEquals('ACCESS_REFUSED', LConnectionError.ReplyText, 'connection close exception reply text mismatch.');
    AssertEquals(AMQP_CLASS_CONNECTION, LConnectionError.ClassId, 'connection close exception class id mismatch.');
    AssertEquals(AMQP_CONNECTION_OPEN, LConnectionError.MethodId, 'connection close exception method id mismatch.');
    AssertTrue(Pos('403 ACCESS_REFUSED', LConnectionError.Message) > 0, 'connection close exception message mismatch.');
  finally
    LConnectionError.Free;
  end;

  LChannelError := EAMQPChannelClosedError.Create(
    1,
    404,
    'NOT_FOUND',
    AMQP_CLASS_QUEUE,
    AMQP_QUEUE_DECLARE);
  try
    AssertEquals(1, LChannelError.ChannelId, 'channel close exception channel id mismatch.');
    AssertEquals(404, LChannelError.ReplyCode, 'channel close exception reply code mismatch.');
    AssertEquals('NOT_FOUND', LChannelError.ReplyText, 'channel close exception reply text mismatch.');
    AssertEquals(AMQP_CLASS_QUEUE, LChannelError.ClassId, 'channel close exception class id mismatch.');
    AssertEquals(AMQP_QUEUE_DECLARE, LChannelError.MethodId, 'channel close exception method id mismatch.');
    AssertTrue(Pos('404 NOT_FOUND', LChannelError.Message) > 0, 'channel close exception message mismatch.');
  finally
    LChannelError.Free;
  end;
end;

procedure RunMethodCodecTests;
begin
  TestHandshakePayloads;
  TestConnectionTuneRoundTrip;
  TestQueueAndPublishPayloads;
  TestMethodReaders;
  TestTypedCloseExceptions;
end;

end.
