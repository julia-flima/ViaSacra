import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/reading_audio_service.dart';
import '../services/settings_service.dart';

/// Conta as páginas empilhadas no Navigator principal (diálogos e menus não contam).
/// Com mais de uma página, o mini-player passa a ser exibido pelo `MaterialApp.builder`
/// em vez de pela `HomeShell`, ficando visível também nas telas de leitura empurradas.
class PageDepthObserver extends NavigatorObserver {
  final ValueNotifier<int> depth = ValueNotifier(0);
  int _count = 0;

  void _update(Route<dynamic>? route, int delta) {
    if (route is! PageRoute) return;
    _count += delta;
    // O Navigator notifica durante o build; adia a atualização para depois do quadro.
    SchedulerBinding.instance.addPostFrameCallback((_) => depth.value = _count);
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(oldRoute, -1);
    _update(newRoute, 1);
  }
}

/// Mini-player global: título atual, progresso do motor neural, anterior/próximo,
/// play/pause, velocidade e fechar. Visível sempre que há uma fila de leitura
/// carregada (Bíblia, Catecismo, Imitação, Via Sacra, Liturgia…) ou enquanto a
/// voz neural Kokoro está sendo baixada/preparada.
///
/// Não usa `Tooltip`/menus suspensos porque também é desenhado fora do Navigator
/// (sem `Overlay`); cada botão leva rótulo de acessibilidade próprio.
class GlobalAudioMiniPlayer extends StatelessWidget {
  const GlobalAudioMiniPlayer({super.key, this.hiddenForKeyPrefix});

  /// Oculta o mini-player quando a fila carregada começa com este prefixo
  /// (ex.: `liturgia-` na aba Liturgia, que já possui a própria barra de áudio).
  final String? hiddenForKeyPrefix;

  static String _fmt(double s) => s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<ReadingAudioController>();
    final status = audio.neuralTtsStatus;
    final busy = status.isBusy;
    final hidden = hiddenForKeyPrefix != null && (audio.loadedKey?.startsWith(hiddenForKeyPrefix!) ?? false);
    if (hidden || (!audio.hasQueue && !busy)) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final title = audio.currentTitle ?? 'Preparando voz neural';
    final subtitle = busy
        ? (status.label ?? 'Preparando voz neural Kokoro…')
        : audio.titles.length > 1
        ? '${audio.index + 1} de ${audio.titles.length}'
        : (audio.playing ? 'Lendo em voz alta' : 'Pausado');

    Widget button(String label, IconData icon, VoidCallback? onPressed, {bool filled = false}) => Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: filled
          ? IconButton.filled(onPressed: onPressed, icon: Icon(icon))
          : IconButton(onPressed: onPressed, icon: Icon(icon)),
    );

    void cycleSpeed() {
      const speeds = SettingsService.speeds;
      final i = speeds.indexOf(audio.speed);
      final next = speeds[(i + 1) % speeds.length];
      audio.setSpeed(next);
      context.read<SettingsService>().ttsSpeed = next;
    }

    return Material(
      key: const ValueKey('global-audio-mini-player'),
      color: cs.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            LinearProgressIndicator(value: status.progress, minHeight: 2)
          else
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VsSpacing.xs, vertical: 2),
            child: Row(
              children: [
                if (audio.hasQueue && audio.titles.length > 1)
                  button('Leitura anterior', Icons.skip_previous_rounded, audio.previous),
                if (audio.hasQueue)
                  button(
                    audio.playing ? 'Pausar' : 'Continuar leitura',
                    audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    audio.toggle,
                    filled: true,
                  ),
                if (audio.hasQueue && audio.titles.length > 1)
                  button('Próxima leitura', Icons.skip_next_rounded, audio.next),
                const SizedBox(width: VsSpacing.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(subtitle, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                if (audio.hasQueue) ...[
                  Semantics(
                    label: 'Velocidade ${_fmt(audio.speed)} vezes. Toque para alterar',
                    button: true,
                    excludeSemantics: true,
                    child: TextButton(
                      onPressed: cycleSpeed,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text('${_fmt(audio.speed)}×'),
                    ),
                  ),
                  button('Parar e fechar o player', Icons.close_rounded, audio.close),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Envolve as rotas empurradas (`Navigator.push`) com o mini-player no rodapé.
/// Na página inicial (`HomeShell`) o mini-player fica acima da barra de navegação.
class GlobalAudioMiniPlayerHost extends StatelessWidget {
  const GlobalAudioMiniPlayerHost({super.key, required this.depth, required this.child});

  final ValueListenable<int> depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: depth,
      child: child,
      builder: (context, d, child) {
        final show =
            d > 1 && context.select<ReadingAudioController, bool>((a) => a.hasQueue || a.neuralTtsStatus.isBusy);
        // Estrutura fixa (Column → Expanded → MediaQuery) para não remontar o Navigator.
        return Column(
          children: [
            Expanded(
              child: MediaQuery.removePadding(context: context, removeBottom: show, child: child!),
            ),
            if (show) const SafeArea(top: false, child: GlobalAudioMiniPlayer()),
          ],
        );
      },
    );
  }
}
