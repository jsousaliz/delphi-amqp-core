# Testes

`tests/ConsoleContracts/DelphiAMQP.Tests.Console.dpr` contem testes simples sem
dependencias externas. Ele valida:

- Defaults de configuracao.
- Conversao de mensagem texto/binario.
- Encode/decode inicial de frames AMQP.

Testes de integracao com RabbitMQ serao adicionados quando o transporte TCP e o
handshake AMQP estiverem implementados.
