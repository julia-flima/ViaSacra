# AGENTS.md — Guia para Agentes e Contribuidores do Via Sacra

Este arquivo define as regras de engenharia, fluxo de branches e princípios doutrinários que todo agente de IA e contribuidor deve seguir ao trabalhar no repositório **Via Sacra**.

---

## 1. Fluxo de Branches e Deploy

O repositório utiliza exatamente **quatro branches** com papéis bem definidos:

| Branch | Papel | Dispara CI? | Dispara Deploy Web (GitHub Pages)? |
|---|---|---|---|
| `main` | **Produção / Deployment.** Sempre estável e verde no CI. | Sim (`ci.yml`) | **Sim** (`deploy-web.yml` → `gh-pages`) |
| `dev` | **Desenvolvimento contínuo.** Todo novo recurso, experimento e correção deve nascer aqui ou em branches a partir de `dev`. | Sim (`ci.yml`) | **Não** |
| `data` | **Automática (bot).** JSONs diários da Liturgia gerados pelo GitHub Actions (`update-liturgy.yml`). Nunca editar manualmente. | Não | Não |
| `gh-pages` | **Automática (bot).** Build estático da versão Web/PWA publicado a partir da `main`. Nunca editar manualmente. | Não | — |

**Regras obrigatórias:**
- **Trabalhe na branch `dev`** durante o desenvolvimento para validar código e testes no CI sem republicar o GitHub Pages a cada ajuste.
- Só faça merge/push para a **`main`** quando as alterações estiverem testadas, formatadas e prontas para produção.
- Não deixe branches temporárias abandonadas no repositório após concluir uma tarefa.

---

## 2. Respeito à Doutrina, Liturgia e Tradição Católica

O Via Sacra é um aplicativo devocional católico. Qualquer alteração de conteúdo ou lógica litúrgica deve respeitar rigorosamente:

- **Fidelidade ao Magistério e aos textos sagrados:** nunca alterar, resumir arbitrariamente ou parafrasear textos bíblicos, orações tradicionais ou leituras litúrgicas.
- **Cânon Católico completo (73 livros):** 46 livros do Antigo Testamento (incluindo os **deuterocanônicos**: Tobias, Judite, 1–2 Macabeus, Sabedoria, Eclesiástico e Baruc, além das partes gregas de Ester e Daniel) e 27 do Novo Testamento. A fonte única de verdade é `tool/bible/canon.py`.
- **Calendário e Cores Litúrgicas:** respeitar os tempos litúrgicos (Advento, Natal, Quaresma, Páscoa, Tempo Comum), solenidades, memórias, ciclos dominicais (A/B/C) e feriais (I/II), e os mistérios do Santo Terço por dia da semana.
- **Conformidade 100% FOSS / F-Droid e Direitos Autorais:**
  - Somente obras em **Domínio Público** podem ser embutidas no repositório (ex.: Vulgata Clementina, Figueiredo, Catecismo Maior de São Pio X, Catecismo Romano de Trento, Santos Padres).
  - Obras protegidas (CNBB, Ave-Maria, Jerusalém, Pastoral, CIC 1992) **nunca** devem ser hospedadas no repositório — o app oferece acesso oficial (`vatican.va`) e importadores locais `.json` no aparelho do usuário.
  - Atribuir explicitamente todas as fontes na interface (CNBB / Edições CNBB, Vatican News, Domínio Público).

---

## 3. Simplicidade, Organização e Melhores Práticas

- **Código simples e sucinto:** prefira soluções diretas, legíveis e sem abstrações desnecessárias (*over-engineering*). Se algo pode ser resolvido de forma clara em 20 linhas, não crie 3 camadas extras.
- **Offline-first e privacidade absoluta:** zero rastreadores, zero Firebase/Google Play Services/Analytics/Crashlytics, zero fontes externas carregadas da internet (todas embutidas em `app/assets/fonts/`).
- **Compatibilidade multiplataforma:** tudo deve funcionar em Android (inclusive F-Droid), iOS e Web/PWA (`sqlite3.wasm` + IndexedDB).
- **Organização de arquivos:**
  - `app/lib/core/` — tema, constantes, calendário e cores litúrgicas
  - `app/lib/data/` — SQLite/FTS5, modelos e repositórios
  - `app/lib/services/` — áudio/TTS, notificações locais, preferências, importadores modulares
  - `app/lib/features/` — telas agrupadas por funcionalidade
  - `scraper/` — coletor Python da Liturgia Diária
  - `scripts/` e `tool/` — scripts auxiliares de geração/padronização de bancos e assets

---

## 4. APIs Atualizadas, Ambiente Local e Verificação de Métodos

- **Nunca assuma contratos antigos de APIs externas ou pacotes:** antes de alterar integrações externas (ex.: API das Edições CNBB `api-liturgia.edicoescnbb.com.br`, Vatican News) ou atualizar dependências Flutter/Dart/Python, **consulte a documentação oficial na web e verifique as assinaturas/métodos atuais**.
- **Ambiente local com `mise`:** neste ambiente, **Flutter/Dart** e **Python/uv** podem estar instalados globalmente via `mise` (shims em `~/.local/share/mise/shims`). Antes de assumir que `flutter` ou `dart` não existem, verifique o `PATH`, `mise which flutter` ou rode com `mise exec -- flutter ...`.
- **Verificação de qualidade antes de concluir:**
  - **Flutter/Dart (`app/`):** `dart format --output=none --set-exit-if-changed lib test` (`page_width: 120` em `app/analysis_options.yaml`), `flutter analyze` (zero warnings/erros) e `flutter test`.
  - **Python (`scraper/` e `scripts/`):** `ruff check .` e `pytest`.
  - **GitHub Actions:** sempre confirmar via `gh run list` / `gh run view` que o CI passou sem erros após o push.
