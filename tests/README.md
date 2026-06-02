# Testes

`tests/ConsoleContracts/DelphiAMQP.Tests.Console.dpr` contém testes simples sem
dependências externas. Ele valida:

- Defaults de configuração.
- Conversão de mensagem texto/binário.
- Encode/decode inicial de frames AMQP.

Testes de integração com RabbitMQ serão adicionados quando o transporte TCP e o
handshake AMQP estiverem implementados.
