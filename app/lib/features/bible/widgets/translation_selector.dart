import 'package:material_ui/material_ui.dart';

import '../../../data/bible/bible_models.dart';

/// Resultado do seletor rápido de traduções.
class TranslationChoice {
  const TranslationChoice({
    this.translationId,
    this.compareId,
    this.downloadBundledId,
    this.clearCompare = false,
    this.manage = false,
  });
  final String? translationId;
  final String? compareId;
  final String? downloadBundledId;
  final bool clearCompare;
  final bool manage;
}

Future<TranslationChoice?> showTranslationSelector(
  BuildContext context, {
  required List<BibleTranslation> translations,
  List<BundledTranslationInfo> availableBundled = const [],
  required String currentId,
  String? compareId,
}) {
  return showModalBottomSheet<TranslationChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Tradução', style: t.titleLarge),
          ),
          for (final tr in translations)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                child: Text(tr.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0)),
              ),
              title: Text(tr.name),
              subtitle: Text('${tr.language} · ${tr.license}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: tr.id == currentId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, TranslationChoice(translationId: tr.id)),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Leitura comparada (versículo a versículo)', style: t.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Desligada'),
                  selected: compareId == null,
                  onSelected: (_) => Navigator.pop(ctx, const TranslationChoice(clearCompare: true)),
                ),
                for (final tr in translations.where((x) => x.id != currentId))
                  ChoiceChip(
                    label: Text(tr.abbreviation),
                    selected: compareId == tr.id,
                    onSelected: (_) => Navigator.pop(ctx, TranslationChoice(compareId: tr.id)),
                  ),
              ],
            ),
          ),
          if (availableBundled.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text('Disponíveis para baixar (domínio público)', style: t.titleSmall),
            ),
            for (final item in availableBundled)
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  child: Text(item.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0)),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.language}'
                  '${item.sizeSuffix}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.download_outlined),
                onTap: () => Navigator.pop(ctx, TranslationChoice(downloadBundledId: item.id)),
              ),
          ],
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.library_add_outlined),
            title: const Text('Gerenciar e importar traduções'),
            onTap: () => Navigator.pop(ctx, const TranslationChoice(manage: true)),
          ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}
