# VclQueueManager

Exemplo visual VCL para operar uma fila RabbitMQ usando Delphi AMQP Core.

O exemplo mantém uma única conexão e um único canal compartilhados entre os
botões. Cada botão tem o código AMQP direto no próprio handler, de forma
intencionalmente didática.

A tela usa o modelo tradicional VCL com `MainForm.pas` e `MainForm.dfm`, para
que possa ser aberta e editada pelo designer visual do Delphi.

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

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Credenciais padrão:

- usuário: `guest`
- senha: `guest`
- porta AMQP: `5672`

## Execução

Abra `DelphiAMQP.Example.VclQueueManager.dproj` no Delphi 10.4+ Win64.

Também é possível compilar pela linha de comando:

```powershell
dcc64 -B DelphiAMQP.Example.VclQueueManager.dpr
```
