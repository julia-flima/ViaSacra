import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../data/bible/bible_models.dart';

/// Ações de um versículo: marcar com cor, favoritar, anotar, compartilhar, copiar.
Future<VerseAnnotation?> showVerseActions(
  BuildContext context, {
  required BibleVerse verse,
  required BibleTranslation translation,
  required VerseAnnotation annotation,
}) {
  return showModalBottomSheet<VerseAnnotation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _VerseActions(verse: verse, translation: translation, initial: annotation),
  );
}

String formatVerseForSharing(BibleVerse v, BibleTranslation t) =>
    '“${v.text}”\n— ${v.book.name} ${v.chapter},${v.verse} (${t.abbreviation} — ${t.name})\n(via app Via Sacra)';

class _VerseActions extends StatefulWidget {
  const _VerseActions({required this.verse, required this.translation, required this.initial});

  final BibleVerse verse;
  final BibleTranslation translation;
  final VerseAnnotation initial;

  @override
  State<_VerseActions> createState() => _VerseActionsState();
}

class _VerseActionsState extends State<_VerseActions> {
  late HighlightColor? _color = widget.initial.color;
  late bool _favorite = widget.initial.favorite;
  late final _note = TextEditingController(text: widget.initial.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  VerseAnnotation get _result =>
      VerseAnnotation(color: _color, favorite: _favorite, note: _note.text.trim().isEmpty ? null : _note.text.trim());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = widget.verse;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _result);
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${v.book.name} ${v.chapter},${v.verse}', style: t.titleLarge),
              const SizedBox(height: 6),
              Text(v.text, style: t.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: VsSpacing.md),
              Text('Marcar', style: t.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final c in HighlightColor.values)
                    Semantics(
                      button: true,
                      selected: _color == c,
                      label: 'Marcar em ${c.label}',
                      child: GestureDetector(
                        onTap: () => setState(() => _color = _color == c ? null : c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(dark ? c.dark : c.light),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                              width: _color == c ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_color != null)
                    TextButton(onPressed: () => setState(() => _color = null), child: const Text('Remover marcação')),
                ],
              ),
              const SizedBox(height: VsSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(_favorite ? Icons.bookmark : Icons.bookmark_border),
                title: const Text('Favorito'),
                value: _favorite,
                onChanged: (x) => setState(() => _favorite = x),
              ),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anotação (somente neste aparelho)',
                ),
              ),
              const SizedBox(height: VsSpacing.md),
              // Wrap: em telas estreitas ou fonte grande os botões quebram de linha
              // em vez de estourar a largura (overflow).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              SharePlus.instance.share(ShareParams(text: formatVerseForSharing(v, widget.translation))),
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('Compartilhar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: formatVerseForSharing(v, widget.translation)));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Versículo copiado.')));
                            }
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copiar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(context, _result), child: const Text('Salvar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
