# ConsoleStepByStep

Exemplo console didático por etapas.

Este exemplo organiza o fluxo em rotinas nomeadas para deixar claro cada passo:

- configurar conexão;
- conectar;
- abrir canal;
- declarar fila;
- iniciar consumer assíncrono;
- publicar mensagem;
- aguardar consumo;
- parar consumer;
- executar purge/delete;
- desconectar.

## Execução

```powershell
dcc64 -B DelphiAMQP.Example.ConsoleStepByStep.dpr
.\DelphiAMQP.Example.ConsoleStepByStep.exe
```
