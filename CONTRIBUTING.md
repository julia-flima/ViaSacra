# Contribuindo com o Via Sacra

Obrigada por querer ajudar! 🙏 O Via Sacra é um projeto comunitário, sem fins lucrativos, mantido por **Júlia Lima** e colaboradores.

## Formas de contribuir

| Você é… | Como ajudar |
|---|---|
| Usuária(o) | Relatar bugs, sugerir melhorias, avisar sobre erros em orações ou textos |
| Revisor(a) de textos / catequista | Corrigir orações, traduções latinas, frutos dos mistérios |
| Designer | Ícones, screenshots, acessibilidade, melhorias de UI |
| Dev Flutter / Python | Código, testes, scraper, CI/CD |
| Tradutor(a) | Novos idiomas (en, es, it, la) |

## Antes de começar

1. Procure nas [issues](https://github.com/julia-flima/ViaSacra/issues) se o assunto já foi discutido.
2. Para mudanças grandes, abra uma issue primeiro para combinarmos a abordagem.
3. Leia o [Código de Conduta](CODE_OF_CONDUCT.md).

## Regras inegociáveis (F-Droid e privacidade)

- **Nenhuma** dependência proprietária: sem Firebase, Google Play Services, Google Analytics, Crashlytics, AdMob, Sentry SaaS, etc.
- Toda dependência nova precisa ter licença compatível com GPL-3.0 (MIT, BSD, Apache-2.0, MPL-2.0, LGPL, GPL). Informe a licença no PR.
- Nenhuma requisição de rede além das fontes de dados documentadas em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Nenhuma fonte (font) baixada em tempo de execução (ex.: `google_fonts`) — fontes devem ser empacotadas (OFL) ou do sistema.
- Conteúdo protegido por direitos autorais **não** entra no repositório sem permissão por escrito (veja [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md)). Imagens: apenas domínio público / CC0, com título, autor e origem.

## Fluxo de trabalho

```bash
git checkout -b feat/minha-melhoria
```

```bash
cd app && flutter pub get && flutter analyze && flutter test
```

```bash
cd scraper && pip install -r requirements.txt && python -m pytest -q
```

Depois abra um Pull Request preenchendo o template.

## Padrão de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/pt-br/), em português ou inglês:

```
<tipo>(<escopo opcional>): <descrição no imperativo>
```

| Tipo | Uso |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `texto` | Correção/adição de orações, leituras, frutos, legendas de arte |
| `docs` | Documentação |
| `style` | Formatação (sem mudança de lógica) |
| `refactor` | Refatoração |
| `test` | Testes |
| `ci` | GitHub Actions |
| `chore` | Manutenção, dependências |
| `data` | Atualização automática de JSONs (reservado ao bot) |

Exemplos: `feat(terco): adiciona vibração dupla ao concluir a dezena` · `texto(oracoes): corrige versão latina do Salve Regina`.

## Corrigindo orações e textos

As orações ficam em [`app/assets/data/prayers.json`](app/assets/data/prayers.json) e os mistérios em [`app/assets/data/mysteries.json`](app/assets/data/mysteries.json). Ao propor correção:

1. Cite a **fonte** (ex.: Compêndio do CIC, Missal Romano, *Enchiridion Indulgentiarum*, site da Santa Sé).
2. Mantenha a grafia oficial usada no Brasil (CNBB) para o português.
3. Não altere o campo `id` (é usado para favoritos salvos nos aparelhos).

Se preferir, abra uma issue com o modelo **"Correção de texto"** (bug report) — não precisa saber Git.

## Estilo de código

- **Dart:** `dart format .` e `flutter analyze` sem avisos (regras em `app/analysis_options.yaml`).
- **Python:** PEP 8, tipagem (`from __future__ import annotations`), funções pequenas e testáveis; `ruff` recomendado.
- Textos de interface em pt-BR, com acentuação correta.
- Acessibilidade: todo botão com ícone precisa de `tooltip` ou `Semantics`.

## Revisão

Todo PR precisa de ao menos uma revisão aprovada e CI verde. A mantenedora pode pedir ajustes — é parte do processo, não é pessoal. 💛

## Licença das contribuições

Ao contribuir, você concorda que seu código será licenciado sob a [GPL-3.0](LICENSE).
