# Arquitetura do Via Sacra

## Visão geral

```
┌──────────────────────── GitHub Actions (serverless, gratuito) ────────────────────────┐
│ update-liturgy.yml  00:05 BRT ─► scraper/scraper.py ─► branch `data`/liturgia/*.json │
│ build-release.yml   tag v*    ─► APK universal + APKs por ABI + .ipa sem assinatura   │
│ ci.yml              PR/push   ─► flutter analyze/test · pytest · auditoria F-Droid    │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                   │ jsDelivr CDN  (fallback: raw.githubusercontent.com)
                                   ▼
┌──────────────────────────────── App Flutter (Android + iOS) ───────────────────────────┐
│ features/  liturgy · rosary · catechism · prayers · settings        (UI, Provider)     │
│ services/  ReadingAudio (flutter_tts + just_audio + audio_service)                     │
│            Notification (flutter_local_notifications, 100% local) · Settings           │
│ data/      LiturgyRepository (offline-first) · CatechismRepository (FTS5)              │
│            ContentRepository (assets) · UserDataRepository (favoritos/constância)      │
│ core/      LiturgicalCalendar (cálculo local) · LiturgicalColor · AppTheme            │
│ SQLite (package:sqlite3, FTS5)  ·  assets/data/*.json  ·  assets/art/*.jpg             │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

## Princípios

1. **Offline-first.** Orações, mistérios, arte, índice do CIC e TTS estão empacotados. A liturgia
   baixada fica em `liturgy_cache`. Sem rede, o app mostra o calendário litúrgico calculado
   localmente (`core/liturgical_calendar.dart`), idêntico ao do scraper.
2. **Uma única fonte de rede.** O app só baixa JSON estático do próprio repositório. Nenhum
   cabeçalho identificador, cookie, analytics ou SDK de terceiros.
3. **Atribuição sempre visível.** Cada leitura, homilia e imagem mostra sua fonte e link.
4. **Falhas isoladas.** No scraper, uma fonte fora do ar não derruba as demais (`status` no JSON)
   e um arquivo bom nunca é sobrescrito por um pior (`qualidade()`).

## Fluxo da liturgia

`LiturgyController.load(data)` → `LiturgyRepository.load`:

1. cache SQLite (se tiver leituras e < 6 h) → retorna;
2. senão, CDN jsDelivr → GitHub raw → grava no cache;
3. falhou a rede → cache antigo, ou `DailyLiturgy.calendarOnly`.

"Baixar Semana Offline" busca hoje + 6 dias (o workflow pré-gera 7 dias diariamente).

## Áudio ("Ouvir Liturgia")

`buildLiturgyQueue` monta a fila: áudio narrado aberto (`liturgia_audio_url`), quando existir e o
usuário preferir, ou um segmento TTS por leitura. `ReadingAudioHandler` (audio_service):

- divide textos em frases (`splitForSpeech`) → pausa/retoma com precisão de frase;
- velocidade 0,75×–1,5× (flutter_tts usa 0,5 como "normal" em ambas as plataformas);
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
| `audio` | `salmo_audio_url`, `salmo_cifra_ou_melodia`, `liturgia_audio_url`, `creditos[]`, `fallback` |
| `homilias.vaticano` / `cnbb` | `titulo`, `autor`, `texto`, `url`, `fonte`, `licenca` |
| `homilias.patristica[]` | `autor`, `obra`, `texto`, `licenca: "Domínio público"` |
| `fontes[]`, `url_original`, `status` | Atribuição e diagnóstico |

Mudanças incompatíveis exigem `schema_version: 2` e suporte simultâneo no app por ao menos uma versão.
