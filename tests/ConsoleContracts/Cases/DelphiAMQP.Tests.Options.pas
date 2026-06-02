unit DelphiAMQP.Tests.Options;

interface

procedure RunOptionsTests;

implementation

uses
  DelphiAMQP.Types,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Options,
  DelphiAMQP.Tests.Assertions;

procedure TestDefaultOptions;
var
  LOptions: IAMQPConnectionOptions;
begin
  LOptions := TAMQPConnectionOptions.CreateDefault;
  AssertEquals('localhost', LOptions.Host, 'Default host mismatch.');
  AssertEquals(5672, LOptions.Port, 'Default port mismatch.');
  AssertEquals('/', LOptions.VirtualHost, 'Default virtual host mismatch.');
  AssertEquals('guest', LOptions.UserName, 'Default username mismatch.');
  AssertEquals('guest', LOptions.Password, 'Default password mismatch.');
  AssertEquals(60, LOptions.HeartbeatSeconds, 'Default heartbeat mismatch.');
  AssertEquals(30000, LOptions.ConnectionTimeoutMS, 'Default timeout mismatch.');
  AssertTrue(not LOptions.UseTLS, 'Default TLS mismatch.');
  AssertTrue(LOptions.ConsumerDispatchMode = cdmWorkerThread, 'Default dispatch mode mismatch.');
end;

procedure TestOptionsSettersAndValidation;
var
  LOptions: IAMQPConnectionOptions;
begin
  LOptions := TAMQPConnectionOptions.CreateDefault
    .SetHost('broker.local')
    .SetPort(5673)
    .SetVirtualHost('/dev')
    .SetUserName('user')
    .SetPassword('secret')
    .SetHeartbeatSeconds(15)
    .SetConnectionTimeoutMS(5000)
    .SetUseTLS(True)
    .SetConsumerDispatchMode(cdmMainThread);

  AssertEquals('broker.local', LOptions.Host, 'Host setter mismatch.');
  AssertEquals(5673, LOptions.Port, 'Port setter mismatch.');
  AssertEquals('/dev', LOptions.VirtualHost, 'Virtual host setter mismatch.');
  AssertEquals('user', LOptions.UserName, 'Username setter mismatch.');
  AssertEquals('secret', LOptions.Password, 'Password setter mismatch.');
  AssertEquals(15, LOptions.HeartbeatSeconds, 'Heartbeat setter mismatch.');
  AssertEquals(5000, LOptions.ConnectionTimeoutMS, 'Timeout setter mismatch.');
  AssertTrue(LOptions.UseTLS, 'TLS setter mismatch.');
  AssertTrue(LOptions.ConsumerDispatchMode = cdmMainThread, 'Dispatch mode setter mismatch.');

  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      TAMQPConnectionOptions.CreateDefault.SetHost('');
    end,
    'Empty host validation failed.');
  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      TAMQPConnectionOptions.CreateDefault.SetPort(0);
    end,
    'Zero port validation failed.');
  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      TAMQPConnectionOptions.CreateDefault.SetVirtualHost('');
    end,
    'Empty virtual host validation failed.');
  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      TAMQPConnectionOptions.CreateDefault.SetUserName('');
    end,
    'Empty username validation failed.');
  AssertRaises(EAMQPConnectionError,
    procedure
    begin
      TAMQPConnectionOptions.CreateDefault.SetConnectionTimeoutMS(0);
    end,
    'Zero timeout validation failed.');
end;

procedure RunOptionsTests;
begin
  TestDefaultOptions;
  TestOptionsSettersAndValidation;
end;

end.
