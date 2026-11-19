import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/bible/bible_module.dart';
import '../../services/bible_service.dart';
import '../../widgets/common.dart';

/// Gerenciador de traduções: embutidas (domínio público) e módulos importados
/// localmente pelo usuário.
class TranslationsScreen extends StatelessWidget {
  const TranslationsScreen({super.key});

  static const _protected = [
    ('CNBB', 'Tradução oficial da CNBB', 'Edições CNBB'),
    ('Ave-Maria', 'Bíblia Sagrada Ave-Maria', 'Editora Ave-Maria'),
    ('Jerusalém', 'Bíblia de Jerusalém', 'Paulus / Éditions du Cerf'),
    ('Pastoral', 'Bíblia Pastoral', 'Paulus'),
  ];

  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await action();
      if (name != null) messenger.showSnackBar(SnackBar(content: Text('“$name” instalada.')));
    } on BibleModuleException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Módulo inválido: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível importar: $e')));
    }
  }

  Future<void> _importUrl(BuildContext context, BibleService bible) async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar de um endereço'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://…/minha-traducao.json'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Importar')),
        ],
      ),
    );
    if (url != null && url.trim().isNotEmpty && context.mounted) {
      await _run(context, () => bible.importFromUrl(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.watch<BibleService>();
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Traduções da Bíblia')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          if (bible.progress != null) ...[
            Text(bible.progressLabel ?? '', style: t.bodySmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: bible.progress),
            const SizedBox(height: VsSpacing.md),
          ],
          const Eyebrow('Instaladas neste aparelho'),
          for (final tr in bible.translations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(tr.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0))),
              title: Text(tr.name),
              subtitle: Text(
                '${tr.language} · ${tr.license}${tr.bundled ? ' · embutida' : ' · importada'}\n'
                '${tr.verseCount} versículos',
              ),
              isThreeLine: true,
              trailing: tr.bundled
                  ? null
                  : IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Remover “${tr.name}”?'),
                            content: const Text('Suas marcações e anotações são mantidas.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
                            ],
                          ),
                        );
                        if (ok ?? false) await bible.remove(tr.id);
                      },
                    ),
            ),
          const SizedBox(height: VsSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: bible.progress != null ? null : () => _run(context, bible.importFromFile),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Importar arquivo (.json)'),
              ),
              OutlinedButton.icon(
                onPressed: bible.progress != null ? null : () => _importUrl(context, bible),
                icon: const Icon(Icons.link),
                label: const Text('Importar de endereço'),
              ),
            ],
          ),
          const CrossDivider(),
          const Eyebrow('Traduções protegidas por direitos autorais'),
          const SizedBox(height: VsSpacing.sm),
          Text(
            'As traduções abaixo pertencem às suas editoras e não podem ser distribuídas pelo Via Sacra sem '
            'autorização. O app está pronto para recebê-las: se você possuir um módulo autorizado pela editora, '
            'importe-o acima — ele fica somente neste aparelho e funciona com leitura comparada, busca, '
            'marcações e áudio. O Via Sacra não fornece nem indica onde obter esses arquivos.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: VsSpacing.sm),
          for (final (abbr, name, holder) in _protected)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.lock_outline),
              title: Text('$name ($abbr)'),
              subtitle: Text('© $holder — requer autorização do titular'),
            ),
          const SizedBox(height: VsSpacing.sm),
          TextButton.icon(
            onPressed: () => openExternal(context, '${AppInfo.repositoryUrl}/blob/main/docs/BIBLE.md'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Formato do módulo de tradução (para editoras e desenvolvedores)'),
          ),
        ],
      ),
    );
  }
}
