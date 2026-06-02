unit DelphiAMQP.Tests.Assertions;

interface

uses
  System.SysUtils;

type
  TTestProc = reference to procedure;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
procedure AssertEquals(const AExpected, AActual: string; const AMessage: string); overload;
procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string); overload;
procedure AssertEqualsUInt64(const AExpected, AActual: UInt64; const AMessage: string);
procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
procedure AssertRaises(
  const AExceptionClass: ExceptClass;
  const AProc: TTestProc;
  const AMessage: string);

implementation

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected <> AActual then
    raise Exception.CreateFmt('%s Expected "%s", got "%s".', [AMessage, AExpected, AActual]);
end;

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
    raise Exception.CreateFmt('%s Expected %d, got %d.', [AMessage, AExpected, AActual]);
end;

procedure AssertEqualsUInt64(const AExpected, AActual: UInt64; const AMessage: string);
begin
  if AExpected <> AActual then
    raise Exception.CreateFmt('%s Expected %d, got %d.', [AMessage, AExpected, AActual]);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  LIndex: Integer;
begin
  AssertEquals(Length(AExpected), Length(AActual), AMessage + ' Length mismatch.');
  for LIndex := 0 to High(AExpected) do
    if AExpected[LIndex] <> AActual[LIndex] then
      raise Exception.CreateFmt('%s Byte mismatch at %d.', [AMessage, LIndex]);
end;

procedure AssertRaises(
  const AExceptionClass: ExceptClass;
  const AProc: TTestProc;
  const AMessage: string);
begin
  try
    AProc;
  except
    on E: Exception do
    begin
      if E.InheritsFrom(AExceptionClass) then
        Exit;
      raise Exception.CreateFmt(
        '%s Expected %s, got %s.',
        [AMessage, AExceptionClass.ClassName, E.ClassName]);
    end;
  end;
  raise Exception.CreateFmt('%s Expected %s, but no exception was raised.', [AMessage, AExceptionClass.ClassName]);
end;

end.
