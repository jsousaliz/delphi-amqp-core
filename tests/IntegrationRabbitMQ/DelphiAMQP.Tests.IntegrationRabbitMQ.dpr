program DelphiAMQP.Tests.IntegrationRabbitMQ;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.SyncObjs,
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

const
  DEFAULT_HOST = 'localhost';
  DEFAULT_PORT = 5672;
  DEFAULT_VHOST = '/';
  DEFAULT_USER = 'guest';
  DEFAULT_PASSWORD = 'guest';
  TEST_QUEUE = 'delphiamqp.integration.test';
  WAIT_TIMEOUT_MS = 5000;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function EnvOrDefault(const AName, ADefault: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result.Trim.IsEmpty then
    Result := ADefault;
end;

function EnvPortOrDefault(const AName: string; const ADefault: UInt16): UInt16;
var
  LValue: string;
  LPort: Integer;
begin
  LValue := GetEnvironmentVariable(AName);
  if LValue.Trim.IsEmpty then
    Exit(ADefault);
  LPort := StrToInt(LValue);
  if (LPort <= 0) or (LPort > High(UInt16)) then
    raise Exception.Create('Invalid AMQP_TEST_PORT value.');
  Result := UInt16(LPort);
end;

procedure RunIntegrationTest;
var
  LFactory: IAMQPConnectionFactory;
  LOptions: IAMQPConnectionOptions;
  LConnection: IAMQPConnection;
  LChannel: IAMQPChannel;
  LConsumer: IAMQPConsumer;
  LReceived: TEvent;
  LReceivedText: string;
begin
  LFactory := TAMQPConnectionFactory.Create(TAMQPLogger.Null);
  LOptions := TAMQPConnectionOptions.CreateDefault
    .SetHost(EnvOrDefault('AMQP_TEST_HOST', DEFAULT_HOST))
    .SetPort(EnvPortOrDefault('AMQP_TEST_PORT', DEFAULT_PORT))
    .SetVirtualHost(EnvOrDefault('AMQP_TEST_VHOST', DEFAULT_VHOST))
    .SetUserName(EnvOrDefault('AMQP_TEST_USER', DEFAULT_USER))
    .SetPassword(EnvOrDefault('AMQP_TEST_PASSWORD', DEFAULT_PASSWORD))
    .SetConnectionTimeoutMS(5000)
    .SetConsumerDispatchMode(cdmWorkerThread);

  LReceived := TEvent.Create(nil, True, False, '');
  try
    LConnection := LFactory.CreateConnection(LOptions);
    LConnection.Connect;
    try
      LChannel := LConnection.CreateChannel;
      LChannel.QueueDeclare(TEST_QUEUE, False, False, False);
      LChannel.QueuePurge(TEST_QUEUE);

      LConsumer := LChannel.BasicConsume(
        TEST_QUEUE,
        procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
        begin
          LReceivedText := AMessage.AsText;
          AContext.Ack;
          LReceived.SetEvent;
        end,
        False);
      LConsumer.Start;
      try
        LChannel.Publish('', TEST_QUEUE, TAMQPMessage.FromText('integration-message'));
        AssertTrue(
          LReceived.WaitFor(WAIT_TIMEOUT_MS) = wrSignaled,
          'Timed out waiting for integration message.');
        AssertTrue(LReceivedText = 'integration-message', 'Received integration payload mismatch.');
      finally
        LConsumer.Stop;
      end;

      LChannel.QueuePurge(TEST_QUEUE);
      LChannel.QueueDelete(TEST_QUEUE);
      LChannel.Close;
    finally
      LConnection.Disconnect;
    end;
  finally
    LReceived.Free;
  end;
end;

begin
  try
    RunIntegrationTest;
    Writeln('RabbitMQ integration tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Writeln('RabbitMQ integration tests require a broker available at AMQP_TEST_HOST:AMQP_TEST_PORT.');
      Halt(1);
    end;
  end;
end.
