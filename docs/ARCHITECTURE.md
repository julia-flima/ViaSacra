# Arquitetura do Via Sacra

## Visão geral

```
┌──────────────────────── GitHub Actions (serverless, gratuito) ────────────────────────┐
│ update-liturgy.yml  00:05 BRT ─► scraper/scraper.py ─► branch `data`/liturgia/*.json │
│ build-release.yml   tag v*    ─► APK universal + APKs por ABI + .ipa sem assinatura   │
│ deploy-web.yml      push main ─► Flutter Web (PWA) ─► branch gh-pages (GitHub Pages)   │
│ ci.yml              PR/push   ─► flutter analyze/test · pytest · auditoria F-Droid    │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                   │ jsDelivr CDN  (fallback: raw.githubusercontent.com)
                                   ▼
┌────────────────────────── App Flutter (Android + iOS + Web/PWA) ───────────────────────┐
│ features/  liturgy · bible · rosary · library(catechism+prayers) · settings  (Provider)│
│ services/  ReadingAudio (Kokoro-82M neural offline + just_audio + audio_service)     │
│            Notification (flutter_local_notifications, 100% local) · Settings           │
│ data/      LiturgyRepository (offline-first) · CatechismRepository (FTS5)              │
│            ContentRepository (assets) · UserDataRepository · BackupRepository         │
│            BibleRepository (módulos, FTS5, marcações) · BibleService (importação)      │
│ core/      LiturgicalCalendar (cálculo local) · LiturgicalColor · AppTheme            │
│ SQLite (package:sqlite3, FTS5): arquivo no celular · WASM + IndexedDB na Web          │
│ assets: data/*.json · art/*.jpg · bible/*.json · fonts/ (nada baixado de CDNs)         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

## Princípios

1. **Offline-first.** Orações, mistérios, arte, índice do CIC e TTS estão empacotados. A liturgia
   baixada fica em `liturgy_cache`. Sem rede, o app mostra o calendário litúrgico calculado
   localmente (`core/liturgical_calendar.dart`), idêntico ao do scraper.
2. **Rede só para conteúdo, nunca para rastrear.** Nenhum cookie, identificador, analytics ou
   SDK de terceiros. O app acessa a rede apenas para:
   - a liturgia diária (JSON e MP3 do branch `data`, via jsDelivr ou GitHub raw);
   - na Web, o modelo de voz Kokoro, baixado uma vez sob demanda (Hugging Face, com o
     `onnxruntime-web` do jsDelivr); no celular ele já vem no app;
   - as vozes Piper opcionais, só quando o usuário toca em "Baixar" (GitHub/sherpa-onnx);
   - páginas que o usuário abre: o texto oficial do CIC no `vatican.va` e o vídeo do Salmo no
     `youtube-nocookie.com`.
3. **Atribuição sempre visível.** Cada leitura, homilia e imagem mostra sua fonte e link.
4. **Falhas isoladas.** No scraper, uma fonte fora do ar não derruba as demais (`status` no JSON)
   e um arquivo bom nunca é sobrescrito por um pior (`qualidade()`).

## Fluxo da liturgia

`LiturgyController.load(data)` → `LiturgyRepository.load`:

1. cache SQLite completo (leituras + Salmo) → retorna se a data já passou, ou se foi baixado há
   menos de 30 min (hoje e dias futuros podem receber correções);
2. senão, CDN jsDelivr → GitHub raw → grava no cache;
3. falhou a rede → cache completo em silêncio (erro só numa atualização manual), cache
   incompleto com aviso, ou `DailyLiturgy.calendarOnly`.

A semana offline é automática (`LiturgyRepository.prefetchWeek`): pouco depois de abrir o app
e ao voltar a ele (no máximo a cada 6 h), baixa os dias de hoje + 6 que faltam no cache. O
workflow pré-gera 7 dias diariamente.

## Áudio ("Ouvir Liturgia")

`buildLiturgyQueue` monta a fila: áudio narrado aberto (`liturgia_audio_url` / `homilia_audio_url`,
gerados diariamente via `kokoro-onnx` com a voz `pf_dora`), quando existir e o usuário preferir, ou
um segmento TTS por leitura. `ReadingAudioHandler` (`audio_service`):

- divide textos em frases (`splitForSpeech`) → pausa/retoma com precisão de frase e pré-sintetiza o
  trecho seguinte (`lookahead` N+1);
- motor neural unificado **Kokoro-82M** (`pf_dora` e `pm_alex`, além de mapeamento automático para
  inglês, espanhol e italiano/latim):
  - **Mobile:** `sherpa_onnx: 1.13.8` em `Isolate` dedicado. O Kokoro int8 (~140 MB) vai dentro do
    APK/IPA (`tool/fetch_kokoro_model.py` → `assets/voice/kokoro/`) e é copiado uma vez para a pasta
    do app. Nas Configurações dá para baixar vozes **Piper** pt-BR (~21 MB) e ler o app inteiro com
    elas, ou usar a voz do sistema (`flutter_tts`), que também é a reserva se a neural falhar.
    O WAV gerado toca no mesmo `AudioPlayer` do áudio narrado;
  - **Web:** Web Worker (`kokoro_worker.js`) em `onnxruntime-web` (WebGPU/WASM) + `ephone`, modelo
    quantizado ~92 MB em Cache API e áudio via Web Audio API;
- avanço automático, anterior/próxima, controles na tela de bloqueio e fones Bluetooth;
- iOS: categoria `playback` + `UIBackgroundModes=audio`; Android: foreground service `mediaPlayback`.

O botão "Ouvir Refrão Cantado" usa um `AudioPlayer` separado com `salmo_audio_url`.

## Notificações

Lembretes são agendados no aparelho para os próximos 14 dias (cada dia com seu Evangelho e
mistérios) e reagendados ao abrir o app, mudar ajustes ou baixar a semana. Modo
`inexactAllowWhileIdle` — dispensa `SCHEDULE_EXACT_ALARM`. A permissão só é pedida quando o
usuário ativa os lembretes.

## Contrato do JSON diário (`schema_version: 1`)

Exemplo real: [`exemplo-liturgia-2026-11-19.json`](exemplo-liturgia-2026-11-19.json).

| Campo | Descrição |
|---|---|
| `calendario` | `tempo`, `semana`, `cor`, `celebracao`, `ciclo_dominical`, `ciclo_ferial`, `misterios_do_dia`, `cor_origem` |
| `leituras.primeira_leitura` / `segunda_leitura` / `evangelho` | `referencia`, `introducao`, `aclamacao`, `texto`, `fonte` |
| `leituras.salmo` | `referencia`, `refrao`, `estrofes[]`, `texto` |
| `audio` | `liturgia_audio_url` / `homilia_audio_url` (+ `*_audio_hash` do roteiro), `salmo_audio_url`, `salmo_cifra_ou_melodia`, `salmo_video_id` / `salmo_video_titulo`, `creditos[]`, `fallback` |
| `homilias.vaticano` / `cnbb` | `titulo`, `autor`, `texto`, `url`, `fonte`, `licenca` |
| `homilias.patristica[]` | `autor`, `obra`, `texto`, `licenca: "Domínio público"` |
| `fontes[]`, `url_original`, `status` | Atribuição e diagnóstico |

Mudanças incompatíveis exigem `schema_version: 2` e suporte simultâneo no app por ao menos uma versão.

## WebViews e embeds

Só dois pontos mostram conteúdo de terceiros, ambos com navegação restrita (`core/url_safety.dart`):

- **Leitor do CIC** (`VaticanReaderScreen`, Android/iOS): abre só `https://*.vatican.va`, com o
  CSS do app e rola até o § pedido; outros links vão para o navegador. Na Web/desktop, abre numa
  nova aba, já no parágrafo (o `vatican.va` não permite iframe).
