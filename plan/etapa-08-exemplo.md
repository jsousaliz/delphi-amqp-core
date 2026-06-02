# Etapa 8: Projeto de Exemplo

Status: implementada.

## Entregas

- [x] Projeto separado em `examples/`.
- [x] Conexão com RabbitMQ local.
- [x] Criação de fila, publish, consume, purge e delete.
- [x] Código didático.
- [x] Separar no exemplo comandos/rotinas para cada fluxo: conectar, declarar
  fila, publicar, consumir, limpar e deletar.
- [x] Adicionar exemplo console mínimo em `examples/ConsoleQuickStart`, com o
  fluxo linear em sequência no `begin/end`.
- [x] Renomear o exemplo console didático para `examples/ConsoleStepByStep`.
- [x] Exibir logs de forma legível e deixar claro quais callbacks rodam em
  worker thread.
- [x] Incluir configuração visível para host, porta, vhost, usuário e senha.
- [x] Adicionar exemplo visual VCL em `examples/VclQueueManager`, com conexão
  compartilhada, botões de operação, consumo separado e logs filtráveis por
  `Level` e `Kind`.

## Definição de pronto

- [x] Exemplo abre no Delphi 10.4+ Win64.
- [x] README documenta execução.
- [x] Exemplo executa de ponta a ponta com RabbitMQ local usando as credenciais
  padrão `guest`/`guest`.
- [x] Exemplo VCL compila em Delphi Win64.
