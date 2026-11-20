import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// "Sobre o Via Sacra & Licenças".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.lg, pad, VsSpacing.xxl),
        children: [
          Center(
            child: Text('✝', style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.secondary)),
          ),
          const SizedBox(height: VsSpacing.sm),
          Center(child: Text(AppInfo.name, style: t.displaySmall)),
          Center(child: Text('Versão ${AppInfo.version}', style: t.bodySmall)),
          const SizedBox(height: VsSpacing.lg),
          Text(
            'Idealizado e desenvolvido por ${AppInfo.author}.\n\n'
            'O Via Sacra é 100% gratuito, sem anúncios, sem rastreadores e de código aberto. '
            'Funciona offline e não coleta nenhum dado: favoritos, anotações e constância '
            'ficam somente no seu aparelho.',
            style: t.bodyLarge,
          ),
          const CrossDivider(),
          const Eyebrow('Créditos e fontes'),
          const SizedBox(height: VsSpacing.sm),
          const SourceAttribution(
            source: 'CNBB — Liturgia Diária',
            url: ExternalLinks.cnbb,
            license: 'Textos litúrgicos para uso devocional e não comercial.',
          ),
          const SourceAttribution(
            source: 'Vatican News (Português) — Dicastério para a Comunicação',
            url: ExternalLinks.vaticanNews,
            license: '© Libreria Editrice Vaticana. Uso pastoral não comercial, com citação e link.',
          ),
          const SourceAttribution(
            source: 'Santos Padres — Santo Agostinho, São João Crisóstomo, Catena Aurea',
            license: 'Obras em domínio público.',
          ),
          const SourceAttribution(
            source: 'Wikimedia Commons, The Met Open Access, National Gallery of Art',
            url: ExternalLinks.commons,
            license: 'Arte sacra em domínio público / CC0.',
          ),
          const SourceAttribution(
            source: 'Catecismo da Igreja Católica',
            url: ExternalLinks.catechismVatican,
            license: '© Libreria Editrice Vaticana. Aberto no portal oficial; não é copiado no app.',
          ),
          const SourceAttribution(
            source: 'Bíblia Portuguesa Mundial (eBible.org), Vulgata Clementina e Douay-Rheims',
            url: 'https://ebible.org/find/details.php?id=porbrbsl',
            license: 'Domínio público. Vulgata e Douay-Rheims via github.com/mborders/vulgata (código MIT).',
          ),
          const SourceAttribution(
            source: 'Catecismo Maior de São Pio X (Tipografia Vaticana, 1905)',
            license:
                'Original em domínio público. Tradução do italiano pelo projeto Via Sacra, em domínio público (CC0).',
          ),
          const SourceAttribution(
            source: 'Tomás de Kempis — A Imitação de Cristo (trad. E. L. de Souza Campos)',
            url: 'https://archive.org/details/tomas-de-kempis-imitacao-de-cristo',
            license: '© 2023 Valdemar Teodoro Editor — cópia e divulgação permitidas, desde que citada a fonte.',
          ),
          const SourceAttribution(
            source: 'Santo Afonso Maria de Ligório — Via Sacra (1761)',
            license: 'Domínio público.',
          ),
          const SourceAttribution(
            source: 'Salmo Responsorial cantado — vídeos de canais do YouTube',
            url: 'https://www.youtube-nocookie.com',
            license: 'Incorporação oficial (youtube-nocookie), sem hospedar os vídeos; canal e intérprete citados em cada Salmo.',
          ),
          const SourceAttribution(
            source: 'Kokoro-82M, sherpa-onnx & eSpeak-NG (leitura neural offline)',
            url: 'https://github.com/k2-fsa/sherpa-onnx',
            license: 'Apache-2.0 (Kokoro-82M / sherpa-onnx) e GPL-3.0 (eSpeak-NG).',
          ),
          const CrossDivider(),
          const Eyebrow('Código aberto'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: const Text('Repositório no GitHub'),
            subtitle: const Text(AppInfo.repositoryUrl),
            onTap: () => openExternal(context, AppInfo.repositoryUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Relatar um problema ou sugerir melhoria'),
            onTap: () => openExternal(context, AppInfo.issuesUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Licença GNU GPL v3.0 (texto integral)'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _LicenseText())),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Licenças das bibliotecas'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
              applicationLegalese: '© 2026 ${AppInfo.author} — GPL-3.0',
            ),
          ),
          const SizedBox(height: VsSpacing.lg),
          Center(
            child: Text('Ad maiorem Dei gloriam', style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}

class _LicenseText extends StatelessWidget {
  const _LicenseText();

  @override
  Widget build(BuildContext context) {
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(title: const Text('GPL-3.0')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/LICENSE.txt'),
        builder: (context, snap) => snap.hasData
            ? SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
                child: SelectionArea(
                  child: Text(snap.data!, style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, height: 1.4)),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
