# Etapa 10: Qualidade Open Source

Status: implementada.

## Entregas

- Revisão da API pública.
- Consolidacao de testes.
- Separar testes de contrato sem dependência externa dos testes de integração
  real com RabbitMQ.
- Manter testes de contrato como suíte obrigatória para pipeline inicial.
- Manter testes de integração RabbitMQ em projeto separado e job opcional.
- Guia de contribuicao.
- Preparacao de versao.
- Revisar compatibilidade de unidades e paths no Delphi 10.4+ Win64.
- Revisar possíveis deadlocks no fechamento de conexão, canais e consumers.
- Revisar tratamento de erros AMQP recebidos via `connection.close` e
  `channel.close`, incluindo reply code/reply text.
- Validar `connection.start` de forma completa, incluindo mecanismos SASL e
  locales anunciados pelo broker.
- Documentar validação de `connection.start`, incluindo mecanismo `PLAIN` e
  locale `en_US`.
- Consolidar testes de contrato, codec e integração em instruções reproduzíveis.
- Verificar se arquivos gerados pelo Delphi continuam ignorados antes de
  publicar.
- Documentar que artefatos locais de build, como `.dcu`, `.exe`, `.res`,
  `.rsm`, `.identcache`, `.dproj.local` e `__history/`, não devem ser
  versionados.
- Implementar medição real de latência em `DurationMS` para operações
  bloqueantes principais, como `connection.open`, `channel.open`,
  `queue.declare`, `queue.purge`, `queue.delete` e `basic.consume`.
- Documentar operações que já registram `DurationMS`.

## Definicao de pronto

- Projeto compila limpo.
- Testes principais passam.
- Eventos de operações bloqueantes principais registram `DurationMS` quando
  aplicável.
- Repositório pronto para publicação.
- Documentação e exemplos refletem exatamente o estado da API publicada.
