# ConsoleQuickStart

Status: implementado.

Exemplo console mínimo e linear.

Este exemplo deixa o fluxo inteiro em sequência no `begin/end`, sem rotinas
auxiliares, para facilitar a leitura direta do uso das interfaces principais.

## Índice

- [RabbitMQ local](#rabbitmq-local)
- [Execução](#execução)

## RabbitMQ local

Este exemplo espera um RabbitMQ local acessível em `localhost:5672`.

Para subir o RabbitMQ local, instale o Docker Desktop para Windows, deixe o
Docker em execução e rode:

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Credenciais padrão usadas pelo exemplo:

- usuário: `guest`
- senha: `guest`
- host: `localhost`
- porta AMQP: `5672`
- console de administração: `http://localhost:15672`

## Execução

```powershell
dcc64 -B DelphiAMQP.Example.ConsoleQuickStart.dpr
.\DelphiAMQP.Example.ConsoleQuickStart.exe
```
