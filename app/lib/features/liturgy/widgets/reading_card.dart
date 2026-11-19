import 'package:material_ui/material_ui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../data/models/liturgy.dart';
import '../../../widgets/common.dart';

/// Cartão de leitura (1ª Leitura, 2ª Leitura, Evangelho).
class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key, required this.reading, required this.onListenFromHere, this.sourceUrl});

  final Reading reading;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;

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
            ),
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
            SelectableText(reading.text, style: t.bodyLarge),
            const SizedBox(height: 12),
            Text(
              gospel ? '— Palavra da Salvação.' : '— Palavra do Senhor.',
              style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
  });

  final Reading psalm;
  final LiturgyAudio audio;
  final VoidCallback onListenFromHere;
  final String? sourceUrl;

  @override
  State<PsalmCard> createState() => _PsalmCardState();
}

class _PsalmCardState extends State<PsalmCard> {
  AudioPlayer? _player;
  bool _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
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
            _CardHeader(label: p.kind.label, reference: p.reference, onListen: widget.onListenFromHere),
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
            ],
            if (widget.audio.psalmChordsOrMelody != null) ...[
              const SizedBox(height: 8),
              Text(widget.audio.psalmChordsOrMelody!, style: t.bodySmall?.copyWith(fontFamily: 'monospace')),
            ],
            const SizedBox(height: 12),
            for (final (i, s) in (p.stanzas.isEmpty ? [p.text] : p.stanzas).indexed) ...[
              SelectableText(s, style: t.bodyLarge),
              if (p.refrain != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 14),
                  child: Text('R.', style: t.labelLarge?.copyWith(color: cs.primary)),
                )
              else if (i < p.stanzas.length - 1)
                const SizedBox(height: 14),
            ],
            SourceAttribution(source: p.source, url: widget.sourceUrl),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.label, this.reference, required this.onListen, this.onShare});

  final String label;
  final String? reference;
  final VoidCallback onListen;
  final VoidCallback? onShare;

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
                if (reference != null) ...[const SizedBox(height: 4), Text(reference!, style: t.titleLarge)],
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
