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
- **Nunca adicione atribuição de IA** em commits, PRs, tags ou releases: nada de `Co-Authored-By`, "Generated with…" ou autor "Claude". Todo commit sai com o `user.name`/`user.email` configurado no repositório.

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
- **Documentação sucinta e em linguagem natural:** frases curtas, organizadas por assunto, sem jargão nem repetição.
- **Offline-first e privacidade absoluta:** zero rastreadores, zero Firebase/Google Play Services/Analytics/Crashlytics, zero fontes externas carregadas da internet (todas embutidas em `app/assets/fonts/`).
- **Compatibilidade multiplataforma:** tudo deve funcionar em Android (inclusive F-Droid), iOS e Web/PWA (`sqlite3.wasm` + IndexedDB).
- **Organização de arquivos:**
  - `app/lib/core/` — tema, constantes, calendário e cores litúrgicas
  - `app/lib/data/` — SQLite/FTS5, modelos e repositórios
  - `app/lib/services/` — áudio/TTS, notificações locais, preferências, importadores modulares
  - `app/lib/features/` — telas agrupadas por funcionalidade
  - `scraper/` — coletor Python da Liturgia Diária
  - `scripts/` e `tool/` — scripts auxiliares de geração/padronização de bancos e assets (rode os que usam `requests` com `uv run --with requests python …`)

---

## 4. APIs Atualizadas, Ambiente Local e Verificação de Métodos

- **Nunca assuma contratos antigos de APIs externas ou pacotes:** antes de alterar integrações externas (ex.: API das Edições CNBB `api-liturgia.edicoescnbb.com.br`, Vatican News) ou atualizar dependências Flutter/Dart/Python, **consulte a documentação oficial na web e verifique as assinaturas/métodos atuais**.
- **Confira o sistema antes de usar uma ferramenta.** Aqui usamos **Fedora Workstation**: pacotes do sistema pelo `dnf` e ferramentas de desenvolvimento (Flutter/Dart, Java 21, Android CLI, Python/uv, Node) pelo `mise`, instaladas de forma global (shims em `~/.local/share/mise/shims`). O Android SDK fica em `~/Android/Sdk` (`ANDROID_HOME` no `mise`, `--sdk=` no `~/.androidrc`) e é gerenciado com `android sdk`; o `sdkmanager` está obsoleto. Outros sistemas podem usar outros gerenciadores. Antes de dizer que algo não existe, verifique com `command -v`, `mise ls`, `mise which flutter` e `flutter doctor`.
- **Peça antes de instalar.** Se faltar uma ferramenta (emulador, Android SDK, Chrome, Playwright, ferramentas de build…), diga o que falta, para que serve e o comando sugerido para o sistema detectado, e **peça ao usuário para instalar**. Não instale nada no sistema por conta própria.
- **Verificação de qualidade antes de concluir:**
  - **Flutter/Dart (`app/`):** `dart format --output=none --set-exit-if-changed lib test` (`page_width: 120` em `app/analysis_options.yaml`), `flutter analyze` (zero warnings/erros) e `flutter test`.
  - **Python:** `ruff check .` e `pytest` em `scraper/`, e `ruff check scripts tool` na raiz (`ruff.toml`).
  - **GitHub Actions:** sempre confirmar via `gh run list` / `gh run view` que o CI passou sem erros após o push.
- **Testes independentes do relógio:** datas fixas ou relativas a dias inteiros; nada de "agora + 1 h", que quebra perto da meia-noite UTC.
- **Teste a interface de ponta a ponta (E2E) antes de concluir** qualquer mudança visível ao usuário:
  - **Web:** `flutter build web` servido localmente e aberto no Chromium/Chrome (navegador integrado, Playwright ou equivalente); percorra o fluxo alterado e confira o console sem erros.
  - **Mobile:** emulador Android (`flutter emulators --launch medium_phone`), `flutter build apk --profile --target-platform android-x64`, `adb install -r …` e `adb logcat` durante o fluxo. Sem janela, toque pelos textos da tela com `adb shell uiautomator dump` + `adb shell input tap x y`. A voz neural só é testável num build com `tool/fetch_kokoro_model.py` rodado antes. **Antes de publicar, teste também o APK release** (`--release --target-platform android-arm64`; o emulador x86_64 traduz ARM): o R8 só encolhe código e recursos no release, e foi assim que o ícone da notificação sumiu na v1.6.0-beta.2. Recursos usados só pelo nome vão em `res/raw/keep.xml`.
  - **Memória:** a máquina de referência tem 7,4 GB. Nunca rode Gradle e emulador juntos (`adb emu kill` antes de compilar e `./gradlew --stop` depois); `~/.gradle/gradle.properties` limita o Gradle a 3 GB. O binário *headless* do emulador crasha aqui: use o emulador com janela.
  - Se a ferramenta não estiver instalada, peça a instalação (item acima). Se mesmo assim não der para testar, diga claramente o que ficou sem teste.

