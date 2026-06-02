unit DelphiAMQP.Tests.Message;

interface

procedure RunMessageTests;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Message,
  DelphiAMQP.Tests.Assertions;

procedure TestMessageText;
var
  LMessage: IAMQPMessage;
begin
  LMessage := TAMQPMessage.FromText('hello');
  AssertEquals('hello', LMessage.AsText, 'Message text mismatch.');
end;

procedure TestMessageBytesAreCopied;
var
  LBody: TBytes;
  LReadBody: TBytes;
  LMessage: IAMQPMessage;
begin
  LBody := TBytes.Create(1, 2, 3);
  LMessage := TAMQPMessage.FromBytes(LBody);
  LBody[0] := 9;
  LReadBody := LMessage.Body;
  AssertBytesEqual(TBytes.Create(1, 2, 3), LReadBody, 'Message body copy mismatch.');
  LReadBody[1] := 9;
  AssertBytesEqual(TBytes.Create(1, 2, 3), LMessage.Body, 'Message body getter copy mismatch.');
end;

procedure TestMessageDeliveryMetadata;
var
  LBody: TBytes;
  LProperties: TAMQPBasicProperties;
  LMessage: IAMQPMessage;
begin
  LBody := TEncoding.UTF8.GetBytes('delivered');
  LProperties.ContentType := 'text/plain';
  LProperties.MessageId := 'message-1';
  LMessage := TAMQPMessage.FromDelivery(LBody, 'amq.direct', 'queue.test', 42, True, LProperties);

  AssertEquals('delivered', LMessage.AsText, 'Delivered text mismatch.');
  AssertEquals('amq.direct', LMessage.Exchange, 'Delivered exchange mismatch.');
  AssertEquals('queue.test', LMessage.RoutingKey, 'Delivered routing key mismatch.');
  AssertEqualsUInt64(42, LMessage.DeliveryTag, 'Delivered tag mismatch.');
  AssertTrue(LMessage.Redelivered, 'Delivered redelivery flag mismatch.');
  AssertEquals('text/plain', LMessage.Properties.ContentType, 'Delivered content type mismatch.');
  AssertEquals('message-1', LMessage.Properties.MessageId, 'Delivered message id mismatch.');
end;

procedure RunMessageTests;
begin
  TestMessageText;
  TestMessageBytesAreCopied;
  TestMessageDeliveryMetadata;
end;

end.
