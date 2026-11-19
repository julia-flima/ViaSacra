import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../services/reading_audio_service.dart';
import '../../../services/settings_service.dart';

/// Barra "Ouvir Liturgia": play/pause, leitura anterior/seguinte e velocidade.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key, required this.onPlayAll, required this.recorded});

  /// Inicia (ou retoma) a fila completa da liturgia.
  final VoidCallback onPlayAll;

  /// Há áudio narrado aberto disponível (senão, TTS local).
  final bool recorded;

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<ReadingAudioController>();
    final settings = context.read<SettingsService>();
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final active = audio.hasQueue && audio.loadedKey != null;
    final subtitle = active && audio.currentTitle != null
        ? audio.currentTitle!
        : recorded
        ? 'Áudio narrado disponível'
        : 'Leitura em voz alta · funciona offline';

    return Material(
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Leitura anterior',
              onPressed: active ? audio.previous : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton.filled(
              tooltip: audio.playing ? 'Pausar' : 'Ouvir Liturgia',
              onPressed: active ? audio.toggle : onPlayAll,
              icon: Icon(audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
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
                for (final s in SettingsService.speeds) PopupMenuItem(value: s, child: Text('${_fmt(s)}×')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Text('${_fmt(audio.speed)}×', style: t.labelLarge?.copyWith(color: cs.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double s) => s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll('.', ',');
}
