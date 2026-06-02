program DelphiAMQP.Example.ConsoleQuickStart;

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

type
  TConsoleLogger = class(TInterfacedObject, IAMQPLogger)
  public
    procedure Log(const AEvent: TAMQPLogEvent);
  end;

procedure TConsoleLogger.Log(const AEvent: TAMQPLogEvent);
begin
  Writeln(FormatDateTime('hh:nn:ss.zzz', AEvent.Timestamp) +
    ' [' + AEvent.Operation + '] ' + AEvent.Message);
end;

var
  Factory: IAMQPConnectionFactory;
  Options: IAMQPConnectionOptions;
  Connection: IAMQPConnection;
  Channel: IAMQPChannel;
  Consumer: IAMQPConsumer;
  MessageReceived: TEvent;
begin
  MessageReceived := TEvent.Create(nil, True, False, '');
  try
    Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);

    Options := TAMQPConnectionOptions.CreateDefault
      .SetHost('localhost')
      .SetPort(5672)
      .SetVirtualHost('/')
      .SetUserName('guest')
      .SetPassword('guest')
      .SetConsumerDispatchMode(cdmWorkerThread);

    Connection := Factory.CreateConnection(Options);
    Connection.Connect;

    Channel := Connection.CreateChannel;
    Channel.QueueDeclare('delphiamqp.demo', True, False, False);

    Consumer := Channel.BasicConsume(
      'delphiamqp.demo',
      procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
      begin
        Writeln('Mensagem recebida: ' + AMessage.AsText);
        AContext.Ack;
        MessageReceived.SetEvent;
      end,
      False);
    Consumer.Start;

    Channel.Publish('', 'delphiamqp.demo', TAMQPMessage.FromText('Ola do Delphi AMQP Core'));

    if MessageReceived.WaitFor(5000) <> wrSignaled then
      raise Exception.Create('Timeout waiting for consumed message.');

    Consumer.Stop;
    Channel.QueuePurge('delphiamqp.demo');
    Channel.QueueDelete('delphiamqp.demo');
    Connection.Disconnect;

    Writeln('Fluxo concluido.');
    Writeln('Pressione Enter para encerrar...');
    Readln;
  finally
    MessageReceived.Free;
  end;
end.
