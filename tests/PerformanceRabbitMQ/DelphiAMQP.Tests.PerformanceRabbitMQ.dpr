program DelphiAMQP.Tests.PerformanceRabbitMQ;

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
  DelphiAMQP.Protocol.Methods in '..\..\src\DelphiAMQP.Protocol.Methods.pas',
  DelphiAMQP.Tests.Performance.Config in 'DelphiAMQP.Tests.Performance.Config.pas',
  DelphiAMQP.Tests.Performance.Load in 'DelphiAMQP.Tests.Performance.Load.pas',
  DelphiAMQP.Tests.Performance.Messages in 'DelphiAMQP.Tests.Performance.Messages.pas',
  DelphiAMQP.Tests.Performance.Report in 'DelphiAMQP.Tests.Performance.Report.pas',
  DelphiAMQP.Tests.Performance.Result in 'DelphiAMQP.Tests.Performance.Result.pas',
  DelphiAMQP.Tests.Performance.Runner in 'DelphiAMQP.Tests.Performance.Runner.pas',
  DelphiAMQP.Tests.Performance.SharedState in 'DelphiAMQP.Tests.Performance.SharedState.pas';

var
  Config: TPerformanceConfig;
  Result: TPerformanceResult;
begin
  try
    Config := LoadConfig;
    PrintHeader;
    PrintConfig(Config);
    Result := RunPerformanceTest(Config);
    PrintResult(Config, Result);
    if Result.Success then
      System.ExitCode := 0
    else
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Writeln('Check environment variables AMQP_TEST_HOST, AMQP_TEST_PORT, AMQP_TEST_VHOST, AMQP_TEST_USER, AMQP_TEST_PASSWORD and AMQP_PERF_PROFILE.');
      System.ExitCode := 1;
    end;
  end;
end.
