unit DelphiAMQP.Protocol.Frame;

interface

uses
  System.SysUtils,
  DelphiAMQP.Types;

const
  AMQP_PROTOCOL_ID = 0;
  AMQP_PROTOCOL_MAJOR = 0;
  AMQP_PROTOCOL_MINOR = 9;
  AMQP_PROTOCOL_REVISION = 1;

  AMQP_FRAME_METHOD = 1;
  AMQP_FRAME_HEADER = 2;
  AMQP_FRAME_BODY = 3;
  AMQP_FRAME_HEARTBEAT = 8;
  AMQP_FRAME_END = $CE;
  AMQP_FRAME_HEADER_SIZE = 7;
  AMQP_FRAME_MIN_SIZE = AMQP_FRAME_HEADER_SIZE + 1;
  AMQP_FRAME_END_SIZE = 1;

  AMQP_FRAME_TYPE_OFFSET = 0;
  AMQP_FRAME_CHANNEL_OFFSET = 1;
  AMQP_FRAME_PAYLOAD_SIZE_OFFSET = 3;
  AMQP_FRAME_PAYLOAD_OFFSET = 7;
  AMQP_FRAME_PAYLOAD_SIZE_FIELD_SIZE = 4;
  AMQP_SHORT_STRING_MAX_BYTES = 255;
  AMQP_OCTET_SIZE = 1;
  AMQP_SHORT_SIZE = 2;
  AMQP_LONG_SIZE = 4;
  AMQP_LONG_LONG_SIZE = 8;
  AMQP_LONG_BYTE_1_OFFSET = 1;
  AMQP_LONG_BYTE_2_OFFSET = 2;
  AMQP_LONG_BYTE_3_OFFSET = 3;

  AMQP_DEFAULT_FRAME_MAX = 131072;
  AMQP_NO_CHANNEL_MAX = 0;
  AMQP_CONNECTION_CHANNEL = 0;
  AMQP_FIRST_APPLICATION_CHANNEL = 1;

type
  TAMQPFrame = record
    FrameType: Byte;
    Channel: UInt16;
    Payload: TBytes;
    class function Create(
      const AFrameType: Byte;
      const AChannel: UInt16;
      const APayload: TBytes): TAMQPFrame; static;
  end;

  TAMQPBinaryWriter = record
  private
    FBuffer: TBytes;
    procedure AppendByte(const AValue: Byte);
  public
    procedure WriteUInt8(const AValue: Byte);
    procedure WriteUInt16(const AValue: UInt16);
    procedure WriteUInt32(const AValue: UInt32);
    procedure WriteUInt64(const AValue: UInt64);
    procedure WriteShortString(const AValue: string);
    procedure WriteLongString(const AValue: TBytes);
    procedure WriteBytes(const AValue: TBytes);
    function ToBytes: TBytes;
  end;

  TAMQPBinaryReader = record
  private
    FBuffer: TBytes;
    FOffset: Integer;
    procedure RequireAvailable(const ACount: Integer);
  public
    constructor Create(const ABuffer: TBytes);
    function ReadUInt8: Byte;
    function ReadUInt16: UInt16;
    function ReadUInt32: UInt32;
    function ReadUInt64: UInt64;
    function ReadShortString: string;
    function ReadLongString: TBytes;
    function ReadBytes(const ACount: Integer): TBytes;
    function Remaining: Integer;
  end;

  TAMQPFrameCodec = class
  public
    class function EncodeFrame(const AFrame: TAMQPFrame): TBytes; static;
    class function DecodeFrame(const ABytes: TBytes): TAMQPFrame; static;
    class function MethodPayload(const AClassId, AMethodId: UInt16): TBytes; static;
    class function ProtocolHeader: TBytes; static;
  end;

implementation

class function TAMQPFrame.Create(
  const AFrameType: Byte;
  const AChannel: UInt16;
  const APayload: TBytes): TAMQPFrame;
