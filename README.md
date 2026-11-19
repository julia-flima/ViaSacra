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
- [Traduções da Bíblia Sagrada e Importador JSON](#traduções-da-bíblia-sagrada-e-importador-json)
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

1. **Liturgia & Homilias** — leituras do dia (1ª Leitura, Salmo com refrão em destaque, 2ª Leitura, Evangelho), cabeçalho com Tempo e Cor Litúrgica, player "Ouvir Liturgia" (TTS offline ou áudio aberto), homilia do Vaticano e reflexões CNBB / Santos Padres, modo Lectio Divina em tela cheia, calendário e "Baixar Semana Offline".
2. **Bíblia Sagrada (73 livros, cânon católico)** — Antigo Testamento com os deuterocanônicos e Novo Testamento; seletor Livro › Capítulo, "Continuar lendo", busca offline por referência ("Jo 3,16") ou palavra (FTS5), leitura comparada versículo a versículo, marcações em cores suaves, favoritos e anotações locais, compartilhamento formatado e áudio do capítulo (TTS). Traduções modulares: Vulgata Clementina e Douay-Rheims embutidas (domínio público) e importação local de módulos — ver [`docs/BIBLE.md`](docs/BIBLE.md). Na Liturgia, tocar na referência de uma leitura abre o capítulo completo.
3. **Santo Terço & Rosário** — mistérios do dia automáticos, Rosário completo (20 mistérios), arte sacra em domínio público, contador tátil com vibração e registro opcional de constância.
4. **Biblioteca** — duas sub-abas: **Catecismo da Igreja Católica** — navegação pelas 4 partes, busca instantânea offline (SQLite FTS5) por número ou palavra, favoritos e anotações locais; e **Devocionário**, com orações fundamentais, eucarísticas, marianas e de proteção, com alternância Português ⇄ Latim.
5. **Ajustes** — lembretes locais (Liturgia e Terço), voz e velocidade do narrador, tipografia, temas Pergaminho / Modo Igreja / Automático, e página "Sobre & Licenças".

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

> A versão web tem Liturgia, Bíblia, Terço, Catecismo, Orações e leitura em voz alta. Os **lembretes
> agendados** (notificações) ficam disponíveis apenas no app nativo para Android e iOS, abaixo.

### Android

**Opção 1 — Download direto (mais simples)**

1. No celular, abra a página **[Releases](https://github.com/julia-flima/ViaSacra/releases/latest)**.
2. Em **Assets**, toque em **`ViaSacra-universal.apk`** (funciona em qualquer aparelho).
   - Quer um arquivo menor? Baixe o específico do seu aparelho: `ViaSacra-arm64-v8a.apk` (a maioria dos celulares atuais), `ViaSacra-armeabi-v7a.apk` (aparelhos antigos) ou `ViaSacra-x86_64.apk` (emuladores/Chromebooks).
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
- Android: Android Studio ou SDK de linha de comando, JDK 17
- iOS: macOS com Xcode 15+ e CocoaPods
- Python **3.11+** (somente para o scraper)

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

Compilando instaladores localmente:

```bash
flutter build apk --release --split-per-abi   # APKs por ABI
```

```bash
flutter build apk --release                   # APK universal
```

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

## Traduções da Bíblia Sagrada e Importador JSON

O módulo da Bíblia Sagrada (cânon católico de **73 livros**: 46 AT com deuterocanônicos + 27 NT) oferece suporte nativo a duas traduções clássicas em **Domínio Público** (100% compatíveis com o F-Droid) — **Pe. Antônio Pereira de Figueiredo** (Português) e **Vulgata Clementina** (Latim) — e um **importador modular local (`.json`)** acessível pela aba **Bíblia** e pelos **Ajustes → Gerenciar e Importar Traduções**.

### Consolidando traduções com `scripts/build_bible_db.py`

O script [`scripts/build_bible_db.py`](scripts/build_bible_db.py) padroniza arquivos `.json` ou `.txt` de Figueiredo e da Vulgata (mapeando os 73 livros pelo cânon em [`tool/bible/canon.py`](tool/bible/canon.py)) e gera os módulos JSON padronizados e o banco SQLite otimizado com índice FTS5:

```bash
# Gera o banco SQLite/FTS5 consolidando Figueiredo e Vulgata (Domínio Público):
python3 scripts/build_bible_db.py \
  --figueiredo fontes/figueiredo.json \
  --vulgata app/assets/bible/vulgata.json \
  --db-out app/assets/db/bible.db \
  --write-json \
  --update-bundled
```

### Esquema JSON padrão aceito pelo Importador

Qualquer arquivo `.json` no formato abaixo pode ser importado diretamente no aparelho via **Gerenciar e Importar Traduções** (usando `file_picker` — compatível com Android, iOS, Web e F-Droid):

```json
{
  "formato": "viasacra-biblia",
  "versao": 1,
  "id": "cnbb",
  "nome": "Bíblia Sagrada — Tradução Oficial da CNBB",
  "sigla": "CNBB",
  "idioma": "pt-BR",
  "licenca": "Uso pessoal (importação local)",
  "fonte": "Edições CNBB",
  "descricao": "Tradução oficial da Conferência Nacional dos Bispos do Brasil.",
  "numeracao_salmos": "grega",
  "versao_modulo": 1,
  "livros": [
    {
      "id": "gn",
      "capitulos": [
        [
          "No princípio, Deus criou o céu e a terra.",
          "A terra estava deserta e vazia..."
        ],
        {
          "1": "Assim foram concluídos o céu e a terra...",
          "2": "No sétimo dia, Deus concluiu toda a obra..."
        }
      ]
    },
    {
      "id": "jo",
      "capitulos": {
        "3": {
          "16": "Com efeito, de tal modo Deus amou o mundo, que lhe deu seu Filho único..."
        }
      }
    }
  ]
}
```

| Campo | Obrigatório | Descrição |
|---|---|---|
| `formato` | Recomendado | Deve ser `"viasacra-biblia"` (quando informado). |
| `versao` | Recomendado | Versão do esquema (`1`). |
| `id` | **Sim** | Identificador único (`2` a `32` caracteres: `[a-z0-9_-]`). Reimportar o mesmo `id` atualiza a tradução. |
| `nome` | **Sim** | Nome completo exibido no seletor e nas atribuições. |
| `sigla` (ou `abreviacao`) | **Sim** | Sigla curta exibida na barra superior (ex.: `FIG`, `MS`, `VUL`, `CNBB`, `AM`, `BJ`). |
| `idioma` | **Sim** | Código BCP-47 (ex.: `pt-BR`, `pt-PT`, `la`, `en`). Define a voz do TTS. |
| `licenca` | Não | Nota de licença/origem (padrão: `"Importada localmente pelo usuário"`). |
| `numeracao_salmos` | Não | `"grega"` (padrão — Vulgata/lecionários) ou `"hebraica"`. |
| `livros` | **Sim** | Lista de livros com `id` pertencente aos 73 livros do cânon católico ([`app/assets/bible/canon.json`](app/assets/bible/canon.json)). |
| `livros[].capitulos` | **Sim** | Lista de capítulos (cada capítulo como lista de versículos `["v1", "v2"]`, pares `[[1, "v1"], [3, "v3"]]` ou objeto `{"1": "v1"}`), ou objeto numerado por capítulo (`{"1": {"1": "v1"}}`). |

Detalhes completos sobre o cânon de 73 livros e armazenamento SQLite/FTS5 estão em [`docs/BIBLE.md`](docs/BIBLE.md).

## Módulo Catecismo (100% FOSS + Portal Oficial e Importador JSON)

Na sub-aba **Biblioteca → Catecismo**, o Via Sacra oferece:

- **Estudo Offline (100% Domínio Público / F-Droid):** **Catecismo Maior de São Pio X (1905)** (perguntas e respostas) e **Catecismo Romano (Concílio de Trento, 1566)** (mesma divisão em 4 partes do CIC de 1992), ambos indexados localmente com SQLite FTS5, busca por número ou palavra-chave, favoritos, anotações pessoais e leitura em voz alta (TTS offline).
- **CIC (1992) — Portal Oficial:** índice estruturado das 4 Partes com atalho direto para o portal oficial em português no site da Santa Sé (`vatican.va`), sem hospedar texto protegido no repositório.
- **Importador Modular Local (`.json`):** permite importar no próprio aparelho um arquivo `.json` do CIC (1992) ou do Compêndio do Catecismo, habilitando busca offline por número (`§1324`) e leitura em voz alta (TTS).

### Esquema JSON padrão para importação de Catecismos

```json
{
  "formato": "viasacra-catecismo",
  "versao": 1,
  "id": "cic_1992",
  "nome": "Catecismo da Igreja Católica",
  "nome_curto": "CIC (1992)",
  "sigla": "CIC",
  "ano": 1992,
  "idioma": "pt-BR",
  "licenca": "Uso pessoal (importação local)",
  "rotulo_entrada": "§",
  "entradas": [
    {
      "numero": 1324,
      "parte": "Segunda Parte — A Celebração do Mistério Cristão",
      "capitulo": "O Sacramento da Eucaristia",
      "pergunta": "A Eucaristia — fonte e ápice da vida eclesial",
      "resposta": "A Eucaristia é fonte e ápice de toda a vida cristã..."
    }
  ]
}
```

| Campo | Obrigatório | Descrição |
|---|---|---|
| `formato` | Recomendado | Deve ser `"viasacra-catecismo"` (quando informado). |
| `versao` | Recomendado | Versão do esquema (`1`). |
| `id` | **Sim** | Identificador único (`2` a `32` caracteres: `[a-z0-9_-]`). |
| `nome` | **Sim** | Nome completo da obra. |
| `nome_curto` / `sigla` | Não | Rótulo curto exibido no seletor de obras. |
| `idioma` | Não | Código BCP-47 (padrão: `"pt-BR"`). Define a voz do TTS. |
| `rotulo_entrada` | Não | Prefixo do número (ex.: `"§"` ou `"P."`). |
| `entradas` (ou `paragrafos`) | **Sim** | Lista de objetos com `numero` (inteiro positivo), `parte`, `capitulo` (opcional), `pergunta` / `titulo` (opcional) e `resposta` / `texto` (obrigatório). |

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
├── docs/                   # Arquitetura, banco de dados, arte sacra, design system
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

Documentação detalhada: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/DATABASE.md`](docs/DATABASE.md) · [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) · [`docs/BIBLE.md`](docs/BIBLE.md) · [`docs/SACRED_ART.md`](docs/SACRED_ART.md) · [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md)

## Fontes, direitos autorais e créditos

O Via Sacra **não tem fins lucrativos** e atribui todas as fontes explicitamente na interface, com link para o original.

| Conteúdo | Fonte | Uso |
|---|---|---|
| Leituras da Liturgia Diária | [CNBB — liturgiadiaria.edicoescnbb.com.br](https://liturgiadiaria.edicoescnbb.com.br) | Devocional, não comercial, com atribuição "Fonte: CNBB / Edições CNBB" |
| Homilias e reflexões do Papa | [Vatican News (Português)](https://www.vaticannews.va/pt.html) / © Libreria Editrice Vaticana / Dicastério para a Comunicação | Uso pastoral não comercial com citação e link |
| Comentários patrísticos | Santo Agostinho, São João Crisóstomo, *Catena Aurea* (São Tomás de Aquino) | Domínio público |
| Arte sacra | Wikimedia Commons, The Met Open Access, National Gallery of Art (CC0) | Domínio público — ver [`docs/SACRED_ART.md`](docs/SACRED_ART.md) |
| Bíblia — Vulgata Clementina e Douay-Rheims | Clementine Vulgate Project / revisão Challoner, via [mborders/vulgata](https://github.com/mborders/vulgata) | Domínio público (embutidas) |
| Bíblia — CNBB, Ave-Maria, Jerusalém, Pastoral | © respectivas editoras | **Não incluídas**; apenas importação local de módulos autorizados — ver [`docs/BIBLE.md`](docs/BIBLE.md) e [`docs/autorizacoes/`](docs/autorizacoes/) |
| Fontes tipográficas | Merriweather (SIL OFL), Roboto (Apache-2.0), DejaVu (livre) | Embutidas — nenhuma fonte é baixada da internet |
| Catecismo da Igreja Católica | © Libreria Editrice Vaticana | **Não incluído** no repositório; importável mediante licença — ver [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md) |

Se você é titular de algum conteúdo e deseja ajustes ou remoção, abra uma *issue* ou escreva para a mantenedora — atenderemos prontamente.

**Idealização e desenvolvimento:** Júlia Lima.
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
