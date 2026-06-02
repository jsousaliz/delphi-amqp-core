# IntegrationRabbitMQ

Projeto de testes de integração real contra RabbitMQ. Ele valida o fluxo de
ponta a ponta: conectar, abrir canal, declarar fila, publicar, consumir com ack,
executar purge, excluir fila, fechar canal e desconectar.

## Índice

- [RabbitMQ local](#rabbitmq-local)
- [Execução](#execução)
- [Variáveis de ambiente](#variáveis-de-ambiente)

## RabbitMQ local

Estes testes esperam um RabbitMQ local acessível em `localhost:5672`.

Para subir o RabbitMQ local, instale o Docker Desktop para Windows, deixe o
Docker em execução e rode:

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Credenciais padrão:

- usuário: `guest`
- senha: `guest`
- host: `localhost`
- porta AMQP: `5672`
- console de administração: `http://localhost:15672`

## Execução

```powershell
dcc64 -B DelphiAMQP.Tests.IntegrationRabbitMQ.dpr
.\DelphiAMQP.Tests.IntegrationRabbitMQ.exe
```

## Variáveis de ambiente

O teste usa estes valores quando as variáveis não forem informadas:

- `AMQP_TEST_HOST`: `localhost`
- `AMQP_TEST_PORT`: `5672`
- `AMQP_TEST_VHOST`: `/`
- `AMQP_TEST_USER`: `guest`
- `AMQP_TEST_PASSWORD`: `guest`
