# Testes

## Índice

- [ConsoleContracts](#consolecontracts)
- [IntegrationRabbitMQ](#integrationrabbitmq)
- [PerformanceRabbitMQ](#performancerabbitmq)
- [Organização dos testes de contrato](#organização-dos-testes-de-contrato)
- [Artefatos gerados](#artefatos-gerados)
- [Estratégia para pipeline](#estratégia-para-pipeline)

## ConsoleContracts

[`ConsoleContracts`](ConsoleContracts/DelphiAMQP.Tests.Console.dpr) contém
testes sem dependências externas. Esse projeto deve rodar sempre no pipeline.

Ele valida:

- defaults e validações de configuração;
- conversão de mensagem texto/binário;
- cópia defensiva do body da mensagem;
- metadata de mensagens recebidas;
- encode/decode de frames AMQP;
- erros básicos do codec de frames;
- builders e readers principais de métodos AMQP;
- parse de `connection.start` e validação de mecanismos SASL/locales;
- parse de `connection.close`/`channel.close` e exceções tipadas com reply
  code/reply text;
- logger em memória e campos estruturados de log;
- operações de canal com sessão fake, sem RabbitMQ;
- fechamento de canal com `channel.close`/`channel.close-ok`;
- emissão de eventos com duração em operações bloqueantes de canal;
- contexto de consumo `Ack/Nack/Reject`, auto-ack, validações e start/stop de
  consumer com sessão fake.

Execução:

```powershell
cd tests\ConsoleContracts
dcc64 -B DelphiAMQP.Tests.Console.dpr
.\DelphiAMQP.Tests.Console.exe
```

## Organização dos testes de contrato

O projeto `ConsoleContracts` usa runner console puro e não depende de framework
externo de teste.

Estrutura:

- `DelphiAMQP.Tests.Console.dpr`: runner principal, responsável apenas por
  chamar as suítes.
- `TestSupport/DelphiAMQP.Tests.Assertions.pas`: asserts e helper de exceção.
- `TestSupport/DelphiAMQP.Tests.FakeFrameSession.pas`: fake de
  `IAMQPFrameSession` para testar canal sem TCP/RabbitMQ.
- `TestSupport/DelphiAMQP.Tests.FrameBuilders.pas`: builders de replies AMQP
  usados pelos testes.
- `Cases/`: suítes separadas por responsabilidade.

Cada unit em `Cases/` expõe uma procedure `Run...Tests`, chamada pelo runner
principal.

## Artefatos gerados

As compilações dos testes e exemplos podem gerar arquivos como `.dcu`, `.exe`,
`.res`, `.rsm`, `.identcache`, `.dproj.local` e pastas `__history/`.

Esses arquivos são artefatos locais do Delphi e não devem ser versionados. O
`.gitignore` do repositório já cobre esses padrões.

## IntegrationRabbitMQ

[`IntegrationRabbitMQ`](IntegrationRabbitMQ/README.md) contém testes reais contra
RabbitMQ. Esse projeto deve ficar em job separado e opcional no início, porque
depende de broker disponível.

Ele valida:

- conexão real;
- abertura de canal;
- declaração de fila;
- publicação;
- consumo assíncrono com ack;
- purge;
- delete;
- desconexão.

## PerformanceRabbitMQ

[`PerformanceRabbitMQ`](PerformanceRabbitMQ/README.md) contém teste manual de
performance contra RabbitMQ real. Esse projeto deve ficar separado dos testes
obrigatórios de pipeline, pois pode consumir mais recursos e tempo.

Ele será usado para medir:

- múltiplas conexões;
- consumers concorrentes;
- publishers concorrentes;
- mensagens publicadas e consumidas;
- mensagens faltantes e duplicadas;
- tempo total e throughput.

## Estratégia para pipeline

- Rode `ConsoleContracts` em todo commit/pull request.
- Rode `IntegrationRabbitMQ` em job separado, manual, agendado ou de release.
- Rode `PerformanceRabbitMQ` manualmente ou em job específico de performance.
- Quando o CI tiver ambiente Delphi e RabbitMQ disponíveis, o job de integração
  pode subir RabbitMQ como service/container antes de executar o teste.
