program DelphiAMQP.Example.ConsoleStepByStep;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows,
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
  RABBITMQ_HOST = 'localhost';
  RABBITMQ_PORT = 5672;
  RABBITMQ_VHOST = '/';
  RABBITMQ_USER = 'guest';
  RABBITMQ_PASSWORD = 'guest';
  DEMO_QUEUE = 'delphiamqp.demo';
  DEMO_MESSAGE = 'Ola do Delphi AMQP Core';
  MESSAGE_TIMEOUT_MS = 5000;

type
  TConsoleLogger = class(TInterfacedObject, IAMQPLogger)
  public
    procedure Log(const AEvent: TAMQPLogEvent);
  end;

procedure TConsoleLogger.Log(const AEvent: TAMQPLogEvent);
var
  LDuration: string;
  LOperation: string;
begin
  LOperation := AEvent.Operation;
  if LOperation.IsEmpty then
    LOperation := 'event';

  LDuration := '';
  if AEvent.DurationMS > 0 then
    LDuration := Format(' (%d ms)', [AEvent.DurationMS]);

  Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEvent.Timestamp) +
    ' [' + LOperation + '] ' + AEvent.Message + LDuration);
end;

procedure PrintConfiguration;
begin
  Writeln('Configuracao RabbitMQ local');
  Writeln(Format('Host: %s', [RABBITMQ_HOST]));
  Writeln(Format('Porta: %d', [RABBITMQ_PORT]));
  Writeln(Format('VHost: %s', [RABBITMQ_VHOST]));
  Writeln(Format('Usuario: %s', [RABBITMQ_USER]));
  Writeln(Format('Fila: %s', [DEMO_QUEUE]));
  Writeln(Format('Thread principal: %d', [GetCurrentThreadId]));
  Writeln;
end;

function BuildOptions: IAMQPConnectionOptions;
begin
  Result := TAMQPConnectionOptions.CreateDefault
    .SetHost(RABBITMQ_HOST)
    .SetPort(RABBITMQ_PORT)
    .SetVirtualHost(RABBITMQ_VHOST)
    .SetUserName(RABBITMQ_USER)
    .SetPassword(RABBITMQ_PASSWORD)
    .SetConsumerDispatchMode(cdmWorkerThread);
end;

function Connect(
  const AFactory: IAMQPConnectionFactory;
  const AOptions: IAMQPConnectionOptions): IAMQPConnection;
begin
  Writeln;
  Writeln('1. Conectando...');
  Result := AFactory.CreateConnection(AOptions);
  Result.Connect;
end;

function OpenChannel(const AConnection: IAMQPConnection): IAMQPChannel;
begin
  Writeln;
  Writeln('2. Abrindo canal...');
  Result := AConnection.CreateChannel;
end;

procedure DeclareQueue(const AChannel: IAMQPChannel);
begin
  Writeln;
  Writeln('3. Declarando fila...');
  AChannel.QueueDeclare(DEMO_QUEUE, True, False, False);
end;

function StartConsumer(
  const AChannel: IAMQPChannel;
  const AMessageReceived: TEvent): IAMQPConsumer;
begin
  Writeln;
  Writeln('4. Iniciando consumer assincrono em worker thread...');
  Result := AChannel.BasicConsume(
    DEMO_QUEUE,
    procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
    begin
      Writeln(Format(
        'Mensagem recebida na worker thread %d: %s',
        [GetCurrentThreadId, AMessage.AsText]));
      AContext.Ack;
      AMessageReceived.SetEvent;
    end,
    False);
  Result.Start;
end;

procedure PublishMessage(const AChannel: IAMQPChannel);
begin
  Writeln;
  Writeln('5. Publicando mensagem...');
  AChannel.Publish('', DEMO_QUEUE, TAMQPMessage.FromText(DEMO_MESSAGE));
end;

procedure WaitForMessage(const AMessageReceived: TEvent);
begin
  Writeln;
  Writeln('6. Aguardando consumo...');
  if AMessageReceived.WaitFor(MESSAGE_TIMEOUT_MS) <> wrSignaled then
    raise Exception.Create('Timeout waiting for consumed message.');
end;

procedure StopConsumer(var AConsumer: IAMQPConsumer);
begin
  if AConsumer = nil then
    Exit;

  Writeln;
  Writeln('7. Parando consumer...');
  AConsumer.Stop;
  AConsumer := nil;
end;

procedure CleanupQueue(const AChannel: IAMQPChannel);
begin
  Writeln;
  Writeln('8. Limpando e excluindo fila...');
  AChannel.QueuePurge(DEMO_QUEUE);
  AChannel.QueueDelete(DEMO_QUEUE);
end;

procedure Disconnect(var AConnection: IAMQPConnection);
begin
  if AConnection = nil then
    Exit;

  Writeln;
  Writeln('9. Desconectando...');
  AConnection.Disconnect;
  AConnection := nil;
end;

procedure WaitForExit;
begin
  Writeln;
  Writeln('Pressione Enter para encerrar...');
  Readln;
end;

procedure PrintCompletedFlow;
begin
  Writeln;
  Writeln('10. Fluxo concluido: connect, channel.open, queue.declare, publish, consume, ack, purge e delete.');
end;

var
  Factory: IAMQPConnectionFactory;
  Options: IAMQPConnectionOptions;
  Connection: IAMQPConnection;
  Channel: IAMQPChannel;
  Consumer: IAMQPConsumer;
  MessageReceived: TEvent;
  ProcessExitCode: Integer;
begin
  ProcessExitCode := 0;
  Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
  Options := BuildOptions;
  MessageReceived := TEvent.Create(nil, True, False, '');
  try
    try
      PrintConfiguration;
      Connection := Connect(Factory, Options);
      Channel := OpenChannel(Connection);
      DeclareQueue(Channel);
      Consumer := StartConsumer(Channel, MessageReceived);
      PublishMessage(Channel);
      WaitForMessage(MessageReceived);
      StopConsumer(Consumer);
      CleanupQueue(Channel);
      Disconnect(Connection);
      PrintCompletedFlow;
    except
      on E: Exception do
      begin
        Writeln(E.ClassName + ': ' + E.Message);
        ProcessExitCode := 1;
      end;
    end;
  finally
    StopConsumer(Consumer);
    Disconnect(Connection);
    MessageReceived.Free;
    WaitForExit;
  end;
  System.ExitCode := ProcessExitCode;
end.
