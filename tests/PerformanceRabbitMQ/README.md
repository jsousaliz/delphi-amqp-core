# PerformanceRabbitMQ

## Status

Implementado.

## Indice

- [Objetivo](#objetivo)
- [RabbitMQ local](#rabbitmq-local)
- [Perfis](#perfis)
- [Variaveis de ambiente](#variaveis-de-ambiente)
- [Execucao](#execucao)
- [Comportamento](#comportamento)
- [Organizacao](#organizacao)

## Objetivo

Este projeto executa um teste manual de performance contra RabbitMQ real,
simulando multiplas conexoes, consumers e publishers usando o Delphi AMQP Core.

O teste publica mensagens em JSON, consome as mensagens publicadas, valida IDs
unicos, detecta mensagens faltantes/duplicadas e imprime um relatorio com tempo
total, tempo de publicacao, tempo de consumo e throughput.

## RabbitMQ local

Para subir o RabbitMQ local, instale o Docker Desktop para Windows, deixe o
Docker em execucao e rode no PowerShell:

```powershell
docker run -d `
  --name delphi-amqp-rabbitmq `
  -p 5672:5672 `
  -p 15672:15672 `
  rabbitmq:3-management
```

## Perfis

O perfil e definido pela variavel de ambiente `AMQP_PERF_PROFILE`.

Valores aceitos:

```text
L, LEVE
M, MEDIO
P, PESADO
```

Se o valor estiver vazio ou invalido, o perfil `Leve` sera usado.

```text
Leve:
- 5 conexoes
- 5 consumers
- 1 publisher
- 1.000 mensagens
- timeout de 60 segundos

Medio:
- 20 conexoes
- 50 consumers
- 2 publishers
- 10.000 mensagens
- timeout de 180 segundos

Pesado:
- 100 conexoes
- 200 consumers
- 5 publishers
- 100.000 mensagens
- timeout de 600 segundos
```

## Variaveis de ambiente

Conexao:

```text
AMQP_TEST_HOST
AMQP_TEST_PORT
AMQP_TEST_VHOST
AMQP_TEST_USER
AMQP_TEST_PASSWORD
```

Performance:

```text
AMQP_PERF_PROFILE
AMQP_PERF_QUEUE
```

Defaults:

```text
Host: localhost
Porta: 5672
VHost: /
Usuario: guest
Senha: guest
Fila: delphiamqp.performance.test
Perfil: Leve
```

## Execucao

```powershell
cd tests\PerformanceRabbitMQ
dcc64 -B DelphiAMQP.Tests.PerformanceRabbitMQ.dpr
.\DelphiAMQP.Tests.PerformanceRabbitMQ.exe
```

Exemplo escolhendo o perfil medio:

```powershell
$env:AMQP_PERF_PROFILE='M'
.\DelphiAMQP.Tests.PerformanceRabbitMQ.exe
```

## Comportamento

O teste executa:

- conexao com RabbitMQ real;
- declaracao da fila de performance;
- `purge` inicial;
- criacao de consumers concorrentes;
- divisao do total de mensagens entre publishers;
- publicacao concorrente com uma conexao por publisher;
- consumo concorrente com uma conexao por consumer;
- payloads em JSON com 5 variacoes de mensagem;
- validacao de mensagens publicadas, consumidas, faltantes e duplicadas;
- relatorio de erros, tempo total, tempo de publicacao, tempo de consumo e
  throughput.

Nesta versao, cada publisher e cada consumer usa sua propria conexao para evitar
leitura concorrente de frames no mesmo socket AMQP.

A fila e limpa no inicio do teste, mas permanece criada ao final para permitir
inspecao dos graficos e estatisticas no RabbitMQ Management. Quando o teste
termina com sucesso, a fila fica vazia porque todas as mensagens foram
consumidas.

Exemplo de payload publicado:

```json
{
  "id": 1,
  "identificador": "delphi-amqp-core-perf",
  "tipo": "tipo-1",
  "mensagem": "Mensagem curta para teste de performance."
}
```

## Organizacao

O projeto foi separado por contexto para manter o runner principal pequeno:

- `DelphiAMQP.Tests.PerformanceRabbitMQ.dpr`: entrada do console.
- `DelphiAMQP.Tests.Performance.Config.pas`: perfis, variaveis de ambiente e
  opcoes de conexao.
- `DelphiAMQP.Tests.Performance.Messages.pas`: payloads e parse de IDs.
- `DelphiAMQP.Tests.Performance.SharedState.pas`: contadores, erros e IDs
  consumidos com protecao de thread.
- `DelphiAMQP.Tests.Performance.Load.pas`: publishers, consumers e limpeza da
  fila.
- `DelphiAMQP.Tests.Performance.Runner.pas`: orquestracao do teste.
- `DelphiAMQP.Tests.Performance.Report.pas`: relatorio de console.
- `DelphiAMQP.Tests.Performance.Result.pas`: resultado final do teste.
