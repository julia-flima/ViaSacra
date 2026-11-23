import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app_state.dart';
import '../../../core/theme.dart';
import '../../../data/models/liturgy.dart';
import '../../../services/reading_audio_service.dart';
import '../../../widgets/common.dart';
import '../../../widgets/local_note_field.dart';
import 'psalm_video_player.dart';

/// Cartão de leitura (1ª Leitura, 2ª Leitura, Evangelho).
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.reading,
    required this.onListenFromHere,
    this.sourceUrl,
    this.onOpenInBible,
    this.noteRef,
  });

  final Reading reading;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;

  /// Chave da anotação pessoal desta leitura (ex.: "2026-11-22#evangelho"); sem ela, sem botão.
  final String? noteRef;

  /// Abre o capítulo completo na aba Bíblia.
  final VoidCallback? onOpenInBible;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gospel = reading.kind == ReadingKind.evangelho;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VsSpacing.lg, VsSpacing.lg, VsSpacing.md, VsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              label: reading.kind.label,
              reference: reading.reference,
              onListen: onListenFromHere,
              onShare: () => _share(reading),
              onOpenInBible: onOpenInBible,
              noteRef: noteRef,
            ),
            SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gospel && reading.acclamation != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      reading.acclamation!,
                      style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: t.bodySmall?.color),
                    ),
                  ],
                  if (reading.introduction != null) ...[
                    const SizedBox(height: 12),
                    Text(reading.introduction!, style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 12),
                  Text(reading.text, style: t.bodyLarge),
                  const SizedBox(height: 12),
                  Text(
                    gospel ? '— Palavra da Salvação.' : '— Palavra do Senhor.',
                    style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            SourceAttribution(source: reading.source, url: sourceUrl),
          ],
        ),
      ),
    );
  }
}

/// Texto compartilhado de uma leitura (inclui o refrão do Salmo, se houver).
String formatReadingForSharing(Reading r) {
  final refrain = r.refrain != null ? 'R. ${r.refrain}\n\n' : '';
  return '${r.kind.label}${r.reference != null ? ' — ${r.reference}' : ''}\n\n$refrain${r.text}\n\n'
      'Fonte: ${r.source} · via app Via Sacra (open source)';
}

void _share(Reading r) => unawaited(SharePlus.instance.share(ShareParams(text: formatReadingForSharing(r))));

/// Cartão do Salmo Responsorial com refrão em destaque e refrão cantado.
class PsalmCard extends StatefulWidget {
  const PsalmCard({
    super.key,
    required this.psalm,
    required this.onListenFromHere,
    this.audio = const LiturgyAudio(),
    this.sourceUrl,
    this.onOpenInBible,
    this.playerFactory,
    this.noteRef,
  });

  final Reading psalm;
  final LiturgyAudio audio;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;
  final VoidCallback? onOpenInBible;
  final AudioPlayer Function()? playerFactory;

  /// Ver [ReadingCard.noteRef].
  final String? noteRef;

  @override
  State<PsalmCard> createState() => _PsalmCardState();
}

