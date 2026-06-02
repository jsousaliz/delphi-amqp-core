unit DelphiAMQP.Transport.Tcp;

interface

uses
  System.SysUtils,
  Winapi.WinSock,
  DelphiAMQP.Types;

const
  WINSOCK_VERSION_2_2 = $0202;
  MILLISECONDS_PER_SECOND = 1000;
  MICROSECONDS_PER_MILLISECOND = 1000;
  IP_ADDRESS_PARSE_ERROR = -1;

type
  TAMQPTcpTransport = class
  private
    FSocket: TSocket;
    FConnected: Boolean;
    FTimeoutMS: Cardinal;
    class procedure EnsureWinSockStarted; static;
    class function LastSocketError: string; static;
    procedure WaitReadable;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Connect(const AHost: string; const APort: UInt16; const ATimeoutMS: Cardinal);
    procedure Disconnect;
    procedure SendBytes(const ABytes: TBytes);
    function ReceiveBytes(const ACount: Integer): TBytes;
    function Connected: Boolean;
  end;

implementation

var
  GWinSockStarted: Boolean = False;

constructor TAMQPTcpTransport.Create;
begin
  inherited Create;
  FSocket := INVALID_SOCKET;
end;

destructor TAMQPTcpTransport.Destroy;
begin
  Disconnect;
  inherited;
end;

class procedure TAMQPTcpTransport.EnsureWinSockStarted;
var
  LData: WSAData;
begin
  if GWinSockStarted then
    Exit;

  if WSAStartup(WINSOCK_VERSION_2_2, LData) <> 0 then
    raise EAMQPConnectionError.Create('Could not initialize WinSock.');
  GWinSockStarted := True;
end;

class function TAMQPTcpTransport.LastSocketError: string;
begin
  Result := SysErrorMessage(WSAGetLastError);
end;

procedure TAMQPTcpTransport.Connect(
  const AHost: string;
  const APort: UInt16;
  const ATimeoutMS: Cardinal);
var
  LAddr: TSockAddrIn;
  LHostEnt: PHostEnt;
  LAddress: u_long;
  LTimeout: Integer;
begin
  if FConnected then
    Exit;

  EnsureWinSockStarted;
  FTimeoutMS := ATimeoutMS;
  FSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if FSocket = INVALID_SOCKET then
    raise EAMQPConnectionError.Create('Could not create TCP socket: ' + LastSocketError);

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);

  LAddress := inet_addr(PAnsiChar(AnsiString(AHost)));
  if LAddress = IP_ADDRESS_PARSE_ERROR then
  begin
    LHostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
    if LHostEnt = nil then
      raise EAMQPConnectionError.Create('Could not resolve host "' + AHost + '": ' + LastSocketError);
    Move(LHostEnt^.h_addr_list[0]^, LAddr.sin_addr, LHostEnt^.h_length);
  end
  else
    LAddr.sin_addr.S_addr := LAddress;

  LTimeout := Integer(ATimeoutMS);
  setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));
  setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));

  if Winapi.WinSock.connect(FSocket, LAddr, SizeOf(LAddr)) = SOCKET_ERROR then
  begin
    Disconnect;
    raise EAMQPConnectionError.Create('Could not connect to ' + AHost + ':' +
      APort.ToString + ': ' + LastSocketError);
  end;

  FConnected := True;
end;

function TAMQPTcpTransport.Connected: Boolean;
begin
  Result := FConnected;
end;

procedure TAMQPTcpTransport.Disconnect;
begin
  if FSocket <> INVALID_SOCKET then
  begin
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
  end;
  FConnected := False;
end;

function TAMQPTcpTransport.ReceiveBytes(const ACount: Integer): TBytes;
var
  LReceived: Integer;
  LTotal: Integer;
begin
  if not FConnected then
    raise EAMQPConnectionError.Create('TCP socket is not connected.');
  if ACount < 0 then
    raise EAMQPConnectionError.Create('Invalid receive byte count.');

  SetLength(Result, ACount);
  LTotal := 0;
  while LTotal < ACount do
  begin
    WaitReadable;
    LReceived := recv(FSocket, Result[LTotal], ACount - LTotal, 0);
    if LReceived = 0 then
      raise EAMQPConnectionError.Create('TCP connection was closed by the remote host.');
    if LReceived = SOCKET_ERROR then
      raise EAMQPConnectionError.Create('Could not receive from TCP socket: ' + LastSocketError);
    Inc(LTotal, LReceived);
  end;
end;

procedure TAMQPTcpTransport.SendBytes(const ABytes: TBytes);
var
  LSent: Integer;
  LTotal: Integer;
begin
  if not FConnected then
    raise EAMQPConnectionError.Create('TCP socket is not connected.');

  LTotal := 0;
  while LTotal < Length(ABytes) do
  begin
    LSent := send(FSocket, ABytes[LTotal], Length(ABytes) - LTotal, 0);
    if LSent = SOCKET_ERROR then
      raise EAMQPConnectionError.Create('Could not send to TCP socket: ' + LastSocketError);
    Inc(LTotal, LSent);
  end;
end;

procedure TAMQPTcpTransport.WaitReadable;
var
  LReadSet: TFDSet;
  LTimeout: TTimeVal;
  LResult: Integer;
begin
  FD_ZERO(LReadSet);
  FD_SET(FSocket, LReadSet);
  LTimeout.tv_sec := FTimeoutMS div MILLISECONDS_PER_SECOND;
  LTimeout.tv_usec :=
    (FTimeoutMS mod MILLISECONDS_PER_SECOND) * MICROSECONDS_PER_MILLISECOND;

  LResult := select(0, @LReadSet, nil, nil, @LTimeout);
  if LResult = SOCKET_ERROR then
    raise EAMQPConnectionError.Create('TCP select failed: ' + LastSocketError);
  if LResult = 0 then
    raise EAMQPConnectionError.Create('Timed out waiting for TCP data.');
end;

end.