begin
  Result.FrameType := AFrameType;
  Result.Channel := AChannel;
  Result.Payload := Copy(APayload);
end;

procedure TAMQPBinaryWriter.AppendByte(const AValue: Byte);
var
  LLength: Integer;
begin
  LLength := Length(FBuffer);
  SetLength(FBuffer, LLength + 1);
  FBuffer[LLength] := AValue;
end;

function TAMQPBinaryWriter.ToBytes: TBytes;
begin
  Result := Copy(FBuffer);
end;

procedure TAMQPBinaryWriter.WriteBytes(const AValue: TBytes);
var
  LLength: Integer;
begin
  LLength := Length(FBuffer);
  SetLength(FBuffer, LLength + Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[0], FBuffer[LLength], Length(AValue));
end;

procedure TAMQPBinaryWriter.WriteLongString(const AValue: TBytes);
begin
  WriteUInt32(Length(AValue));
  WriteBytes(AValue);
end;

procedure TAMQPBinaryWriter.WriteShortString(const AValue: string);
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  if Length(LBytes) > AMQP_SHORT_STRING_MAX_BYTES then
    raise EAMQPProtocolError.CreateFmt(
      'AMQP short string cannot exceed %d bytes.',
      [AMQP_SHORT_STRING_MAX_BYTES]);
  WriteUInt8(Length(LBytes));
  WriteBytes(LBytes);
end;

procedure TAMQPBinaryWriter.WriteUInt16(const AValue: UInt16);
begin
  AppendByte(Byte((AValue shr 8) and $FF));
  AppendByte(Byte(AValue and $FF));
end;

procedure TAMQPBinaryWriter.WriteUInt32(const AValue: UInt32);
begin
  AppendByte(Byte((AValue shr 24) and $FF));
  AppendByte(Byte((AValue shr 16) and $FF));
  AppendByte(Byte((AValue shr 8) and $FF));
  AppendByte(Byte(AValue and $FF));
end;

procedure TAMQPBinaryWriter.WriteUInt64(const AValue: UInt64);
begin
  WriteUInt32(UInt32((AValue shr 32) and $FFFFFFFF));
  WriteUInt32(UInt32(AValue and $FFFFFFFF));
end;

procedure TAMQPBinaryWriter.WriteUInt8(const AValue: Byte);
begin
  AppendByte(AValue);
end;

constructor TAMQPBinaryReader.Create(const ABuffer: TBytes);
begin
  FBuffer := Copy(ABuffer);
  FOffset := 0;
end;

function TAMQPBinaryReader.ReadBytes(const ACount: Integer): TBytes;
begin
  if ACount < 0 then
    raise EAMQPProtocolError.Create('Invalid byte count.');
  RequireAvailable(ACount);
  SetLength(Result, ACount);
  if ACount > 0 then
    Move(FBuffer[FOffset], Result[0], ACount);
  Inc(FOffset, ACount);
end;

function TAMQPBinaryReader.ReadLongString: TBytes;
var
  LLength: UInt32;
begin
  LLength := ReadUInt32;
  if LLength > UInt32(MaxInt) then
    raise EAMQPProtocolError.Create('AMQP long string is too large.');
  Result := ReadBytes(Integer(LLength));
end;

function TAMQPBinaryReader.ReadShortString: string;
var
  LLength: Byte;
  LBytes: TBytes;
begin
  LLength := ReadUInt8;
  LBytes := ReadBytes(LLength);
  Result := TEncoding.UTF8.GetString(LBytes);
end;

function TAMQPBinaryReader.ReadUInt16: UInt16;
begin
  RequireAvailable(AMQP_SHORT_SIZE);
  Result :=
    (UInt16(FBuffer[FOffset]) shl 8) or
    UInt16(FBuffer[FOffset + AMQP_OCTET_SIZE]);
  Inc(FOffset, AMQP_SHORT_SIZE);
end;

