unit DelphiAMQP.Tests.Factory;

interface

procedure RunFactoryTests;

implementation

uses
  DelphiAMQP.Types,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Options,
  DelphiAMQP.Factory,
  DelphiAMQP.Tests.Assertions;

procedure TestFactoryContracts;
var
  LFactory: IAMQPConnectionFactory;
  LConnection: IAMQPConnection;
begin
  LFactory := TAMQPConnectionFactory.Create;
  LConnection := LFactory.CreateConnection(TAMQPConnectionOptions.CreateDefault);
  AssertTrue(LConnection <> nil, 'Factory connection result must not be nil.');
  AssertTrue(LConnection.State = csDisconnected, 'Factory connection initial state mismatch.');

  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      LFactory.CreateConnection(nil);
    end,
    'Factory nil options validation failed.');
end;

procedure RunFactoryTests;
begin
  TestFactoryContracts;
end;

end.
