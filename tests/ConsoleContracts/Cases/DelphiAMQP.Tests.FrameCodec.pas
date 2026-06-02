unit DelphiAMQP.Tests.FrameCodec;

interface

procedure RunFrameCodecTests;

implementation

uses
  System.SysUtils,
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame,
  DelphiAMQP.Tests.Assertions;

procedure TestFrameRoundTrip;
var
  LPayload: TBytes;
  LEncoded: TBytes;
  LDecoded: TAMQPFrame;
begin
  LPayload := TAMQPFrameCodec.MethodPayload(10, 11);
  LEncoded := TAMQPFrameCodec.EncodeFrame(TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, LPayload));
  LDecoded := TAMQPFrameCodec.DecodeFrame(LEncoded);

  AssertEquals(AMQP_FRAME_METHOD, LDecoded.FrameType, 'Frame type mismatch.');
  AssertEquals(1, LDecoded.Channel, 'Frame channel mismatch.');
  AssertEquals(4, Length(LDecoded.Payload), 'Frame payload length mismatch.');
end;

procedure TestFrameCodecValidation;
var
  LEncoded: TBytes;
begin
  AssertBytesEqual(
    TBytes.Create(Byte(Ord('A')), Byte(Ord('M')), Byte(Ord('Q')), Byte(Ord('P')), 0, 0, 9, 1),
    TAMQPFrameCodec.ProtocolHeader,
    'Protocol header mismatch.');

  AssertRaises(EAMQPProtocolError,
    procedure
    begin
      TAMQPFrameCodec.DecodeFrame(TBytes.Create(1, 0, 1));
    end,
    'Short frame validation failed.');

  LEncoded := TAMQPFrameCodec.EncodeFrame(TAMQPFrame.Create(AMQP_FRAME_METHOD, 1, TBytes.Create(1, 2)));
  LEncoded[High(LEncoded)] := 0;
  AssertRaises(EAMQPProtocolError,
    procedure
    begin
      TAMQPFrameCodec.DecodeFrame(LEncoded);
    end,
    'Invalid frame end validation failed.');

  AssertRaises(EAMQPProtocolError,
    procedure
    var
      LWriter: TAMQPBinaryWriter;
    begin
      LWriter.WriteShortString(StringOfChar('x', AMQP_SHORT_STRING_MAX_BYTES + 1));
    end,
    'Short string max length validation failed.');
end;

procedure RunFrameCodecTests;
begin
  TestFrameRoundTrip;
  TestFrameCodecValidation;
end;

end.