- **Salmo cantado** (`PsalmVideoPlayer`): embed oficial `youtube-nocookie.com`, com o id do vídeo
  validado e domínios restritos ao YouTube.

## Backup

Ajustes → **Backup dos seus dados** exporta um `.json` (`viasacra-backup` v1) com favoritos,
anotações, constância e marcações da Bíblia (`data/backup_repository.dart`). A importação mescla:
nada é apagado, e em anotações e marcações vence a versão mais recente.

## Navegação (5 abas)

`NavigationController` (`lib/app_navigation.dart`) controla a aba ativa e permite que uma aba
abra outra. Por exemplo, tocar em "Lc 19,41-44" na Liturgia chama
`BibleService.requestOpen(BibleRef)` e muda para a aba Bíblia, que abre o capítulo com o trecho
proclamado destacado.

1. Liturgia & Homilias
2. Bíblia Sagrada (ver [`BIBLE.md`](BIBLE.md))
3. Santo Terço & Rosário
4. Biblioteca, com sub-abas Catecismo e Orações
5. Ajustes & Sobre

## Versão Web (PWA)

| Item | Implementação |
|---|---|
| Hospedagem | GitHub Pages, branch `gh-pages`: produção na raiz (`deploy-web.yml`, push na `main`) e prévia em `/dev/` (`deploy-dev-preview.yml`, push na `dev`). Cada deploy substitui só a sua parte, sem acumular arquivos antigos |
| Base | `--base-href "/<repositório>/"`, ou seja, `/ViaSacra/` (o GitHub Pages diferencia maiúsculas) |
| Instalação | `web/manifest.json` (`standalone`, `#FAF8F5`/`#B8860B`, ícones 192/512 e *maskable*) e meta tags iOS (`apple-mobile-web-app-capable`, `apple-touch-icon`) em `web/index.html` |
| Offline | `web/sw.js` próprio: o app usa *stale-while-revalidate* e a liturgia usa *network-first* com cache. O service worker legado do Flutter, que se autodesinstala, é desativado por um `web/flutter_bootstrap.js` customizado |
| Privacidade | `--no-web-resources-cdn` faz o CanvasKit ser servido localmente; todas as fontes são embutidas e o `fontFallbackBaseUrl` aponta para um caminho local. Nenhuma requisição ao Google |
| Banco | SQLite WASM + IndexedDB (ver `DATABASE.md`). A Bíblia é preparada na primeira visita |
| Áudio | Voz neural Kokoro-82M no Web Worker (`kokoro_worker.js`) via WebGPU/WASM + Web Audio API, com fallback para Web Speech API; MP3 via `<audio>` |
| Lembretes | Desativados com `kIsWeb`; a aba Ajustes mostra um aviso indicando o app nativo |
