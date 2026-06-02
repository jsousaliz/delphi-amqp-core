# Etapa 5: Filas e Publicação

Status: implementada.

## Entregas

- Revisar a fronteira interna entre conexão e canal para permitir que o canal
  envie frames e aguarde replies pelo `ChannelId` sem expor transporte TCP na
  API pública.
- Parsear `connection.start` para validar se o servidor anunciou mecanismo
  `PLAIN` e locale `en_US`; se não houver suporte, retornar erro claro.
- Implementar helpers de protocolo para bits AMQP, field table vazia, content
  header e content body.
- Adicionar constantes AMQP de `queue` e `basic` com nomes explicitos.
- `queue.declare`.
- `queue.delete`.
- `queue.purge`.
- `basic.publish`.
- Propriedades basicas de mensagem.
- Leitura dos replies: `queue.declare-ok`, `queue.delete-ok`, `queue.purge-ok`
  e retorno controlado para `basic.publish` quando aplicavel.
- Documentar que publisher confirms ainda não fazem parte desta etapa, salvo
  decisao explicita antes da implementacao.

## Definicao de pronto

- Exemplo cria fila, publica, limpa e remove fila.
- Teste de integração valida operações AMQP.
- Testes unitários validam encode dos métodos de `queue` e `basic.publish`.
- Documentação técnica explica frames de método, content header e content body
  usados na publicação.
