# Etapa 11: Teste de Performance RabbitMQ

## Status

Implementada.

## Objetivo

Criar uma aplicacao console de teste de performance real contra RabbitMQ para
avaliar o comportamento do Delphi AMQP Core com multiplas conexoes, consumers e
publishers concorrentes.

Este teste nao substitui os testes de contrato nem os testes de integracao. Ele
deve ser executado manualmente ou em job separado, pois depende de RabbitMQ real
e pode consumir mais recursos.

## Perfis

O teste possui tres perfis fixos:

```text
L = Leve
M = Medio
P = Pesado
```

Se o perfil informado for vazio ou invalido, o teste assume `Leve`.

### Leve

```text
Conexoes: 5
Consumers: 5
Publishers: 1
Mensagens: 1.000
Timeout: 60 segundos
```

### Medio

```text
Conexoes: 20
Consumers: 50
Publishers: 2
Mensagens: 10.000
Timeout: 180 segundos
```

### Pesado

```text
Conexoes: 100
Consumers: 200
Publishers: 5
Mensagens: 100.000
Timeout: 600 segundos
```

## Variaveis de Ambiente

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

## Estrutura Implementada

```text
tests/PerformanceRabbitMQ/
  DelphiAMQP.Tests.PerformanceRabbitMQ.dpr
  DelphiAMQP.Tests.PerformanceRabbitMQ.dproj
  DelphiAMQP.Tests.Performance.Config.pas
  DelphiAMQP.Tests.Performance.Load.pas
  DelphiAMQP.Tests.Performance.Messages.pas
  DelphiAMQP.Tests.Performance.Report.pas
  DelphiAMQP.Tests.Performance.Result.pas
  DelphiAMQP.Tests.Performance.Runner.pas
  DelphiAMQP.Tests.Performance.SharedState.pas
  README.md
```

## Fluxo do Teste

1. Ler variaveis de ambiente.
2. Resolver perfil.
3. Imprimir configuracao inicial.
4. Conectar no RabbitMQ.
5. Declarar fila de performance.
6. Fazer `purge` inicial.
7. Criar consumers concorrentes.
8. Criar publishers concorrentes.
9. Publicar mensagens JSON com IDs unicos.
10. Consumir mensagens ate atingir o total esperado ou timeout.
11. Parar consumers.
12. Fechar conexoes.
13. Preservar a fila criada para inspecao no RabbitMQ Management.
14. Imprimir relatorio final.

## Modelo de Mensagem

Cada mensagem publicada possui payload JSON:

```json
{
  "id": 1,
  "identificador": "delphi-amqp-core-perf",
  "tipo": "tipo-1",
  "mensagem": "Mensagem curta para teste de performance."
}
```

O teste usa cinco variacoes de texto para simular payloads curtos, medios e
longos.

O campo `id` e usado para validar:

- total publicado;
- total consumido;
- mensagens faltantes;
- mensagens duplicadas.

## Tratamento de Erros

Nao ha retry nesta etapa.

Se uma operacao falhar, o erro e registrado e aparece no relatorio final. O
teste tenta finalizar de forma controlada e aplica timeout conforme o perfil.

## Relatorio Final

O relatorio final exibe:

- perfil executado;
- ambiente;
- mensagens publicadas;
- mensagens consumidas;
- mensagens faltantes;
- mensagens duplicadas;
- erros registrados;
- tempo total;
- tempo de publicacao;
- tempo ate consumo completo;
- publicacoes por segundo;
- consumos por segundo.

## Etapas de Desenvolvimento

1. Estrutura, perfis e relatorio base: implementada.
2. Preparacao RabbitMQ: implementada.
3. Publishers concorrentes: implementada.
4. Consumers concorrentes: implementada.
5. Espera por consumo completo ou timeout: implementada.
6. Finalizacao controlada: implementada.
7. Relatorio final com metricas reais: implementada.
8. Documentacao final do teste: implementada.

## Definicao de Pronto

- Projeto compila no Delphi 10.4+ Win64.
- Perfil invalido assume `Leve`.
- Teste publica mensagens JSON com IDs unicos.
- Teste valida mensagens consumidas, faltantes e duplicadas.
- Erros aparecem no relatorio final.
- Tempo total e taxas medias sao exibidos.
- README explica uso, variaveis de ambiente, perfis e organizacao.
