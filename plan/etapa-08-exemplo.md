# Etapa 8: Projeto de Exemplo

Status: implementada.

## Entregas

- Projeto separado em `examples/`.
- Conexão com RabbitMQ local.
- Criação de fila, publish, consume, purge e delete.
- Código didático.
- Separar no exemplo comandos/rotinas para cada fluxo: conectar, declarar
  fila, publicar, consumir, limpar e deletar.
- Adicionar exemplo console mínimo em `examples/ConsoleQuickStart`, com o
  fluxo linear em sequência no `begin/end`.
- Renomear o exemplo console didático para `examples/ConsoleStepByStep`.
- Exibir logs de forma legível e deixar claro quais callbacks rodam em
  worker thread.
- Incluir configuração visível para host, porta, vhost, usuário e senha.
- Adicionar exemplo visual VCL em `examples/VclQueueManager`, com conexão
  compartilhada, botões de operação, consumo separado e logs filtráveis por
  `Level` e `Kind`.

## Definição de pronto

- Exemplo abre no Delphi 10.4+ Win64.
- README documenta execução.
- Exemplo executa de ponta a ponta com RabbitMQ local usando as credenciais
  padrão `guest`/`guest`.
- Exemplo VCL compila em Delphi Win64.
