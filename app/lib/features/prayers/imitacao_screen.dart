import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';

class _ImitationBook {
  const _ImitationBook({required this.number, required this.title, required this.subtitle, required this.chapters});

  final String number;
  final String title;
  final String subtitle;
  final List<_ImitationChapter> chapters;
}

class _ImitationChapter {
  const _ImitationChapter({
    required this.bookNumber,
    required this.number,
    required this.title,
    required this.paragraphs,
  });

  final String bookNumber;
  final int number;
  final String title;
  final List<String> paragraphs;

  String get label => 'Livro $bookNumber · Cap. $number';
}

/// Leitor 100% offline de "A Imitação de Cristo" (Tomás de Kempis — 4 Livros, 114 capítulos).
class ImitacaoScreen extends StatefulWidget {
  const ImitacaoScreen({super.key});

  @override
  State<ImitacaoScreen> createState() => _ImitacaoScreenState();
}

class _ImitacaoScreenState extends State<ImitacaoScreen> {
  List<_ImitationBook>? _books;
  String _source = '';
  String _license = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/imitacao_de_cristo.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final books = [
      for (final b in (data['livros'] as List).cast<Map<String, dynamic>>())
        _ImitationBook(
          number: b['numero'] as String,
          title: b['titulo'] as String,
          subtitle: b['subtitulo'] as String? ?? '',
          chapters: [
            for (final c in (b['capitulos'] as List).cast<Map<String, dynamic>>())
              _ImitationChapter(
                bookNumber: b['numero'] as String,
                number: (c['numero'] as num).toInt(),
                title: c['titulo'] as String? ?? '',
                paragraphs: (c['paragrafos'] as List).cast<String>(),
              ),
          ],
        ),
    ];
    if (mounted) {
      setState(() {
        _books = books;
        _source = data['fonte'] as String? ?? 'Tomás de Kempis — A Imitação de Cristo';
        _license = data['licenca'] as String? ?? 'Domínio público';
      });
    }
  }

  void _openChapter(List<_ImitationChapter> all, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImitacaoChapterScreen(chapters: all, initialIndex: index, source: _source, license: _license),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final books = _books;
    if (books == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('A Imitação de Cristo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final all = [for (final b in books) ...b.chapters];
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final todayIdx = all.isEmpty ? 0 : dayOfYear % all.length;
    final today = all.isEmpty ? null : all[todayIdx];

    return Scaffold(
      appBar: AppBar(title: const Text('A Imitação de Cristo')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          if (today != null)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
                leading: Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text('Leitura sugerida de hoje · ${today.label}', style: t.titleSmall),
                subtitle: Text(today.title, style: t.titleMedium),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _openChapter(all, todayIdx),
              ),
            ),
          const SizedBox(height: VsSpacing.sm),
          for (final b in books)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              title: Text(b.title, style: t.titleLarge),
              subtitle: Text(b.subtitle.isEmpty ? '${b.chapters.length} capítulos' : b.subtitle, style: t.bodySmall),
              children: [
                for (final c in b.chapters)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '${c.number}',
                      style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(c.title, style: t.bodyMedium),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _openChapter(all, all.indexOf(c)),
                  ),
              ],
            ),
          const CrossDivider(),
          SourceAttribution(source: _source, license: _license),
        ],
      ),
    );
  }
}

class _ImitacaoChapterScreen extends StatefulWidget {
  const _ImitacaoChapterScreen({
    required this.chapters,
    required this.initialIndex,
    required this.source,
    required this.license,
  });

  final List<_ImitationChapter> chapters;
  final int initialIndex;
  final String source;
  final String license;

  @override
  State<_ImitacaoChapterScreen> createState() => _ImitacaoChapterScreenState();
}

class _ImitacaoChapterScreenState extends State<_ImitacaoChapterScreen> {
  late int _index = widget.initialIndex;

  void _listen(_ImitationChapter c) {
    final settings = context.read<SettingsService>();
    final speech = '${c.label}. ${c.title}. ${c.paragraphs.join(' ')}';
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'imitacao-${c.bookNumber}-${c.number}',
        title: c.label,
        subtitle: c.title,
        text: speech,
        language: 'pt-BR',
      ),
      speed: settings.ttsSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapters[_index];
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.label),
        actions: [
          IconButton(
            tooltip: 'Ouvir capítulo (TTS)',
            icon: const Icon(Icons.headphones_outlined),
            onPressed: () => _listen(c),
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              final text =
                  '${c.title}\n\n${c.paragraphs.join('\n\n')}\n\n— Tomás de Kempis, A Imitação de Cristo (${c.label})';
              unawaited(SharePlus.instance.share(ShareParams(text: text)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
        children: [
          Eyebrow(c.label),
          const SizedBox(height: 6),
          Text(c.title, style: t.headlineSmall),
          const SizedBox(height: VsSpacing.md),
          for (var i = 0; i < c.paragraphs.length; i++) ...[
            SelectableText('${i + 1}. ${c.paragraphs[i]}', style: t.bodyLarge),
            const SizedBox(height: VsSpacing.md),
          ],
          const SizedBox(height: VsSpacing.sm),
          Row(
            children: [
              if (_index > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _index--),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
              const Spacer(),
              if (_index < widget.chapters.length - 1)
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _index++),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Próximo'),
                ),
            ],
          ),
          const CrossDivider(),
          SourceAttribution(source: widget.source, license: widget.license),
        ],
      ),
    );
  }
}
