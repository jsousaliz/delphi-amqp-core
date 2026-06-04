# Delphi AMQP Core

Status: pronto

Delphi AMQP Core é uma biblioteca Delphi open source para comunicação nativa com
RabbitMQ e brokers compatíveis com AMQP 0-9-1.

O projeto permite conectar, declarar filas, publicar mensagens, consumir
mensagens de forma assíncrona, executar `ack`, `nack` e `reject`, limpar/excluir
filas e observar operações por logs estruturados, sem depender de componentes
Delphi externos.

Funcionalidades atuais: fundação do projeto, contratos públicos, codec inicial, transporte
TCP, handshake AMQP 0-9-1, abertura de canal, operações de fila, publicação,
consumo assíncrono com ack/nack/reject e observabilidade estruturada.

## Índice

- [Objetivos](#objetivos)
- [Tecnologias usadas](#tecnologias-usadas)
- [Recursos principais](#recursos-principais)
- [Casos de uso](#casos-de-uso)
- [Estrutura](#estrutura)
- [Planejamento de desenvolvimento](#planejamento-de-desenvolvimento)
- [Uso básico](#uso-básico)
- [Consumo assíncrono](#consumo-assíncrono)
- [Exemplos](#exemplos)
- [Observabilidade](#observabilidade)
- [RabbitMQ local](#rabbitmq-local)
- [Testes](#testes)
- [Roadmap](#roadmap)
- [Documentação técnica](#documentação-técnica)
- [Licença](#licença)

## Objetivos

- AMQP 0-9-1 nativo, inicialmente validado com RabbitMQ.
- API baseada em interfaces para reduzir controle manual de memória.
- Consumo assíncrono para não bloquear a thread principal.
- Observabilidade por interface de logger estruturado.
- Exemplos didáticos em projeto separado.
- Licença MIT.

## Tecnologias usadas

- Delphi 10.4+ Win64.
- Object Pascal.
- AMQP 0-9-1.
- RabbitMQ.
- TCP nativo.
- WinSock.
- Interfaces Delphi com reference counting.
- Worker threads para consumo assíncrono.
- Logger estruturado.
- Testes de contrato em console.
- Testes de integração com RabbitMQ real.
- Teste de performance com publishers e consumers concorrentes.
- Docker para ambiente RabbitMQ local.

## Recursos principais

- Cliente AMQP 0-9-1 nativo para Delphi.
- Integração com RabbitMQ sem componentes Delphi externos.
- Publicação de mensagens texto e binárias.
- Consumo assíncrono sem bloquear a thread principal.
- `basic.ack`, `basic.nack` e `basic.reject`.
- `queue.declare`, `queue.purge` e `queue.delete`.
- API baseada em interfaces.
- Observabilidade por `IAMQPLogger`.
- Eventos estruturados com `Operation`, `ConnectionId`, `ChannelId`,
  `ErrorClass` e `DurationMS`.
- Exemplos console e VCL.
- Testes de contrato, integração real e performance.

## Casos de uso

- Aplicações Delphi que precisam publicar mensagens no RabbitMQ.
- Serviços Delphi que consomem filas AMQP.
- Integrações assíncronas entre sistemas legados e modernos.
- Monitoramento e administração básica de filas.
- Estudos sobre implementação nativa de AMQP 0-9-1 em Object Pascal.

## Estrutura

- `src/`: units da biblioteca.
- [`tests/`](tests/README.md): testes de contrato, integração RabbitMQ e performance.
- [`examples/`](examples/README.md): exemplos console e VCL.
- [`docs/`](docs/README.md): documentação do usuário, arquitetura e guia técnico interno.
- `plan/`: planejamento de desenvolvimento por etapas.
- `LICENSE` e `COPYRIGHT`: licenciamento do projeto.

## Planejamento de desenvolvimento

O planejamento incremental do componente fica em [`plan/`](plan/README.md). O arquivo principal
[`plan/README.md`](plan/README.md) lista as etapas e cada arquivo detalha entregas, definição de
pronto e observações de implementação.

## Uso básico

```pascal
var
  Factory: IAMQPConnectionFactory;
  Options: IAMQPConnectionOptions;
  Connection: IAMQPConnection;
  Channel: IAMQPChannel;
begin
  Factory := TAMQPConnectionFactory.Create;
  Options := TAMQPConnectionOptions.CreateDefault;

  Options.SetHost('localhost')
    .SetPort(5672)
    .SetVirtualHost('/')
    .SetUserName('guest')
    .SetPassword('guest');

  Connection := Factory.CreateConnection(Options);
  Connection.Connect;

  Channel := Connection.CreateChannel;
  Channel.QueueDeclare('delphiamqp.demo', True, False, False);
  Channel.Publish('', 'delphiamqp.demo', TAMQPMessage.FromText('Olá AMQP'));

  Connection.Disconnect;
end;
```

## Consumo assíncrono

```pascal
Consumer := Channel.BasicConsume(
  'delphiamqp.demo',
  procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
  begin
    try
      Writeln(AMessage.AsText);
      AContext.Ack;
    except
      AContext.Nack(True);
    end;
  end);

Consumer.Start;
```

O callback poderá ser executado em worker thread ou sincronizado com a thread
principal, conforme configuração.

## Exemplos

O projeto `examples/ConsoleQuickStart` demonstra o uso mínimo e linear da API,
com o fluxo inteiro em sequência no `begin/end`.

O projeto `examples/ConsoleStepByStep` demonstra o mesmo fluxo em etapas
nomeadas, com saída mais didática no console:

- conexão com RabbitMQ local;
- criação de fila;
- publicação de mensagem;
- purge e delete de fila;
- consumo assíncrono com ack manual;
- callback executando em worker thread;
- logs estruturados emitidos no console.

O projeto visual em `examples/VclQueueManager` demonstra uma tela VCL para:

- configurar conexão;
- criar, limpar e excluir fila;
- publicar mensagem;
- iniciar e parar consumo;
- visualizar mensagens consumidas;
- visualizar logs com filtro por `Level` e `Kind`.

Veja as instruções completas em:

- [`examples/ConsoleQuickStart/README.md`](examples/ConsoleQuickStart/README.md)
- [`examples/ConsoleStepByStep/README.md`](examples/ConsoleStepByStep/README.md)
- [`examples/VclQueueManager/README.md`](examples/VclQueueManager/README.md)

## Observabilidade

Passe um `IAMQPLogger` para `TAMQPConnectionFactory.Create` para receber eventos
estruturados de conexão, canal, fila, publish, consume, ack/nack/reject,
heartbeat e erro.

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
```

Os eventos incluem campos como `Operation`, `ConnectionId`, `ChannelId`,
`ErrorClass` e `DurationMS`. Operações bloqueantes principais registram duração
em milissegundos. Sem logger explícito, a biblioteca usa um logger nulo interno.

## RabbitMQ local

Para executar os exemplos com RabbitMQ local, instale o Docker Desktop para
Windows, deixe o Docker em execução e rode no PowerShell:

```powershell
docker run -d `
  --name delphi-amqp-rabbitmq `
  -p 5672:5672 `
  -p 15672:15672 `
  rabbitmq:3-management
```

Credenciais padrão:

- Usuário: `guest`
- Senha: `guest`
- Host: `localhost`
- Porta AMQP: `5672`
- Console de administração: `http://localhost:15672`

## Testes

O projeto possui testes separados por finalidade:

- [`ConsoleContracts`](tests/ConsoleContracts/DelphiAMQP.Tests.Console.dpr):
  testes de contrato sem RabbitMQ.
- [`IntegrationRabbitMQ`](tests/IntegrationRabbitMQ/README.md): testes reais
  contra RabbitMQ.
- [`PerformanceRabbitMQ`](tests/PerformanceRabbitMQ/README.md): teste de
  performance com publishers e consumers concorrentes.

Execução dos testes de contrato:

```powershell
cd tests\ConsoleContracts
dcc64 -B DelphiAMQP.Tests.Console.dpr
.\DelphiAMQP.Tests.Console.exe
```

## Roadmap

1. Fundação do repositório e documentação.
2. Contratos públicos e arquitetura.
3. Codec AMQP 0-9-1.
4. Conexão TCP, handshake e canais.
5. Operações de fila e publicação.
6. Consumo assíncrono.
7. Observabilidade.
8. Projeto de exemplo completo.
9. Documentação final.
10. Preparação open source.
11. Teste de performance com RabbitMQ real.

## Documentação técnica

O funcionamento interno do transporte TCP, frames AMQP, métodos de handshake e
orquestração da conexão está documentado em
[`docs/technical-guide.md`](docs/technical-guide.md). Este
arquivo deve ser mantido como documentação viva conforme novas etapas forem
implementadas.

## Licença

MIT. Veja `LICENSE`.
