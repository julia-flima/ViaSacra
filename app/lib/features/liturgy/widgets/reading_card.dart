import 'package:material_ui/material_ui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../data/models/liturgy.dart';
import '../../../widgets/common.dart';
import 'psalm_video_player.dart';

/// Cartão de leitura (1ª Leitura, 2ª Leitura, Evangelho).
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.reading,
    required this.onListenFromHere,
    this.sourceUrl,
    this.onOpenInBible,
  });

  final Reading reading;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;

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

  static void _share(Reading r) => SharePlus.instance.share(
    ShareParams(
      text:
          '${r.kind.label}${r.reference != null ? ' — ${r.reference}' : ''}\n\n${r.text}\n\n'
          'Fonte: ${r.source} · via app Via Sacra (open source)',
    ),
  );
}

/// Cartão do Salmo Responsorial com refrão em destaque e refrão cantado.
class PsalmCard extends StatefulWidget {
  const PsalmCard({
    super.key,
    required this.psalm,
    required this.onListenFromHere,
    this.audio = const LiturgyAudio(),
    this.sourceUrl,
    this.onOpenInBible,
  });

  final Reading psalm;
  final LiturgyAudio audio;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;
  final VoidCallback? onOpenInBible;

  @override
  State<PsalmCard> createState() => _PsalmCardState();
}

class _PsalmCardState extends State<PsalmCard> {
  AudioPlayer? _player;
  bool _playing = false;
  bool _showVideo = false;

  @override
  void didUpdateWidget(covariant PsalmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio.psalmVideoId != widget.audio.psalmVideoId) {
      _showVideo = false;
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _searchPsalmOnYoutube() async {
    final ref = widget.psalm.reference?.split(',').first.trim() ?? '';
    final refrainWords = (widget.psalm.refrain ?? '').split(RegExp(r'\s+')).take(6).join(' ');
    final query = ['Salmo Responsorial', ref, refrainWords].where((s) => s.isNotEmpty).join(' ');
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleSung() async {
    final url = widget.audio.psalmAudioUrl;
    if (url == null) return;
    if (_playing) {
      await _player?.pause();
      setState(() => _playing = false);
      return;
    }
    try {
      _player ??= AudioPlayer()
        ..playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed && mounted) setState(() => _playing = false);
        });
      await _player!.setUrl(url);
      setState(() => _playing = true);
      await _player!.play();
    } catch (_) {
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
              onOpenInBible: widget.onOpenInBible,
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
                onPressed: () => setState(() => _showVideo = !_showVideo),
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
  const _CardHeader({required this.label, this.reference, required this.onListen, this.onShare, this.onOpenInBible});

  final String label;
  final String? reference;
  final VoidCallback onListen;
  final VoidCallback? onShare;
  final VoidCallback? onOpenInBible;

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
        if (onShare != null)
          IconButton(tooltip: 'Compartilhar', onPressed: onShare, icon: const Icon(Icons.ios_share_outlined)),
      ],
    );
  }
}
