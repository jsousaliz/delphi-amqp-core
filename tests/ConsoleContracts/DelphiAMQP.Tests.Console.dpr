program DelphiAMQP.Tests.Console;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DelphiAMQP in '..\..\src\DelphiAMQP.pas',
  DelphiAMQP.Types in '..\..\src\DelphiAMQP.Types.pas',
  DelphiAMQP.Interfaces in '..\..\src\DelphiAMQP.Interfaces.pas',
  DelphiAMQP.Options in '..\..\src\DelphiAMQP.Options.pas',
  DelphiAMQP.Message in '..\..\src\DelphiAMQP.Message.pas',
  DelphiAMQP.Logging in '..\..\src\DelphiAMQP.Logging.pas',
  DelphiAMQP.Factory in '..\..\src\DelphiAMQP.Factory.pas',
  DelphiAMQP.Connection in '..\..\src\DelphiAMQP.Connection.pas',
  DelphiAMQP.Channel in '..\..\src\DelphiAMQP.Channel.pas',
  DelphiAMQP.Consumer in '..\..\src\DelphiAMQP.Consumer.pas',
  DelphiAMQP.Internal.Session in '..\..\src\DelphiAMQP.Internal.Session.pas',
  DelphiAMQP.Transport.Tcp in '..\..\src\DelphiAMQP.Transport.Tcp.pas',
  DelphiAMQP.Protocol.Frame in '..\..\src\DelphiAMQP.Protocol.Frame.pas',
  DelphiAMQP.Protocol.Methods in '..\..\src\DelphiAMQP.Protocol.Methods.pas';

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestDefaultOptions;
var
  LOptions: IAMQPConnectionOptions;
begin
  LOptions := TAMQPConnectionOptions.CreateDefault;
  AssertTrue(LOptions.Host = 'localhost', 'Default host mismatch.');
  AssertTrue(LOptions.Port = 5672, 'Default port mismatch.');
  AssertTrue(LOptions.VirtualHost = '/', 'Default virtual host mismatch.');
end;

procedure TestMessageText;
var
  LMessage: IAMQPMessage;
begin
  LMessage := TAMQPMessage.FromText('hello');
  AssertTrue(LMessage.AsText = 'hello', 'Message text mismatch.');
end;

procedure TestFrameRoundTrip;
var
  LPayload: TBytes;
  LEncoded: TBytes;
  LDecoded: TAMQPFrame;
begin
  LPayload := TAMQPFrameCodec.MethodPayload(10, 11);
  LEncoded := TAMQPFrameCodec.EncodeFrame(TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LPayload));
  LDecoded := TAMQPFrameCodec.DecodeFrame(LEncoded);

  AssertTrue(LDecoded.FrameType = AMQP_FRAME_METHOD, 'Frame type mismatch.');
  AssertTrue(LDecoded.Channel = 1, 'Frame channel mismatch.');
  AssertTrue(Length(LDecoded.Payload) = 4, 'Frame payload length mismatch.');
end;

procedure TestHandshakePayloads;
var
  LFrame: TAMQPFrame;
  LMethod: TAMQPMethodId;
begin
  LFrame := TAMQPMethodCodec.BuildConnectionStartOk('guest', 'guest');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertTrue(LMethod.ClassId = AMQP_CLASS_CONNECTION, 'start-ok class mismatch.');
  AssertTrue(LMethod.MethodId = AMQP_CONNECTION_START_OK, 'start-ok method mismatch.');

  LFrame := TAMQPMethodCodec.BuildConnectionOpen('/');
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertTrue(LMethod.MethodId = AMQP_CONNECTION_OPEN, 'connection.open method mismatch.');

  LFrame := TAMQPMethodCodec.BuildChannelOpen(1);
  AssertTrue(LFrame.Channel = 1, 'channel.open channel mismatch.');
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
  AssertTrue(LMethod.ClassId = AMQP_CLASS_QUEUE, 'queue.declare class mismatch.');
  AssertTrue(LMethod.MethodId = AMQP_QUEUE_DECLARE, 'queue.declare method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicPublish(1, '', 'queue.test', False, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertTrue(LMethod.ClassId = AMQP_CLASS_BASIC, 'basic.publish class mismatch.');
  AssertTrue(LMethod.MethodId = AMQP_BASIC_PUBLISH, 'basic.publish method mismatch.');

  LProperties.ContentType := 'text/plain';
  LFrame := TAMQPMethodCodec.BuildContentHeader(1, 5, LProperties);
  AssertTrue(LFrame.FrameType = AMQP_FRAME_HEADER, 'content header frame type mismatch.');

  LBodyFrames := TAMQPMethodCodec.BuildContentBodyFrames(1, TEncoding.UTF8.GetBytes('hello'), 2);
  AssertTrue(Length(LBodyFrames) = 3, 'content body chunk count mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicConsume(1, 'queue.test', '', False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertTrue(LMethod.MethodId = AMQP_BASIC_CONSUME, 'basic.consume method mismatch.');

  LFrame := TAMQPMethodCodec.BuildBasicAck(1, 42, False);
  LMethod := TAMQPMethodCodec.ReadMethodId(LFrame);
  AssertTrue(LMethod.MethodId = AMQP_BASIC_ACK, 'basic.ack method mismatch.');
end;

procedure TestInMemoryLogger;
var
  LLogger: TAMQPInMemoryLogger;
begin
  LLogger := TAMQPInMemoryLogger.Create;
  LLogger.Log(Default(TAMQPLogEvent));
  TAMQPLogger.Info(
    LLogger,
    lekQueue,
    'connection-id',
    1,
    'queue declared',
    AMQP_LOG_QUEUE_DECLARE);

  AssertTrue(LLogger.Count = 2, 'In-memory logger count mismatch.');
  AssertTrue(LLogger.ContainsOperation(AMQP_LOG_QUEUE_DECLARE), 'In-memory logger operation missing.');
end;

begin
  try
    TestDefaultOptions;
    TestMessageText;
    TestFrameRoundTrip;
    TestHandshakePayloads;
    TestQueueAndPublishPayloads;
    TestInMemoryLogger;
    Writeln('All contract tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
