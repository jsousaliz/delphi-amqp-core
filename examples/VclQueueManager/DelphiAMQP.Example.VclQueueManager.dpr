program DelphiAMQP.Example.VclQueueManager;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas',
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

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, VclQueueManagerForm);
  Application.Run;
end.
