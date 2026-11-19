<div align="center">

# ✝ Via Sacra

**Liturgia Diária, Homilias, Santo Terço, Catecismo e Orações — gratuito, sem anúncios, sem rastreadores, offline.**

[![Licença: GPL v3](https://img.shields.io/badge/Licen%C3%A7a-GPL--3.0-B8860B.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![F-Droid Ready](https://img.shields.io/badge/F--Droid-ready-1976D2?logo=f-droid&logoColor=white)](https://f-droid.org)
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
  - [Android](#android)
  - [iOS (iPhone / iPad)](#ios-iphone--ipad)
- [Instalação para desenvolvedores](#instalação-para-desenvolvedores)
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
2. **Santo Terço & Rosário** — mistérios do dia automáticos, Rosário completo (20 mistérios), arte sacra em domínio público, contador tátil com vibração e registro opcional de constância.
3. **Catecismo da Igreja Católica** — navegação pelas 4 partes, busca instantânea offline (SQLite FTS5) por número ou palavra, favoritos e anotações locais.
4. **Devocionário** — orações fundamentais, eucarísticas, marianas e de proteção, com alternância Português ⇄ Latim.
5. **Ajustes** — lembretes locais (Liturgia e Terço), voz e velocidade do narrador, tipografia, temas Pergaminho / Modo Igreja / Automático, e página "Sobre & Licenças".

## Instalação para usuários (sem programar)

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

## Arquitetura

```
ViaSacra/
├── app/                    # Aplicativo Flutter (Android + iOS)
│   ├── lib/
│   │   ├── core/           # tema, cores litúrgicas, calendário, constantes
│   │   ├── data/           # modelos, SQLite (FTS5), repositórios
│   │   ├── services/       # TTS/áudio, notificações locais, preferências
│   │   └── features/       # liturgia, terço, catecismo, orações, ajustes
│   └── assets/data/        # orações, mistérios, arte sacra, schema SQL
├── scraper/                # Coletor Python (requests + BeautifulSoup4)
├── data/                   # JSONs gerados (branch `data`, servidos via jsDelivr)
├── fastlane/metadata/      # Metadados do F-Droid
├── docs/                   # Arquitetura, banco de dados, arte sacra, design system
└── .github/workflows/      # update-liturgy.yml · build-release.yml · ci.yml
```

Fluxo de dados:

```
GitHub Actions (00:05 BRT) ─► scraper.py ─► data/liturgia/AAAA-MM-DD.json ─► branch `data`
                                                                           │
             App (offline-first) ◄── jsDelivr CDN / GitHub Pages ◄─────────┘
                    │
                    └─► SQLite local (cache litúrgico, CIC FTS5, favoritos, constância)
```

Documentação detalhada: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · [`docs/DATABASE.md`](docs/DATABASE.md) · [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) · [`docs/SACRED_ART.md`](docs/SACRED_ART.md) · [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md)

## Fontes, direitos autorais e créditos

O Via Sacra **não tem fins lucrativos** e atribui todas as fontes explicitamente na interface, com link para o original.

| Conteúdo | Fonte | Uso |
|---|---|---|
| Leituras da Liturgia Diária | [CNBB — liturgiadiaria.cnbb.org.br](https://liturgiadiaria.cnbb.org.br) | Devocional, não comercial, com atribuição "Fonte: CNBB" |
| Homilias e reflexões do Papa | [Vatican News (Português)](https://www.vaticannews.va/pt.html) / © Libreria Editrice Vaticana / Dicastério para a Comunicação | Uso pastoral não comercial com citação e link |
| Comentários patrísticos | Santo Agostinho, São João Crisóstomo, *Catena Aurea* (São Tomás de Aquino) | Domínio público |
| Arte sacra | Wikimedia Commons, The Met Open Access, National Gallery of Art (CC0) | Domínio público — ver [`docs/SACRED_ART.md`](docs/SACRED_ART.md) |
| Catecismo da Igreja Católica | © Libreria Editrice Vaticana | **Não incluído** no repositório; importável mediante licença — ver [`docs/COPYRIGHT.md`](docs/COPYRIGHT.md) |

Se você é titular de algum conteúdo e deseja ajustes ou remoção, abra uma *issue* ou escreva para a mantenedora — atenderemos prontamente.

**Idealização e desenvolvimento:** Júlia Lima.
**Agradecimentos:** CNBB, Vatican News, Wikimedia Commons e a todos os contribuidores.

## Contribuindo

Contribuições são muito bem-vindas — de código a correções de orações e traduções! Leia o [CONTRIBUTING.md](CONTRIBUTING.md) e o [Código de Conduta](CODE_OF_CONDUCT.md).

## Licença

Copyright © 2026 Júlia Lima.

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da **GNU General Public License versão 3** publicada pela Free Software Foundation. Veja o arquivo [LICENSE](LICENSE).

Os textos litúrgicos, homilias e imagens pertencem aos seus respectivos titulares e **não** estão cobertos pela GPL.

<div align="center"><sub>Ad maiorem Dei gloriam ✝</sub></div>
