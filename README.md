<div align="center">

# ✝ Via Sacra

**Liturgia Diária, Bíblia Sagrada, Santo Terço, Catecismo e Orações — gratuito, sem anúncios, sem rastreadores, offline.**

### [▶ Usar agora no navegador](https://julia-flima.github.io/ViaSacra/) — iPhone, Android e computador, sem baixar nada

[![Licença: GPL v3](https://img.shields.io/badge/Licen%C3%A7a-GPL--3.0-B8860B.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![F-Droid Ready](https://img.shields.io/badge/F--Droid-ready-1976D2?logo=f-droid&logoColor=white)](https://f-droid.org)
[![Web PWA](https://img.shields.io/badge/Web-PWA-B8860B?logo=googlechrome&logoColor=white)](https://julia-flima.github.io/ViaSacra/)
[![Release Android](https://img.shields.io/github/v/release/julia-flima/ViaSacra?label=Android%20APK&logo=android&color=3DDC84)](https://github.com/julia-flima/ViaSacra/releases/latest)
[![Release iOS](https://img.shields.io/github/v/release/julia-flima/ViaSacra?label=iOS%20IPA&logo=apple&color=555555)](https://github.com/julia-flima/ViaSacra/releases/latest)
[![Atualização da Liturgia](https://github.com/julia-flima/ViaSacra/actions/workflows/update-liturgy.yml/badge.svg)](https://github.com/julia-flima/ViaSacra/actions/workflows/update-liturgy.yml)

Idealizado e desenvolvido por **Júlia Lima**.

</div>

---

## Sumário

- [Filosofia](#filosofia)
- [Funcionalidades](#funcionalidades)
- [Instalação para usuários (sem programar)](#instalação-para-usuários-sem-programar)
  - [Usar agora pelo navegador (sem baixar nada)](#-usar-agora-pelo-navegador-ios-e-android--sem-baixar-nada)
  - [Android](#android)
  - [iOS (iPhone / iPad)](#ios-iphone--ipad)
- [Instalação para desenvolvedores](#instalação-para-desenvolvedores)
- [Traduções da Bíblia e catecismos](#traduções-da-bíblia-e-catecismos)
- [Arquitetura](#arquitetura)
- [Fontes, direitos autorais e créditos](#fontes-direitos-autorais-e-créditos)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

## Filosofia

O Via Sacra nasceu para ser um companheiro de oração **silencioso e respeitoso**:

| Princípio | O que significa na prática |
|---|---|
| **100% gratuito** | Sem compras, assinaturas ou "versão premium". Nunca. |
| **Sem anúncios** | Nenhum SDK de publicidade. |
| **Sem rastreadores** | Sem Firebase, Google Analytics, Crashlytics ou telemetria. O app não sabe quem você é. |
| **Offline-first** | Orações, Catecismo, Terço e leitura em voz alta (TTS) funcionam sem internet. As liturgias baixadas ficam em cache. |
| **Open Source** | Código sob GPL-3.0, auditável e compatível com o F-Droid. |
| **Sem pressão** | O contador de constância é opcional, discreto e nunca punitivo. Notificações só se você pedir. |

## Funcionalidades

1. **Liturgia & Homilias** — leituras do dia (1ª Leitura, Salmo com refrão em destaque, 2ª Leitura, Evangelho), cabeçalho com Tempo e Cor Litúrgica e uma obra de arte sacra que muda a cada dia (com obra própria nas festas), player "Ouvir Liturgia" (TTS offline ou áudio aberto), homilia do Vaticano e reflexões CNBB / Santos Padres, **Santo do dia** (resumo do Vatican News com link para a história completa), modo Lectio Divina em tela cheia, calendário e os próximos 7 dias salvos offline automaticamente.
2. **Bíblia Sagrada (73 livros, cânon católico)** — Antigo Testamento com os deuterocanônicos e Novo Testamento; seletor Livro › Capítulo, "Continuar lendo", busca offline por referência ("Jo 3,16") ou palavra (FTS5), leitura comparada versículo a versículo, marcações em cores suaves, favoritos e anotações locais, compartilhamento formatado e áudio do capítulo (TTS). Traduções modulares: **Bíblia Portuguesa Mundial (pt-BR)**, **Vulgata Clementina (Latim)** e **Douay-Rheims (Inglês)** embutidas (domínio público) e importação local de módulos — ver [`docs/BIBLE.md`](docs/BIBLE.md). Na Liturgia, tocar na referência de uma leitura abre o capítulo completo.
3. **Santo Terço & Rosário** — mistérios do dia automáticos, Rosário completo (20 mistérios), arte sacra em domínio público, contador tátil com vibração e registro opcional de constância.
4. **Biblioteca** — duas sub-abas: **Catecismo** — índice das 4 partes do CIC (texto oficial no vatican.va) e Catecismo Maior de São Pio X com busca offline (SQLite FTS5) por número ou palavra, favoritos e anotações locais; e **Devocionário**, com orações fundamentais, eucarísticas, marianas e de proteção, com alternância Português ⇄ Latim.
   A Biblioteca traz também **A Imitação de Cristo** (114 capítulos, com "Continuar lendo" e favoritos) e a **Via Sacra** de Santo Afonso (14 estações).
5. **Ajustes** — lembretes locais (Liturgia e Terço), voz e velocidade do narrador, tipografia, temas Pergaminho / Modo Igreja / Automático, **backup** (exportar/importar favoritos, anotações, constância e marcações) e página "Sobre & Licenças".

O áudio usa a voz neural **Kokoro-82M** (vozes Dora e Alex). A Liturgia e a homilia do dia vêm em MP3 pronto, gerado todo dia nas duas vozes, que toca na hora. O resto é sintetizado no aparelho, sem internet. O modo **Automático** escolhe a melhor voz que o aparelho aguenta (Kokoro, Piper ou a voz do sistema). Decisões e próximos passos: [`docs/AUDIO.md`](docs/AUDIO.md). Um **mini-player** acompanha a leitura em todas as telas.

## Instalação para usuários (sem programar)

### ⭐ Usar agora pelo navegador (iOS e Android — sem baixar nada)

A forma mais simples: o Via Sacra funciona como um **aplicativo web (PWA)**. Depois de adicionado à
tela inicial, ele abre em tela cheia, como um app, e **funciona mesmo sem internet**.

**Endereço: <https://julia-flima.github.io/ViaSacra/>**

**No iPhone / iPad (Safari)**

1. Abra o link acima no **Safari**.
2. Toque em **Compartilhar** (o quadrado com a seta ↑) → **Adicionar à Tela de Início**.

**No Android (Chrome)**

1. Abra o link acima no **Chrome**.
2. Toque em **Instalar aplicativo** (ou no menu **⋮** → **Adicionar à tela inicial**).

> A versão web tem Liturgia, Bíblia, Terço, Catecismo, Orações e leitura em voz alta. Os **lembretes**
> chegam na hora com o site aberto; fechado, só no Chrome com o app instalado e em horário aproximado.
> Para lembretes pontuais, use o app nativo para Android e iOS, abaixo.

### Android

**Opção 1 — Download direto (mais simples)**

1. No celular, abra a página **[Releases](https://github.com/julia-flima/ViaSacra/releases/latest)**.
2. Em **Assets**, toque em **`ViaSacra.apk`**: é um arquivo só, que funciona em qualquer celular Android.
3. Abra o arquivo baixado. Se o Android pedir, toque em **Configurações → Permitir desta fonte** e volte.
4. Toque em **Instalar**. Pronto! 🙏

**Opção 2 — Obtainium (atualizações automáticas direto do GitHub)**

1. Instale o [Obtainium](https://github.com/ImranR98/Obtainium).
2. Toque em **Adicionar app** e cole: `https://github.com/julia-flima/ViaSacra`
3. Toque em **Adicionar**. O Obtainium avisará quando houver nova versão.

**Opção 3 — F-Droid**

Assim que o app for aceito no repositório oficial, basta procurar por **Via Sacra** no [F-Droid](https://f-droid.org). Os metadados já estão em [`fastlane/metadata/android`](fastlane/metadata/android).

**Opção 4 — Google Play** *(planejado)* — o mesmo APK assinado poderá ser publicado na Play Store.

### iOS (iPhone / iPad)

A Apple não permite instalar arquivos diretamente como no Android. Há dois caminhos:

**Opção 1 — AltStore / SideStore (gratuito, com seu Apple ID)**

1. Instale o **[AltStore](https://altstore.io)** (precisa de um computador na primeira vez) ou o **[SideStore](https://sidestore.io)** (dispensa computador após a configuração).
2. No iPhone, abra a página **[Releases](https://github.com/julia-flima/ViaSacra/releases/latest)** e baixe **`ViaSacra-unsigned.ipa`**.
3. Toque em **Compartilhar → Abrir com AltStore/SideStore** (ou, dentro do app, **My Apps → +** e escolha o `.ipa`).
4. O AltStore/SideStore assina o app com o seu Apple ID. Em **Ajustes → Geral → VPN e Gerenciamento de Dispositivo**, confie no seu perfil, se solicitado.
5. Com Apple ID gratuito, o app precisa ser renovado a cada 7 dias — o AltStore/SideStore faz isso automaticamente.

> **TrollStore:** em aparelhos compatíveis, abra o `.ipa` com o TrollStore e toque em **Install** (sem expiração).

**Opção 2 — TestFlight / App Store** *(planejado)*

Quando disponível, o link do TestFlight será publicado aqui e nas Releases. Basta instalar o app **TestFlight** da Apple e tocar no convite.

## Instalação para desenvolvedores

### Pré-requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) **3.50+** (canal stable) e Dart 3.13+
- Android: SDK e emulador (pelo [Android CLI](https://developer.android.com/tools/agents/android-cli) ou pelo Android Studio) e um **JDK 21** completo (com `javac`)
- iOS: macOS com Xcode 15+ e CocoaPods
- Python **3.11+** (scraper e scripts de `tool/`)

No projeto usamos o [mise](https://mise.jdx.dev) para instalar tudo isso de forma global. Ambiente de referência (Fedora):

```bash
mise use -g flutter@3.50.0 java@temurin-21 android-cli python uv && mise set --global ANDROID_HOME="$HOME/Android/Sdk"
```

```bash
android sdk install platform-tools emulator platforms/android-37.0 build-tools/37.0.0 system-images/android-36/google_apis/x86_64 && android emulator create medium_phone && flutter config --android-sdk "$ANDROID_HOME" --jdk-dir "$(mise where java@temurin-21)"
```

Plataformas novas do SDK têm nomes como `platforms/android-37.0`; confira com `android sdk list --all`.

### Rodando o app

```bash
git clone https://github.com/julia-flima/ViaSacra.git
```

```bash
cd ViaSacra/app
```

```bash
flutter pub get
```

```bash
flutter run            # escolhe automaticamente um emulador/aparelho conectado
```

A voz neural Kokoro vai dentro do APK/IPA. Antes de compilar um instalador, prepare-a (≈140 MB, SHA-256 conferido, fora do git). Sem ela o app funciona e lê com a voz do aparelho:

```bash
python3 ../tool/fetch_kokoro_model.py
```

Compilando instaladores localmente:

```bash
flutter build apk --release --target-platform android-arm,android-arm64   # o mesmo ViaSacra.apk da Release
```

```bash
flutter build apk --profile --target-platform android-x64                 # para o emulador
```

A Release publica **um único APK** (`ViaSacra.apk`, ARM 32/64 bits), para ninguém ficar em dúvida sobre qual baixar. O `app/android/app/build.gradle.kts` só empacota as arquiteturas pedidas em `--target-platform`.

```bash
flutter build ios --release --no-codesign     # iOS sem assinatura (macOS)
```

Versão Web/PWA (o banco offline usa `sqlite3.wasm`, baixado pelo script):

```bash
bash ../tool/fetch_sqlite_wasm.sh   # baixa app/web/sqlite3.wasm (versão casada com o pubspec.lock)
```

```bash
flutter run -d chrome
```

```bash
flutter build web --release --no-web-resources-cdn --base-href "/ViaSacra/"
```

O endpoint de dados é configurável em tempo de build (útil para forks):

```bash
flutter run --dart-define=VIA_SACRA_DATA_URL=https://cdn.jsdelivr.net/gh/SEU_USUARIO/ViaSacra@data
```

### Antes de enviar alterações

Na pasta `app/`:

```bash
dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test
```

Na raiz (scripts Python e scraper):

```bash
ruff check . && (cd scraper && python -m pytest -q)
```

Mudanças visíveis também são testadas no app de verdade:

- **Android:** emulador (`flutter emulators --launch medium_phone`), `flutter build apk --profile --target-platform android-x64`, `adb install -r` e `adb logcat` para ver erros. Em máquinas com pouca memória, não rode o Gradle e o emulador ao mesmo tempo.
- **Web:** `flutter build web` e o site servido localmente, aberto no Chrome/Chromium com o console sem erros (para o Flutter achar o Chromium: `CHROME_EXECUTABLE=/usr/bin/chromium-browser`).

### Rodando o scraper

```bash
cd scraper && python -m venv .venv && . .venv/bin/activate
```

```bash
pip install -r requirements.txt
```

```bash
python scraper.py --days 7 --out ../data       # hoje + 6 dias
```

```bash
python -m pytest -q                             # testes com páginas de exemplo (offline)
```

Veja todas as opções com `python scraper.py --help`.

### Assinatura do APK de release (opcional)

O workflow de release assina os APKs se estes *secrets* existirem no repositório: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Sem eles, os APKs são assinados com a chave de debug (funcionam, mas não atualizam por cima de uma versão assinada com outra chave). Para o F-Droid, o próprio F-Droid compila e assina a partir do código-fonte.

## Traduções da Bíblia e catecismos

A Bíblia traz embutidas a **Bíblia Portuguesa Mundial** (pt-BR), a **Vulgata Clementina** e a
**Douay-Rheims**, todas em domínio público. Outras traduções (inclusive as protegidas, com
autorização do titular) podem ser importadas no aparelho em **Ajustes → Gerenciar e Importar
Traduções**. Formato dos módulos e scripts de conversão: [`docs/BIBLE.md`](docs/BIBLE.md).

Catecismos (São Pio X embutido, índice do CIC e importador local): [`docs/CATECHISM.md`](docs/CATECHISM.md).

## Arquitetura

```
ViaSacra/
├── app/                    # Aplicativo Flutter (Android + iOS + Web/PWA)
│   ├── lib/
│   │   ├── core/           # tema, cores litúrgicas, calendário, constantes
│   │   ├── data/           # modelos, SQLite (FTS5), repositórios, Bíblia
│   │   │   └── platform/   # abertura do banco: arquivo (nativo) · WASM+IndexedDB (web)
│   │   ├── services/       # TTS/áudio, notificações locais, Bíblia (módulos), preferências
│   │   └── features/       # liturgia, bíblia, terço, biblioteca, ajustes
│   ├── assets/             # orações, mistérios, arte, Bíblia (módulos), fontes, schema SQL
│   └── web/                # index.html, manifest.json, sw.js (PWA offline)
├── scraper/                # Coletor Python (requests + BeautifulSoup4)
├── data/                   # JSONs gerados (branch `data`, servidos via jsDelivr)
├── fastlane/metadata/      # Metadados do F-Droid
├── docs/                   # Arquitetura, banco, Bíblia, catecismos, direitos autorais, notas das releases
└── .github/workflows/      # update-liturgy.yml · build-release.yml · deploy-web.yml · ci.yml
```

Fluxo de dados:

```
GitHub Actions (00:05 BRT) ─► scraper.py ─► data/liturgia/AAAA-MM-DD.json ─► branch `data`
                                                                           │
             App (offline-first) ◄── jsDelivr CDN / GitHub Pages ◄─────────┘
                    │
                    └─► SQLite local (cache litúrgico, CIC FTS5, favoritos, constância)
```

Documentação detalhada: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/AUDIO.md`](docs/AUDIO.md) · [`docs/DATABASE.md`](docs/DATABASE.md) · [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) · [`docs/BIBLE.md`](docs/BIBLE.md) · [`docs/CATECHISM.md`](docs/CATECHISM.md) · [`docs/SACRED_ART.md`](docs/SACRED_ART.md) · [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md) · [`docs/releases/`](docs/releases/)

## Fontes, direitos autorais e créditos

O Via Sacra **não tem fins lucrativos** e atribui todas as fontes explicitamente na interface, com link para o original.

| Conteúdo | Fonte | Uso |
|---|---|---|
| Leituras da Liturgia Diária | [CNBB — liturgiadiaria.edicoescnbb.com.br](https://liturgiadiaria.edicoescnbb.com.br) | Devocional, não comercial, com atribuição "Fonte: CNBB / Edições CNBB" |
| Homilias e reflexões do Papa | [Vatican News (Português)](https://www.vaticannews.va/pt.html) / © Libreria Editrice Vaticana / Dicastério para a Comunicação | Uso pastoral não comercial com citação e link |
| Santo do dia (resumo) | [Vatican News (Português)](https://www.vaticannews.va/pt/santo-do-dia.html) / © Libreria Editrice Vaticana / Dicastério para a Comunicação | Só o resumo do dia, com citação e link para a história completa |
| Comentários patrísticos | Santo Agostinho, São João Crisóstomo, *Catena Aurea* (São Tomás de Aquino) | Domínio público |
| Arte sacra | Wikimedia Commons, The Met Open Access, National Gallery of Art (CC0) | Domínio público — ver [`docs/SACRED_ART.md`](docs/SACRED_ART.md) |
| Bíblia — Bíblia Portuguesa Mundial (pt-BR, 73 livros) | [eBible.org (`porbrbsl`)](https://ebible.org/porbrbsl/) | Domínio público (embutida) |
| Bíblia — Vulgata Clementina e Douay-Rheims | Clementine Vulgate Project / revisão Challoner, via [mborders/vulgata](https://github.com/mborders/vulgata) | Domínio público (embutidas) |
| Bíblia — CNBB, Ave-Maria, Jerusalém, Pastoral | © respectivas editoras | **Não incluídas**; apenas importação local de módulos autorizados — ver [`docs/BIBLE.md`](docs/BIBLE.md) e [`docs/autorizacoes/`](docs/autorizacoes/) |
| Fontes tipográficas | Merriweather (SIL OFL), Roboto (Apache-2.0), DejaVu (livre) | Embutidas — nenhuma fonte é baixada da internet |
| Catecismo da Igreja Católica | © Libreria Editrice Vaticana | **Não incluído** no repositório; importável mediante licença — ver [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md) |
| Catecismo Maior de São Pio X | Original de 1905 (Tipografia Vaticana), domínio público | Embutido — tradução do projeto, em domínio público (CC0) |
| A Imitação de Cristo | Trad. E. L. de Souza Campos, © 2023 Valdemar Teodoro Editor | Embutida — cópia e divulgação permitidas com citação da fonte |
| Voz neural | Kokoro-82M, sherpa-onnx (Apache-2.0), eSpeak-NG (GPL-3.0); Piper Faber (CC0) e Dii (CC BY-NC-SA 4.0, opcional) | Kokoro e Faber embutidos no app do celular (na Web, Kokoro baixado uma vez); Dii só ao tocar em “Baixar”; nada é enviado para fora |

Se você é titular de algum conteúdo e deseja ajustes ou remoção, abra uma *issue* ou escreva para a mantenedora — atenderemos prontamente.

**Idealização e desenvolvimento:** Júlia Lima.
**Revisão técnica:** Eduardo Lima Moraes ([DoodlesEpic](https://github.com/DoodlesEpic)) — revisões de código, desempenho, defeitos e infraestrutura nas versões 1.6.
**Agradecimentos:** CNBB, Vatican News, Wikimedia Commons e a todos os contribuidores.

## Contribuindo

Contribuições são muito bem-vindas — de código a correções de orações e traduções! Leia o [CONTRIBUTING.md](CONTRIBUTING.md), o [AGENTS.md](AGENTS.md) e o [Código de Conduta](CODE_OF_CONDUCT.md).

### Fluxo de branches

| Branch | Finalidade |
|---|---|
| `main` | **Produção / Deployment.** Cada push na `main` roda o CI e publica a versão de produção em `https://julia-flima.github.io/ViaSacra/`. |
| `dev` | **Desenvolvimento contínuo.** Roda o CI (`ci.yml`) e publica uma **prévia isolada** para testes em `https://julia-flima.github.io/ViaSacra/dev/` sem afetar a produção. |
| `data` | Gerenciada automaticamente pelo workflow `update-liturgy.yml` (JSONs diários da Liturgia). |
| `gh-pages` | Gerenciada automaticamente pelo workflow `deploy-web.yml` (site estático do GitHub Pages). |

## Licença

Copyright © 2026 Júlia Lima.

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da **GNU General Public License versão 3** publicada pela Free Software Foundation. Veja o arquivo [LICENSE](LICENSE).

Os textos litúrgicos, homilias e imagens pertencem aos seus respectivos titulares e **não** estão cobertos pela GPL.

<div align="center"><sub>Ad maiorem Dei gloriam ✝</sub></div>
