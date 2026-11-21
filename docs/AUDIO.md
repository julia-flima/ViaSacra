# Leitura em voz alta

Como o Via Sacra fala, por que é assim e para onde vamos.

## Princípios

- **A melhor voz em português do Brasil, sem custo para o aparelho.** Sempre que possível, o áudio já vem pronto (MP3 gerado no CI). Sintetizar no aparelho é a segunda opção.
- **Offline-first.** Sem internet, o app ainda lê tudo com uma voz embutida.
- **Privacidade e FOSS.** O app nunca envia texto nem dados para serviços de voz. Só baixa arquivos públicos (MP3 e modelos) de endereços abertos (jsDelivr/GitHub).

## O que existe hoje (v1.6)

| Fonte | Onde | Quando é usada |
|---|---|---|
| MP3 pré-gerado (Kokoro **Dora** e **Alex**) | branch `data`, via jsDelivr | Liturgia e homilia do dia, sempre que a voz escolhida for Dora ou Alex (no modo Automático ou Kokoro) |
| Kokoro-82M no aparelho | embutido no APK/IPA; na Web, baixado uma vez | Qualquer texto, se o aparelho acompanhar a fala |
| Piper Faber no aparelho (CC0) | embutido no APK | Reserva do modo Automático em celulares lentos |
| Piper Dii (CC BY-NC-SA) | baixado a pedido nas Configurações | Só se a pessoa escolher |
| Voz do sistema | Android/iOS/navegador | Reserva final (e escolha explícita) |

## Decisões

- **MP3 por voz, com marcas.** `generate_audio.py` grava um MP3 da Liturgia e da Homilia para cada voz Kokoro (`liturgia_vozes`/`homilia_vozes`), com o segundo em que começa cada leitura. O app recorta o MP3 por leitura, então avançar, voltar e "Ouvir a partir daqui" funcionam sem síntese.
- **A voz escolhida é a voz ouvida.** O app toca o MP3 só quando ele é da voz escolhida. Trocar a voz durante a leitura reinicia o trecho atual na voz nova. MP3 antigos de outra voz (ex.: Piper Cadu, de versões anteriores do gerador) são ignorados: o app só aceita os campos antigos se o crédito for Kokoro.
- **Modo Automático (padrão).** O app mede no uso quanto tempo o Kokoro leva para sintetizar cada segundo de fala (RTF) e guarda a média.
  - Celular: Kokoro se ele acompanha a fala (RTF ≤ 1,1); senão o Piper Faber embutido; senão a voz do sistema.
  - Web: Kokoro se acompanha. Sem medição ainda, usa a voz do sistema quando não há WebGPU e o modelo não foi baixado, porque o WASM numa só thread fica ~2× mais lento que a fala e não vale baixar 92 MB.
  - Os MP3 prontos continuam valendo no Automático: são Kokoro, sem custo para o aparelho.
- **Um modelo por vez, num só Isolate.** Trocar de voz só troca o modelo e libera o anterior com `free()`. Detalhes no `native_tts_io.dart`.
- **Dii fora do app.** A licença dela é não comercial. Por isso ela só é baixada a pedido e não é usada pelo Automático.

Medições (emulador x86_64, 4 núcleos): Kokoro a ~1,04× o tempo real e Piper a ~0,2×. No navegador sem WebGPU, Kokoro a ~2×.

## Plano: uma "API" de áudio estática

O objetivo é que quase todo áudio chegue pronto, com qualidade de estúdio, sem servidor próprio, sem rastreio e sem custo de manutenção.

**Ideia central: áudio endereçado pelo conteúdo.** O nome de cada arquivo é o hash de `voz + texto normalizado`. O CI gera os arquivos e um índice (`audio/indice.json`: hash → arquivo, duração, marcas). Antes de sintetizar um trecho, o app calcula o hash. Se ele estiver no índice, toca o arquivo (e o guarda em cache). Se não estiver, sintetiza no aparelho como hoje. É uma "API" só de leitura, servida por CDN, sem nenhuma requisição com dados da pessoa.

Etapas:

1. **Textos fixos** (orações, Terço, Via Sacra, Imitação de Cristo, Catecismo de São Pio X): gerados uma vez por voz e refeitos só quando o texto muda. São algumas horas de áudio, dezenas de MB em Opus 32 kbps: cabem no jsDelivr/GitHub.
2. **Normalização única.** Uma só função de normalização, com casos de teste compartilhados entre Python e Dart, para o hash bater dos dois lados. Inclui a expansão de "Lc 19,41-44", ordinais e abreviações, que ainda falta (ver pendências no AGENTS.md).
3. **Bíblia completa** (~80 h por voz): grande demais para o git. Publicar como anexos de Releases do GitHub ou no Internet Archive (adequado a obras em domínio público), um arquivo por capítulo, no mesmo índice por hash.
4. **Voz melhor no CI.** Como a geração roda no CI, dá para usar modelos maiores e mais naturais que não caberiam no celular. Exigência: licença livre também para o áudio gerado (Apache/MIT/CC0/CC BY). Ficam de fora modelos com licença não comercial (ex.: XTTS-v2/CPML) e serviços pagos com termos restritivos. Avaliar candidatos em pt-BR (Kokoro maior, F5-TTS e outros) com uma audição às cegas.
5. **Serviços de terceiros** (Azure, Google, ElevenLabs): nunca chamados pelo app (violaria a privacidade e o F-Droid). No máximo, usados no CI se a licença permitir redistribuir o áudio. Hoje nenhum permite de forma clara, então ficam descartados.

Critério de sucesso: no uso comum (Liturgia, orações, Terço), o aparelho não sintetiza nada; a síntese local fica só para texto importado ou novo.
