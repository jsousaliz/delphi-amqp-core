unit DelphiAMQP.Tests.Performance.Report;

interface

uses
  DelphiAMQP.Tests.Performance.Config,
  DelphiAMQP.Tests.Performance.Result;

procedure PrintConfig(const AConfig: TPerformanceConfig);
procedure PrintHeader;
procedure PrintResult(
  const AConfig: TPerformanceConfig;
  const AResult: TPerformanceResult);

implementation

uses
  System.SysUtils;

function FormatInteger(const AValue: Integer): string;
begin
  Result := FormatFloat('#,##0', AValue);
end;

function FormatDuration(const AElapsedMS: UInt64): string;
var
  LHours: UInt64;
  LMilliseconds: UInt64;
  LMinutes: UInt64;
  LSeconds: UInt64;
begin
  LMilliseconds := AElapsedMS mod 1000;
  LSeconds := AElapsedMS div 1000;
  LMinutes := LSeconds div 60;
  LSeconds := LSeconds mod 60;
  LHours := LMinutes div 60;
  LMinutes := LMinutes mod 60;

  Result := Format('%.2d:%.2d:%.2d.%.3d', [LHours, LMinutes, LSeconds, LMilliseconds]);
end;

function RatePerSecond(const ACount: Integer; const AElapsedMS: UInt64): Double;
begin
  if AElapsedMS = 0 then
    Exit(0);
  Result := ACount / (AElapsedMS / 1000);
end;

procedure PrintHeader;
begin
  Writeln('============================================================');
  Writeln(' Delphi AMQP Core - Teste de Performance RabbitMQ');
  Writeln('============================================================');
  Writeln;
end;

procedure PrintConfig(const AConfig: TPerformanceConfig);
begin
  Writeln('CENARIO TESTADO');
  Writeln('------------------------------------------------------------');
  Writeln('Perfil selecionado: ' + ProfileName(AConfig.Profile));
  Writeln;
  Writeln('Este perfil executara o teste com:');
  Writeln('- Conexoes: ' + FormatInteger(AConfig.ConnectionCount));
  Writeln('- Consumers: ' + FormatInteger(AConfig.ConsumerCount));
  Writeln('- Publishers: ' + FormatInteger(AConfig.PublisherCount));
  Writeln('- Mensagens planejadas: ' + FormatInteger(AConfig.MessageCount));
  Writeln('- Timeout: ' + FormatDuration(AConfig.TimeoutMS));
  Writeln;
  Writeln('Ambiente:');
  Writeln('- Host: ' + AConfig.Host);
  Writeln('- Porta: ' + AConfig.Port.ToString);
  Writeln('- Virtual host: ' + AConfig.VirtualHost);
  Writeln('- Fila: ' + AConfig.QueueName);
  Writeln;
end;

procedure PrintResult(
  const AConfig: TPerformanceConfig;
  const AResult: TPerformanceResult);
var
  LStatus: string;
begin
  if AResult.Success then
    LStatus := 'SUCESSO'
  else
    LStatus := 'FALHA';

  Writeln('RESULTADO OBTIDO');
  Writeln('------------------------------------------------------------');
  Writeln('- Status: ' + LStatus);
  Writeln('- Mensagens publicadas: ' + FormatInteger(AResult.PublishedCount));
  Writeln('- Mensagens consumidas: ' + FormatInteger(AResult.ConsumedCount));
  Writeln('- Mensagens faltantes: ' + FormatInteger(AResult.MissingCount));
  Writeln('- Mensagens duplicadas: ' + FormatInteger(AResult.DuplicateCount));
  Writeln('- Erros registrados: ' + FormatInteger(AResult.ErrorCount));
  if not AResult.ErrorMessage.Trim.IsEmpty then
    Writeln('- Erro: ' + AResult.ErrorMessage);
  Writeln;
  Writeln('TEMPOS E TAXAS');
  Writeln('------------------------------------------------------------');
  Writeln('- Tempo total: ' + FormatDuration(AResult.TotalElapsedMS));
  Writeln('- Tempo de publicacao: ' + FormatDuration(AResult.PublishElapsedMS));
  Writeln('- Tempo ate consumo completo: ' + FormatDuration(AResult.ConsumeElapsedMS));
  Writeln('- Publicacoes por segundo: ' +
    FormatFloat('#,##0.00', RatePerSecond(AResult.PublishedCount, AResult.PublishElapsedMS)));
  Writeln('- Consumos por segundo: ' +
    FormatFloat('#,##0.00', RatePerSecond(AResult.ConsumedCount, AResult.ConsumeElapsedMS)));
  Writeln;
  Writeln('OBSERVACAO');
  Writeln('------------------------------------------------------------');
  Writeln('- Esta versao publica JSONs com 5 variacoes de tamanho e consome com concorrencia.');
  Writeln('- O sucesso exige publicar e consumir todas as mensagens sem erro ou duplicidade.');
  Writeln('- A fila permanece criada no RabbitMQ para inspecao dos graficos apos o teste.');
  Writeln;
  Writeln('============================================================');
end;

end.
