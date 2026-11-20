import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/reading_audio_service.dart';
import '../services/settings_service.dart';

/// Mini-player global de áudio acessível em todas as telas e rotas de leitura.
/// Exibe progresso de download/síntese do Kokoro-82M e controles de reprodução.
class GlobalAudioMiniPlayer extends StatelessWidget {
  const GlobalAudioMiniPlayer({super.key, this.useSafeArea = false});

  /// Aplica respiro inferior quando renderizado como rodapé de rota isolada
  /// ou ao lado do `NavigationRail`. No `NavigationBar`, já fica acima da barra.
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    ReadingAudioController? audio;
    try {
      audio = context.watch<ReadingAudioController>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    SettingsService? settings;
    try {
      settings = context.read<SettingsService>();
    } on ProviderNotFoundException {
      settings = null;
    }

    final hasAudio = audio.hasQueue && audio.loadedKey != null;
    final status = audio.neuralTtsStatus;
    if (!hasAudio && !status.isBusy) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final multiTrack = audio.titles.length > 1;

    final Widget? progressBar = status.isBusy
        ? LinearProgressIndicator(value: status.progress, minHeight: 3)
        : audio.isSynthesizing
        ? const LinearProgressIndicator(minHeight: 2.5)
        : hasAudio && audio.chunkCount > 1
        ? LinearProgressIndicator(value: audio.chunkProgress, minHeight: 2.5)
        : null;

    final subtitle = status.isBusy
        ? (status.label ?? 'Preparando voz neural…')
        : audio.isSynthesizing
        ? 'Sintetizando voz neural…'
        : (audio.currentSubtitle ?? (audio.playing ? 'Reproduzindo…' : 'Pausado'));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?progressBar,
        if (!hasAudio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.downloading_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.label ?? 'Preparando voz neural Kokoro…',
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audio.currentTitle ?? 'Leitura em voz alta',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelLarge,
                      ),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                    ],
                  ),
                ),
                if (multiTrack)
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: audio.previous,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.skip_previous_rounded, size: 20),
                  ),
                IconButton.filledTonal(
                  tooltip: audio.playing ? 'Pausar' : 'Retomar',
                  onPressed: audio.toggle,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  icon: Icon(audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
                ),
                if (multiTrack)
                  IconButton(
                    tooltip: 'Próximo',
                    onPressed: audio.next,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                  ),
                PopupMenuButton<double>(
                  tooltip: 'Velocidade de leitura',
                  initialValue: audio.speed,
                  onSelected: (s) {
                    audio!.setSpeed(s);
                    settings?.ttsSpeed = s;
                  },
                  itemBuilder: (_) => [
                    for (final s in SettingsService.speeds) PopupMenuItem(value: s, child: Text('${_fmt(s)}×')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Text(
                      '${_fmt(audio.speed)}×',
                      style: t.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Parar e fechar',
                  onPressed: audio.dismiss,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
      ],
    );

    return Material(
      color: cs.surfaceContainerHigh,
      shape: Border(top: BorderSide(color: cs.outlineVariant)),
      child: useSafeArea ? SafeArea(top: false, child: content) : content,
    );
  }

  static String _fmt(double s) => s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll('.', ',');
}
