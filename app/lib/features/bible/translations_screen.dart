import 'dart:async' show unawaited;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/bible/bible_models.dart';
import '../../data/bible/bible_module.dart';
import '../../services/bible_import_service.dart';
import '../../services/bible_service.dart';
import '../../widgets/common.dart';

/// Tela "Gerenciar e Importar Traduções": lista traduções nativas (embutidas)
/// e módulos `.json` importados localmente pelo usuário, com barra de progresso,
/// validação detalhada e exclusão para liberar espaço.
class TranslationsScreen extends StatefulWidget {
  const TranslationsScreen({super.key});

  @override
  State<TranslationsScreen> createState() => _TranslationsScreenState();
}

class _TranslationsScreenState extends State<TranslationsScreen> {
  static const _protected = [
    ('CNBB', 'Tradução oficial da CNBB', 'Edições CNBB'),
    ('Ave-Maria', 'Bíblia Sagrada Ave-Maria', 'Editora Ave-Maria'),
    ('Jerusalém', 'Bíblia de Jerusalém', 'Paulus / Éditions du Cerf'),
    ('Pastoral', 'Bíblia Pastoral', 'Paulus'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bible = context.read<BibleService>();
      if (bible.autoInstallBundled) {
        unawaited(bible.ensureBundled().catchError((Object e) => debugPrint('Erro ao preparar Bíblia: $e')));
      } else if (bible.bundledCatalog.isEmpty) {
        unawaited(
          bible.ensureCatalog().catchError((Object e) {
            debugPrint('Erro ao carregar catálogo da Bíblia: $e');
            return const <BundledTranslationInfo>[];
          }),
        );
      }
    });
  }

  Future<void> _downloadBundled(BuildContext context, BibleService bible, BundledTranslationInfo item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await bible.installBundled(item.id);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('“${item.name}” (${item.abbreviation}) pronta para uso offline.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Não foi possível baixar “${item.name}”: $e')));
      }
    }
  }

  Future<void> _run(BuildContext context, Future<BibleImportResult?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await action();
      if (result != null && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '“${result.name}” (${result.abbreviation}) importada: '
              '${result.bookCount} livros, ${result.verseCount} versículos.',
            ),
          ),
        );
      }
    } on BibleModuleException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arquivo fora do padrão'),
          content: Text(
            'Não foi possível validar o arquivo JSON selecionado:\n\n${e.message}\n\n'
            'Verifique se o arquivo possui os metadados obrigatórios (id, nome, sigla, idioma) '
            'e a lista de livros/capítulos/versículos no formato documentado no README.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Não foi possível importar: $e')));
      }
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

  Future<void> _confirmDelete(BuildContext context, BibleService bible, BibleTranslation tr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir “${tr.name}”?'),
        content: Text(
          'Os ${tr.verseCount} versículos serão removidos deste aparelho para liberar espaço. '
          'Suas marcações, favoritos e anotações são mantidos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await bible.remove(tr.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('“${tr.name}” removida.')));
      }
    }
  }

  Widget _tile(BuildContext context, BibleService bible, BibleTranslation tr, TextTheme t) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(tr.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0))),
      title: Text(tr.name),
      subtitle: Text(
        '${tr.language} · ${tr.license}\n'
        '${tr.verseCount} versículos · Salmos: numeração ${tr.psalmNumbering}',
      ),
      isThreeLine: true,
      trailing: tr.bundled
          ? null
          : IconButton(
              tooltip: 'Excluir tradução importada',
              icon: const Icon(Icons.delete_outline),
              onPressed: bible.progress != null ? null : () => _confirmDelete(context, bible, tr),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.watch<BibleService>();
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final bundled = bible.translations.where((tr) => tr.bundled).toList();
    final imported = bible.translations.where((tr) => !tr.bundled).toList();
    final pct = bible.progress == null ? null : (bible.progress! * 100).clamp(0, 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar e Importar Traduções')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          if (bible.progress != null) ...[
            Row(
              children: [
                Expanded(child: Text(bible.progressLabel ?? 'Importando…', style: t.bodySmall)),
                if (pct != null) Text('$pct%', style: t.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: bible.progress),
            const SizedBox(height: VsSpacing.md),
          ],
          const Eyebrow('Traduções nativas (embutidas)'),
          for (final tr in bundled) _tile(context, bible, tr, t),
          for (final item in bible.availableBundled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(item.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0))),
              title: Text(item.name),
              subtitle: Text(
                '${item.language} · ${item.license}'
                '${item.sizeMb != null ? ' · ~${item.sizeMb!.toStringAsFixed(1).replaceAll('.', ',')} MB' : ''}',
              ),
              trailing: OutlinedButton.icon(
                onPressed: bible.progress != null ? null : () => _downloadBundled(context, bible, item),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Baixar'),
              ),
            ),
          if (bundled.isEmpty && bible.availableBundled.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VsSpacing.sm),
              child: Text('Carregando catálogo…', style: t.bodyMedium),
            ),
          const SizedBox(height: VsSpacing.md),
          const Eyebrow('Traduções importadas neste aparelho'),
          if (imported.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: VsSpacing.sm),
              child: Text(
                'Nenhuma tradução importada ainda. Você pode importar arquivos .json no padrão do Via Sacra '
                '(como Figueiredo, Matos Soares, CNBB, Ave-Maria ou Jerusalém) diretamente do seu aparelho.',
                style: t.bodyMedium,
              ),
            )
          else
            for (final tr in imported) _tile(context, bible, tr, t),
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
            'autorização. O app está pronto para recebê-las: se você possuir um arquivo .json compatível, '
            'importe-o acima — ele fica somente neste aparelho e funciona com leitura comparada, busca FTS5, '
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
            label: const Text('Formato do módulo JSON (documentação e esquema)'),
          ),
        ],
      ),
    );
  }
}
