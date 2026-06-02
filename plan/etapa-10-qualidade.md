# Etapa 10: Qualidade Open Source

## Entregas

- Revisao da API publica.
- Consolidacao de testes.
- Guia de contribuicao.
- Preparacao de versao.
- Revisar compatibilidade de unidades e paths no Delphi 10.4+ Win64.
- Revisar possiveis deadlocks no fechamento de conexao, canais e consumers.
- Revisar tratamento de erros AMQP recebidos via `connection.close` e
  `channel.close`, incluindo reply code/reply text.
- Validar `connection.start` de forma completa, incluindo mecanismos SASL e
  locales anunciados pelo broker.
- Consolidar testes de contrato, codec e integracao em instrucoes reproduziveis.
- Verificar se arquivos gerados pelo Delphi continuam ignorados antes de
  publicar.

## Definicao de pronto

- Projeto compila limpo.
- Testes principais passam.
- Repositorio pronto para publicacao.
- Documentacao e exemplos refletem exatamente o estado da API publicada.