class _PsalmCardState extends State<PsalmCard> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;
  ReadingAudioController? _mainAudio;
  String? _loadedUrl;
  bool _playing = false;
  bool _showVideo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ReadingAudioController? audio;
    try {
      audio = Provider.of<ReadingAudioController>(context, listen: false);
    } on ProviderNotFoundException {
      audio = null;
    }
    if (!identical(_mainAudio, audio)) {
      _mainAudio?.removeListener(_onMainAudioChanged);
      _mainAudio = audio;
      _mainAudio?.addListener(_onMainAudioChanged);
    }
  }

  void _onMainAudioChanged() {
    if ((_mainAudio?.playing ?? false) && _playing) {
      unawaited(_player?.pause());
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void didUpdateWidget(covariant PsalmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio.psalmVideoId != widget.audio.psalmVideoId) {
      _showVideo = false;
    }
    if (oldWidget.audio.psalmAudioUrl != widget.audio.psalmAudioUrl) {
      unawaited(_player?.stop());
      _loadedUrl = null;
      _playing = false;
    }
  }

  @override
  void dispose() {
    _mainAudio?.removeListener(_onMainAudioChanged);
    unawaited(_playerSub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _searchPsalmOnYoutube() async {
    final ref = widget.psalm.reference?.split(',').first.trim() ?? '';
    final refrainWords = (widget.psalm.refrain ?? '').split(RegExp(r'\s+')).take(6).join(' ');
    final query = ['Salmo Responsorial', ref, refrainWords].where((s) => s.isNotEmpty).join(' ');
    await openExternal(context, Uri.https('www.youtube.com', '/results', {'search_query': query}).toString());
  }

  Future<void> _toggleSung() async {
    final url = widget.audio.psalmAudioUrl;
    if (url == null) return;
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      if (_mainAudio?.playing == true) {
        await _mainAudio!.pause();
      }
      final player = _player ??= (widget.playerFactory?.call() ?? AudioPlayer());
      _playerSub ??= player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playing = false);
        }
      });
      if (_loadedUrl != url) {
        await player.setUrl(url);
        _loadedUrl = url;
      } else if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      if (mounted) setState(() => _playing = true);
      await player.play();
    } catch (_) {
      _loadedUrl = null;
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Áudio indisponível agora. Verifique sua conexão.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = widget.psalm;
    final credit = widget.audio.creditFor('salmo_audio_url');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VsSpacing.lg, VsSpacing.lg, VsSpacing.md, VsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              label: p.kind.label,
              reference: p.reference,
              onListen: widget.onListenFromHere,
              onShare: () => _share(p),
              onOpenInBible: widget.onOpenInBible,
              noteRef: widget.noteRef,
            ),
            if (p.refrain != null) ...[
              const SizedBox(height: 14),
              Semantics(
                label: 'Refrão: ${p.refrain}',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VsSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: cs.primary, width: 3)),
                  ),
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'R.  ',
                            style: t.titleMedium?.copyWith(color: cs.primary),
                          ),
                          TextSpan(
                            text: p.refrain,
                            style: t.titleLarge?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.audio.psalmAudioUrl != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _toggleSung,
                icon: Icon(_playing ? Icons.pause_rounded : Icons.music_note_outlined),
                label: Text(_playing ? 'Pausar refrão' : 'Ouvir Refrão Cantado'),
              ),
              if (credit != null)
                SourceAttribution(
                  source: [credit.performer, credit.channel].whereType<String>().join(' · '),
                  url: credit.sourceUrl,
                  license: credit.license,
                ),
            ] else if (widget.audio.psalmVideoId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  if (!_showVideo && _mainAudio?.playing == true) {
                    unawaited(_mainAudio!.pause());
                  }
                  setState(() => _showVideo = !_showVideo);
                },
                icon: Icon(_showVideo ? Icons.close_rounded : Icons.music_note_outlined),
                label: Text(_showVideo ? 'Fechar Salmo Cantado' : 'Ouvir Salmo Cantado'),
              ),
              if (_showVideo)
                PsalmVideoPlayer(
                  key: ValueKey(widget.audio.psalmVideoId),
                  videoId: widget.audio.psalmVideoId!,
                  title: widget.audio.psalmVideoTitle,
                  credit: widget.audio.creditFor('salmo_video_id'),
                ),
            ] else ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _searchPsalmOnYoutube,
                icon: const Icon(Icons.music_note_outlined),
                label: const Text('Buscar Salmo Cantado'),
              ),
            ],
            if (widget.audio.psalmChordsOrMelody != null) ...[
              const SizedBox(height: 8),
              Text(widget.audio.psalmChordsOrMelody!, style: t.bodySmall?.copyWith(fontFamily: 'Roboto')),
            ],
            const SizedBox(height: 12),
            SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, s) in (p.stanzas.isEmpty ? [p.text] : p.stanzas).indexed) ...[
                    Text(s, style: t.bodyLarge),
                    if (p.refrain != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 14),
                        child: Text('R.', style: t.labelLarge?.copyWith(color: cs.primary)),
                      )
                    else if (i < p.stanzas.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            SourceAttribution(source: p.source, url: widget.sourceUrl),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.label,
    this.reference,
    required this.onListen,
    this.onShare,
    this.onOpenInBible,
    this.noteRef,
  });

  final String label;
  final String? reference;
  final VoidCallback onListen;
  final VoidCallback? onShare;
  final VoidCallback? onOpenInBible;
  final String? noteRef;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(label),
                if (reference != null) ...[
                  const SizedBox(height: 4),
                  if (onOpenInBible == null)
                    Text(reference!, style: t.titleLarge)
                  else
                    Tooltip(
                      message: 'Ler o capítulo completo na Bíblia',
                      child: InkWell(
                        onTap: onOpenInBible,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                reference!,
                                style: t.titleLarge?.copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.menu_book_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        IconButton(tooltip: 'Ouvir a partir daqui', onPressed: onListen, icon: const Icon(Icons.headphones_outlined)),
        if (noteRef != null) _NoteButton(noteRef: noteRef!, title: reference == null ? label : '$label · $reference'),
        if (onShare != null)
          IconButton(tooltip: 'Compartilhar', onPressed: onShare, icon: const Icon(Icons.ios_share_outlined)),
      ],
    );
  }
}

/// Anotação pessoal da leitura (só no aparelho, entra no backup), aberta numa folha inferior para
/// não tirar espaço do texto. O ícone fica preenchido quando já há anotação.
class _NoteButton extends StatefulWidget {
  const _NoteButton({required this.noteRef, required this.title});

  final String noteRef;
  final String title;

  static const kind = 'liturgy';

  @override
  State<_NoteButton> createState() => _NoteButtonState();
}

class _NoteButtonState extends State<_NoteButton> {
  bool get _hasNote => context.read<AppServices>().userData.note(_NoteButton.kind, widget.noteRef) != null;

  Future<void> _open() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(VsSpacing.lg, 0, VsSpacing.lg, VsSpacing.lg + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: VsSpacing.md),
            LocalNoteField(
              kind: _NoteButton.kind,
              noteRef: widget.noteRef,
              label: 'Minha anotação (somente neste aparelho)',
              autofocus: true,
              // Grava também ao fechar a folha (depois da animação): atualiza o ícone em seguida.
              onSaved: () => Future.microtask(() {
                if (mounted) setState(() {});
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final has = _hasNote;
    return IconButton(
      tooltip: has ? 'Ver anotação' : 'Anotar',
      onPressed: _open,
      icon: const Icon(Icons.edit_note),
      color: has ? Theme.of(context).colorScheme.primary : null,
    );
  }
}