---

## 5. Releases Mobile (APK / IPA) e Tags Semânticas

Para permitir testar novas funcionalidades no celular (Android `.apk` e iOS `.ipa` sem assinatura), o workflow `.github/workflows/build-release.yml` compila e publica automaticamente os instaladores na aba **Releases** do GitHub sempre que uma tag `v*` é enviada:

- **Pré-releases de teste (a partir da `dev`):** após marcos relevantes (ex.: novo leitor WebView, melhorias de áudio/TTS, novos módulos offline), crie periodicamente uma tag de pré-release semântica `vX.Y.Z-beta.N` (ex.: `git tag v1.1.0-beta.1 && git push origin v1.1.0-beta.1`).
- **Releases estáveis (a partir da `main`):** somente após validação na `dev` e merge na `main`, crie uma tag estável `vX.Y.Z` (ex.: `v1.1.0`).
- **Antes de criar a tag** (o CI confere e falha se faltar algo):
  1. `app/pubspec.yaml`: `version: X.Y.Z+N`, com `N` (versionCode) maior que o da release anterior;
  2. `AppInfo.version` em `app/lib/core/constants.dart` e a receita `fdroid/io.github.juliaflima.via_sacra.yml` com a mesma versão (teste `app_version_test.dart`);
  3. notas da versão em `docs/releases/vX.Y.Z.md` (obrigatórias em releases estáveis) e changelog do F-Droid em `fastlane/metadata/android/pt-BR/changelogs/N.txt` (até 500 caracteres).
- **Artefatos gerados:** **um único `ViaSacra.apk`** (ARM 32 e 64 bits, todos os celulares) e `ViaSacra-unsigned.ipa`, com a voz Kokoro embutida (`tool/fetch_kokoro_model.py`) e sem dependências proprietárias (F-Droid ready). Não publique APKs por ABI nem universal: vários arquivos confundem quem baixa. Para o emulador, compile localmente com `--target-platform android-x64`.

---

## 6. Documentação enxuta (regra do bom escoteiro)

- **Deixe a documentação um pouco melhor do que encontrou, só onde você mexeu:** ao mudar um comportamento, atualize o trecho de `README.md`/`docs/` que trata dele no mesmo PR. Não reescreva documentos inteiros nem crie novos sem necessidade.
- **Um lugar para cada assunto:** o `README.md` resume e aponta para `docs/` (Bíblia, catecismos, banco, arquitetura, direitos autorais). Detalhes de implementação ficam em comentários no código, perto de onde valem.
- **O que mudou em cada versão** vai nas notas de `docs/releases/`, não espalhado pelos documentos.

---

## 7. Estado atual e próximos passos

**Versão em produção: v1.5.0** (`main`). Na `dev`: **v1.6.0-beta.3** (corrige o fechamento ao trocar de leitura no áudio — ícone da notificação apagado pelo R8 —, avançar/voltar no áudio narrado, fechamento por falta de memória ao trocar de voz e a demora da voz neural; Bíblia baixada sozinha na Web), aguardando teste no celular antes do PR `dev → main`.

**Fluxo usado até aqui:** uma branch por tarefa a partir da `dev` → PR para a `dev` → CI verde → merge e apagar a branch. Para lançar: subir a versão (seção 5), PR `dev → main`, tag `vX.Y.Z` e conferir Release e site.

**Onde fica cada coisa (atalhos):**

