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
  DelphiAMQP.Protocol.Methods in '..\..\src\DelphiAMQP.Protocol.Methods.pas',
  DelphiAMQP.Tests.Assertions in 'TestSupport\DelphiAMQP.Tests.Assertions.pas',
  DelphiAMQP.Tests.FrameBuilders in 'TestSupport\DelphiAMQP.Tests.FrameBuilders.pas',
  DelphiAMQP.Tests.FakeFrameSession in 'TestSupport\DelphiAMQP.Tests.FakeFrameSession.pas',
  DelphiAMQP.Tests.Options in 'Cases\DelphiAMQP.Tests.Options.pas',
  DelphiAMQP.Tests.Message in 'Cases\DelphiAMQP.Tests.Message.pas',
  DelphiAMQP.Tests.FrameCodec in 'Cases\DelphiAMQP.Tests.FrameCodec.pas',
  DelphiAMQP.Tests.MethodCodec in 'Cases\DelphiAMQP.Tests.MethodCodec.pas',
  DelphiAMQP.Tests.Logging in 'Cases\DelphiAMQP.Tests.Logging.pas',
  DelphiAMQP.Tests.Channel in 'Cases\DelphiAMQP.Tests.Channel.pas',
  DelphiAMQP.Tests.Consumer in 'Cases\DelphiAMQP.Tests.Consumer.pas',
  DelphiAMQP.Tests.Factory in 'Cases\DelphiAMQP.Tests.Factory.pas';

begin
  try
    RunOptionsTests;
    RunMessageTests;
    RunFrameCodecTests;
    RunMethodCodecTests;
    RunLoggingTests;
    RunChannelTests;
    RunConsumerTests;
    RunFactoryTests;
    Writeln('All contract tests passed.');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
