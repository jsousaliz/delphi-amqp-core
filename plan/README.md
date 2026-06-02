# Development Plan Delphi AMQP Core

Este diretorio contem o planejamento operacional do projeto e serve como guia
para execucao por etapas.

## Etapas

1. [Fundação do repositório](etapa-01-fundacao.md)
2. [Arquitetura e contratos públicos](etapa-02-arquitetura-contratos.md)
3. [Codec AMQP 0-9-1](etapa-03-codec-amqp.md)
4. [Conexão e handshake](etapa-04-conexao-handshake.md)
5. [Filas e publicação](etapa-05-filas-publicacao.md)
6. [Consumo assíncrono](etapa-06-consumo-assincrono.md)
7. [Observabilidade](etapa-07-observabilidade.md)
8. [Projeto de exemplo](etapa-08-exemplo.md)
9. [Documentação final](etapa-09-documentacao.md)
10. [Qualidade open source](etapa-10-qualidade.md)

## Pendências identificadas após a Etapa 4

- Parsear `connection.start` de forma completa para validar mecanismo `PLAIN` e
  locale antes de enviar `connection.start-ok`.
- Criar uma fronteira interna clara entre `TAMQPConnection` e `TAMQPChannel`
  para envio/recebimento de frames por canal.
- Implementar helpers AMQP para bits, field tables, content header e content
  body antes de `basic.publish`.
- Atualizar a documentação técnica a cada nova etapa implementada.
