# Etapa 3: Codec AMQP 0-9-1

Status: implementada.

## Entregas

- Encode/decode de frames.
- Serializacao binaria de inteiros e short strings.
- Suporte inicial a method frames, content header/body e heartbeat.

## Definicao de pronto

- Testes com frames conhecidos.
- Erros de protocolo tratados.
- Operacoes com timeout nas camadas superiores.
