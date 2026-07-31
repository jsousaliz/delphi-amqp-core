# Contribuindo

## Índice

- [Diretrizes](#diretrizes)
- [Fluxo recomendado](#fluxo-recomendado)

## Diretrizes

- Mantenha a API pública baseada em interfaces.
- Evite dependências externas obrigatórias.
- Preserve compatibilidade com Delphi 10.4+ Win64.
- Adicione testes para novos comportamentos de protocolo.
- Documente mudanças públicas no [README](README.md),
  [`docs/architecture.md`](docs/architecture.md) ou
  [`docs/technical-guide.md`](docs/technical-guide.md).

## Artefatos locais

Compilações Delphi podem gerar `.dcu`, `.exe`, `.res`, `.rsm`,
`.identcache`, `.dproj.local` e pastas `__history/`. Esses arquivos são
artefatos locais e não devem ser versionados.

## Fluxo recomendado

1. Crie uma branch pequena e focada.
2. Implemente a mudança com testes.
3. Valide o exemplo quando a mudança afetar uso público.
4. Abra um pull request descrevendo comportamento e impacto.
