import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../services/reading_audio_service.dart';
import '../../../services/settings_service.dart';

/// Barra "Ouvir Liturgia": play/pause, leitura anterior/seguinte e velocidade.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key, required this.onPlayAll, required this.recorded, this.expectedKey});

  /// Inicia (ou retoma) a fila completa da liturgia.
  final VoidCallback onPlayAll;

  /// Há áudio narrado aberto disponível (senão, TTS local).
  final bool recorded;

  /// Chave base esperada (ex.: `liturgia-2026-11-19`) para não espelhar outra data ou módulo.
  final String? expectedKey;

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<ReadingAudioController>();
    final settings = context.read<SettingsService>();
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final active = expectedKey != null ? audio.isLoadedFor(expectedKey!) : (audio.hasQueue && audio.loadedKey != null);
    final playingThis = active && audio.playing;
    final neuralStatus = audio.neuralTtsStatus;
    final busy = neuralStatus.isBusy;
    final subtitle = busy
        ? (neuralStatus.label ?? 'Preparando voz neural…')
        : active && audio.currentTitle != null
        ? audio.currentTitle!
        : recorded
        ? 'Áudio narrado disponível'
        : 'Leitura em voz alta · funciona offline';

    return Material(
      color: cs.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Leitura anterior',
                  onPressed: active ? audio.previous : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filled(
                  tooltip: playingThis ? 'Pausar' : 'Ouvir Liturgia',
                  onPressed: active ? audio.toggle : onPlayAll,
                  icon: Icon(playingThis ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: 'Próxima leitura',
                  onPressed: active ? audio.next : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ouvir Liturgia', style: t.labelLarge),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Velocidade de leitura',
                  initialValue: audio.speed,
                  onSelected: (s) {
                    audio.setSpeed(s);
                    settings.ttsSpeed = s;
                  },
                  itemBuilder: (_) => [
                    for (final s in SettingsService.speeds)
                      PopupMenuItem(value: s, child: Text(SettingsService.speedLabel(s))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Text(
                      SettingsService.speedLabel(audio.speed),
                      style: t.labelLarge?.copyWith(color: cs.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (busy) LinearProgressIndicator(value: neuralStatus.progress, minHeight: 3),
        ],
      ),
    );
  }
}