| Assunto | Arquivos |
|---|---|
| Voz neural (celular) | `services/native_tts_io.dart` (Kokoro embutido + Piper baixável, sherpa-onnx num Isolate; um modelo por vez) |
| Voz embutida no APK | `tool/fetch_kokoro_model.py` → `app/assets/voice/kokoro/` (partes + `manifest.json`, fora do git); `build-release.yml` e receita F-Droid rodam o script |
| Escolha do motor de voz | `SettingsService.ttsEngine`/`piperVoice` e `_VoiceSettings` em `features/settings/settings_screen.dart` |
| Voz neural (Web) | `web/kokoro_tts.js` e `web/kokoro_worker.js` (onnxruntime-web) |
| Fila de leitura e divisão do texto | `services/reading_audio_service.dart` (`splitForSpeech`, pré-síntese da leitura seguinte, um só `AudioPlayer`) |
| MP3 por leitura (marcas) | `scraper/generate_audio.py` grava `liturgia_audio_marcas`; `buildLiturgyQueue` recorta o MP3 com `ClippingAudioSource` |
| Diagnóstico da voz | builds profile/debug escrevem `VS-TTS …` no `adb logcat` (síntese, áudio, cancelamento, RTF do Kokoro) e `VS-TTS web` no console |
| Limpeza do texto para a voz | `services/neural_tts_types.dart` (`normalizeTextForKokoro`) |
| MP3 diários da Liturgia | `scraper/generate_audio.py` + `update-liturgy.yml` (branch `data`, via jsDelivr) |
| Arte sacra | `tool/sacred_art_catalog.json` → `tool/fetch_sacred_art.py` → `assets/data/sacred_art.json`; rodízio em `data/liturgical_art.dart` |
| Calendário litúrgico | `core/liturgical_calendar.dart` |
| Banco e migrações | `data/database.dart` (`PRAGMA user_version`) |
| Backup do usuário | `data/backup_repository.dart` |
| Conferência de versão | `tool/check_release_version.sh` |

**Pendências conhecidas:**

- **Revisão humana** da tradução do Catecismo de São Pio X (feita pelo projeto; italiano ao lado em `scripts/data/sao_pio_x_1905.json`).
- **Leitura mais natural:** expandir em `normalizeTextForKokoro` referências bíblicas ("Lc 19,41-44"), ordinais, abreviações ("S.", "N. Sra."), "R./V." e números romanos.
- **Áudio instantâneo** para conteúdo fixo (orações, Terço, Via Sacra): gerar MP3 no CI, como já é feito com a Liturgia.
- **Web:** onnxruntime-web e ephone ainda vêm do jsDelivr (hospedar junto do site); a voz roda numa só thread porque o GitHub Pages não envia COOP/COEP (avaliar `coi-serviceworker`).
- **Telas grandes** a dividir em widgets: `bible_screen.dart`, `catechism_screen.dart`, `settings_screen.dart`.
- **Kokoro em celulares lentos:** no emulador ele leva ~1,04× o tempo da fala (Piper: ~0,2×). Quando a média passa de 1,15×, as Configurações sugerem o Piper. Avaliar embutir o Piper Faber (CC0, ~35 MB) como reserva automática.
- **Voz na Web numa só thread:** sem COOP/COEP no GitHub Pages; avaliar cabeçalhos via `sw.js` (cuidado com o vídeo do YouTube).
- **Teste local da Web no navegador integrado:** ele não carrega `sw.js` nem `kokoro_worker.js` de um `python -m http.server`; teste a voz Web na prévia `/ViaSacra/dev/`.
- **Licença da voz Dii (Piper):** CC BY-NC-SA 4.0 (não comercial). Não vem no app, só é baixada a pedido; decidir se fica (F-Droid pode marcar como *NonFreeAssets*). Faber é CC0.
- **MP3 da Liturgia sem marcas** (gerados antes da v1.6.0-beta.2) são refeitos uma vez pelo `update-liturgy.yml`; até lá, avançar/voltar fica desativado nesses dias.
- **Pequenas limpezas restantes:** `widgets/keyboard_scroll.dart` reimplementa atalhos que o Flutter já oferece; o texto da Via Sacra está em constantes Dart (`via_sacra_screen.dart`) em vez de `assets/data/`; o catálogo da Bíblia na Web não mostra "Tentar de novo" se falhar.
- **Testes de tela:** `test/support/app_harness.dart` não suporta dois `buildServices` no mesmo arquivo (o 2º trava); use um arquivo por teste de fluxo.
