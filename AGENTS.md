# AGENTS.md — Guia para Agentes e Contribuidores do Via Sacra

Este arquivo define as regras de engenharia, fluxo de branches e princípios doutrinários que todo agente de IA e contribuidor deve seguir ao trabalhar no repositório **Via Sacra**.

---

## 1. Fluxo de Branches e Deploy

O repositório utiliza exatamente **quatro branches** com papéis bem definidos:

| Branch | Papel | Dispara CI? | Dispara Deploy Web (GitHub Pages)? |
|---|---|---|---|
| `main` | **Produção / Deployment.** Sempre estável e verde no CI. | Sim (`ci.yml`) | **Sim — Produção** (`deploy-web.yml` → `/ViaSacra/`) |
| `dev` | **Desenvolvimento contínuo.** Todo novo recurso, experimento e correção deve nascer aqui ou em branches a partir de `dev`. | Sim (`ci.yml`) | **Prévia isolada** (`deploy-dev-preview.yml` → `/ViaSacra/dev/`, sem tocar na produção) |
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
  - **Python:** `ruff check .` e `pytest` em `scraper/`, e `ruff check scripts tool` na raiz (`ruff.toml`).
  - **GitHub Actions:** sempre confirmar via `gh run list` / `gh run view` que o CI passou sem erros após o push.

---

## 5. Releases Mobile (APK / IPA) e Tags Semânticas

Para permitir testar novas funcionalidades no celular (Android `.apk` e iOS `.ipa` sem assinatura), o workflow `.github/workflows/build-release.yml` compila e publica automaticamente os instaladores na aba **Releases** do GitHub sempre que uma tag `v*` é enviada:

- **Pré-releases de teste (a partir da `dev`):** após marcos relevantes (ex.: novo leitor WebView, melhorias de áudio/TTS, novos módulos offline), crie periodicamente uma tag de pré-release semântica `vX.Y.Z-beta.N` (ex.: `git tag v1.1.0-beta.1 && git push origin v1.1.0-beta.1`).
- **Releases estáveis (a partir da `main`):** somente após validação na `dev` e merge na `main`, crie uma tag estável `vX.Y.Z` (ex.: `v1.1.0`).
- **Antes de criar a tag** (o CI confere e falha se faltar algo):
  1. `app/pubspec.yaml`: `version: X.Y.Z+N`, com `N` (versionCode) maior que o da release anterior;
  2. `AppInfo.version` em `app/lib/core/constants.dart` e a receita `fdroid/io.github.juliaflima.via_sacra.yml` com a mesma versão (teste `app_version_test.dart`);
  3. notas da versão em `docs/releases/vX.Y.Z.md` (obrigatórias em releases estáveis) e changelog do F-Droid em `fastlane/metadata/android/pt-BR/changelogs/N.txt` (até 500 caracteres).
- **Artefatos gerados:** `ViaSacra-universal.apk`, APKs por ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) e `ViaSacra-unsigned.ipa`, todos verificados sem dependências proprietárias (F-Droid ready).

---

## 6. Documentação enxuta (regra do bom escoteiro)

- **Deixe a documentação um pouco melhor do que encontrou, só onde você mexeu:** ao mudar um comportamento, atualize o trecho de `README.md`/`docs/` que trata dele no mesmo PR. Não reescreva documentos inteiros nem crie novos sem necessidade.
- **Um lugar para cada assunto:** o `README.md` resume e aponta para `docs/` (Bíblia, catecismos, banco, arquitetura, direitos autorais). Detalhes de implementação ficam em comentários no código, perto de onde valem.
- **O que mudou em cada versão** vai nas notas de `docs/releases/`, não espalhado pelos documentos.
