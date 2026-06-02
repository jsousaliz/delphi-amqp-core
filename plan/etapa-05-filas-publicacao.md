# Etapa 5: Filas e Publicacao

Status: implementada inicialmente. Manter este arquivo para revisao final e
eventuais ajustes de publisher confirms/propriedades.

## Entregas

- Revisar a fronteira interna entre conexao e canal para permitir que o canal
  envie frames e aguarde replies pelo `ChannelId` sem expor transporte TCP na
  API publica.
- Parsear `connection.start` para validar se o servidor anunciou mecanismo
  `PLAIN` e locale `en_US`; se nao houver suporte, retornar erro claro.
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
- Documentar que publisher confirms ainda nao fazem parte desta etapa, salvo
  decisao explicita antes da implementacao.

## Definicao de pronto

- Exemplo cria fila, publica, limpa e remove fila.
- Teste de integracao valida operacoes AMQP.
- Testes unitarios validam encode dos metodos de `queue` e `basic.publish`.
- Documentacao tecnica explica frames de metodo, content header e content body
  usados na publicacao.