function TAMQPBinaryReader.ReadUInt32: UInt32;
begin
  RequireAvailable(AMQP_LONG_SIZE);
  Result :=
    (UInt32(FBuffer[FOffset]) shl 24) or
    (UInt32(FBuffer[FOffset + AMQP_LONG_BYTE_1_OFFSET]) shl 16) or
    (UInt32(FBuffer[FOffset + AMQP_LONG_BYTE_2_OFFSET]) shl 8) or
    UInt32(FBuffer[FOffset + AMQP_LONG_BYTE_3_OFFSET]);
  Inc(FOffset, AMQP_LONG_SIZE);
end;

function TAMQPBinaryReader.ReadUInt64: UInt64;
var
  LHigh: UInt64;
  LLow: UInt64;
begin
  LHigh := ReadUInt32;
  LLow := ReadUInt32;
  Result := (LHigh shl 32) or LLow;
end;

function TAMQPBinaryReader.ReadUInt8: Byte;
begin
  RequireAvailable(AMQP_OCTET_SIZE);
  Result := FBuffer[FOffset];
  Inc(FOffset);
end;

function TAMQPBinaryReader.Remaining: Integer;
begin
  Result := Length(FBuffer) - FOffset;
end;

procedure TAMQPBinaryReader.RequireAvailable(const ACount: Integer);
begin
  if Remaining < ACount then
    raise EAMQPProtocolError.Create('Unexpected end of AMQP frame payload.');
end;

class function TAMQPFrameCodec.DecodeFrame(const ABytes: TBytes): TAMQPFrame;
var
  LReader: TAMQPBinaryReader;
  LSize: UInt32;
  LEnd: Byte;
begin
  if Length(ABytes) < AMQP_FRAME_MIN_SIZE then
    raise EAMQPProtocolError.CreateFmt(
      'AMQP frame must have at least %d bytes.',
      [AMQP_FRAME_MIN_SIZE]);

  LReader := TAMQPBinaryReader.Create(ABytes);
  Result.FrameType := LReader.ReadUInt8;
  Result.Channel := LReader.ReadUInt16;
  LSize := LReader.ReadUInt32;
  if LSize > UInt32(MaxInt) then
    raise EAMQPProtocolError.Create('AMQP frame payload is too large.');

  Result.Payload := LReader.ReadBytes(Integer(LSize));
  LEnd := LReader.ReadUInt8;
  if LEnd <> AMQP_FRAME_END then
    raise EAMQPProtocolError.Create('Invalid AMQP frame end marker.');
  if LReader.Remaining <> 0 then
    raise EAMQPProtocolError.Create('Unexpected bytes after AMQP frame.');
end;

class function TAMQPFrameCodec.EncodeFrame(const AFrame: TAMQPFrame): TBytes;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt8(AFrame.FrameType);
  LWriter.WriteUInt16(AFrame.Channel);
  LWriter.WriteUInt32(Length(AFrame.Payload));
  LWriter.WriteBytes(AFrame.Payload);
  LWriter.WriteUInt8(AMQP_FRAME_END);
  Result := LWriter.ToBytes;
end;

class function TAMQPFrameCodec.MethodPayload(const AClassId, AMethodId: UInt16): TBytes;
var
  LWriter: TAMQPBinaryWriter;
begin
  LWriter.WriteUInt16(AClassId);
  LWriter.WriteUInt16(AMethodId);
  Result := LWriter.ToBytes;
end;

class function TAMQPFrameCodec.ProtocolHeader: TBytes;
begin
  Result := TBytes.Create(
    Byte(Ord('A')),
    Byte(Ord('M')),
    Byte(Ord('Q')),
    Byte(Ord('P')),
    AMQP_PROTOCOL_ID,
    AMQP_PROTOCOL_MAJOR,
    AMQP_PROTOCOL_MINOR,
    AMQP_PROTOCOL_REVISION);
end;

end.
