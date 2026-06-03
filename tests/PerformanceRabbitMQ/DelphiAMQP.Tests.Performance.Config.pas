unit DelphiAMQP.Tests.Performance.Config;

interface

uses
  System.SysUtils,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Options,
  DelphiAMQP.Types;

type
  TPerformanceProfile = (
    ppLight,
    ppMedium,
    ppHeavy
  );

  TPerformanceConfig = record
    Host: string;
    Port: UInt16;
    VirtualHost: string;
    UserName: string;
    Password: string;
    QueueName: string;
    Profile: TPerformanceProfile;
    ConnectionCount: Integer;
    ConsumerCount: Integer;
    PublisherCount: Integer;
    MessageCount: Integer;
    TimeoutMS: Cardinal;
  end;

function BuildOptions(const AConfig: TPerformanceConfig): IAMQPConnectionOptions;
function LoadConfig: TPerformanceConfig;
function ProfileName(const AProfile: TPerformanceProfile): string;

implementation

const
  DEFAULT_HOST = 'localhost';
  DEFAULT_PORT = 5672;
  DEFAULT_VHOST = '/';
  DEFAULT_USER = 'guest';
  DEFAULT_PASSWORD = 'guest';
  DEFAULT_QUEUE = 'delphiamqp.performance.test';

function EnvOrDefault(const AName, ADefault: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result.Trim.IsEmpty then
    Result := ADefault;
end;

function EnvPortOrDefault(const AName: string; const ADefault: UInt16): UInt16;
var
  LPort: Integer;
  LValue: string;
begin
  LValue := GetEnvironmentVariable(AName);
  if LValue.Trim.IsEmpty then
    Exit(ADefault);

  LPort := StrToInt(LValue);
  if (LPort <= 0) or (LPort > High(UInt16)) then
    raise Exception.Create('Invalid AMQP_TEST_PORT value.');

  Result := UInt16(LPort);
end;

function ResolveProfile: TPerformanceProfile;
var
  LValue: string;
begin
  LValue := GetEnvironmentVariable('AMQP_PERF_PROFILE').Trim.ToUpper;

  if (LValue = 'M') or (LValue = 'MEDIO') or (LValue = 'MÉDIO') then
    Exit(ppMedium);

  if (LValue = 'P') or (LValue = 'PESADO') then
    Exit(ppHeavy);

  Result := ppLight;
end;

function ProfileName(const AProfile: TPerformanceProfile): string;
begin
  case AProfile of
    ppMedium:
      Result := 'Medio';
    ppHeavy:
      Result := 'Pesado';
  else
    Result := 'Leve';
  end;
end;

procedure ApplyProfile(var AConfig: TPerformanceConfig);
begin
  case AConfig.Profile of
    ppMedium:
      begin
        AConfig.ConnectionCount := 20;
        AConfig.ConsumerCount := 50;
        AConfig.PublisherCount := 2;
        AConfig.MessageCount := 10000;
        AConfig.TimeoutMS := 180000;
      end;
    ppHeavy:
      begin
        AConfig.ConnectionCount := 100;
        AConfig.ConsumerCount := 200;
        AConfig.PublisherCount := 5;
        AConfig.MessageCount := 100000;
        AConfig.TimeoutMS := 600000;
      end;
  else
    AConfig.ConnectionCount := 5;
    AConfig.ConsumerCount := 5;
    AConfig.PublisherCount := 1;
    AConfig.MessageCount := 1000;
    AConfig.TimeoutMS := 60000;
  end;
end;

function LoadConfig: TPerformanceConfig;
begin
  Result.Host := EnvOrDefault('AMQP_TEST_HOST', DEFAULT_HOST);
  Result.Port := EnvPortOrDefault('AMQP_TEST_PORT', DEFAULT_PORT);
  Result.VirtualHost := EnvOrDefault('AMQP_TEST_VHOST', DEFAULT_VHOST);
  Result.UserName := EnvOrDefault('AMQP_TEST_USER', DEFAULT_USER);
  Result.Password := EnvOrDefault('AMQP_TEST_PASSWORD', DEFAULT_PASSWORD);
  Result.QueueName := EnvOrDefault('AMQP_PERF_QUEUE', DEFAULT_QUEUE);
  Result.Profile := ResolveProfile;
  ApplyProfile(Result);
end;

function BuildOptions(const AConfig: TPerformanceConfig): IAMQPConnectionOptions;
begin
  Result := TAMQPConnectionOptions.CreateDefault
    .SetHost(AConfig.Host)
    .SetPort(AConfig.Port)
    .SetVirtualHost(AConfig.VirtualHost)
    .SetUserName(AConfig.UserName)
    .SetPassword(AConfig.Password)
    .SetConnectionTimeoutMS(5000)
    .SetConsumerDispatchMode(cdmWorkerThread);
end;

end.
