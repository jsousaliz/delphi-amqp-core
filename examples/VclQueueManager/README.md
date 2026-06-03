# VclQueueManager

Status: implementado.

Exemplo visual VCL para operar uma fila RabbitMQ usando Delphi AMQP Core.

O exemplo mantém uma única conexão e um único canal compartilhados entre os
botões. Cada botão tem o código AMQP direto no próprio handler, de forma
intencionalmente didática.

A tela usa o modelo tradicional VCL com `MainForm.pas` e `MainForm.dfm`, para
que possa ser aberta e editada pelo designer visual do Delphi.

## Índice

- [Funcionalidades](#funcionalidades)
- [RabbitMQ local](#rabbitmq-local)
- [Execução](#execução)

## Funcionalidades

- configurar host, porta, virtual host, usuário, senha e dispatch mode;
- informar o nome da fila;
- conectar/desconectar;
- criar fila;
- executar purge;
- excluir fila;
- publicar mensagem;
- iniciar/parar consumo;
- visualizar mensagens consumidas;
- visualizar logs estruturados;
- filtrar logs por `Level` e `Kind`.

## RabbitMQ local

Este exemplo espera um RabbitMQ local acessível em `localhost:5672`.

Para subir o RabbitMQ local, instale o Docker Desktop para Windows, deixe o
Docker em execução e rode no PowerShell:

```powershell
docker run -d `
  --name delphi-amqp-rabbitmq `
  -p 5672:5672 `
  -p 15672:15672 `
  rabbitmq:3-management
```

Credenciais padrão usadas pelo exemplo:

- usuário: `guest`
- senha: `guest`
- host: `localhost`
- porta AMQP: `5672`
- console de administração: `http://localhost:15672`

## Execução

Abra `DelphiAMQP.Example.VclQueueManager.dproj` no Delphi 10.4+ Win64.

Também é possível compilar pela linha de comando:

```powershell
dcc64 -B DelphiAMQP.Example.VclQueueManager.dpr
```
