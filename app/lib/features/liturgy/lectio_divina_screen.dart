import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Leitura em tela cheia, sem distrações, com os quatro passos da Lectio Divina.
class LectioDivinaScreen extends StatefulWidget {
  const LectioDivinaScreen({
    super.key,
    required this.title,
    required this.text,
    this.author,
    this.source,
    this.url,
    this.license,
  });

  final String title;
  final String text;
  final String? author;
  final String? source;
  final String? url;
  final String? license;

  @override
  State<LectioDivinaScreen> createState() => _LectioDivinaScreenState();
}

class _LectioDivinaScreenState extends State<LectioDivinaScreen> {
  static const _steps = [
    ('Lectio', 'Leia devagar. O que o texto diz?'),
    ('Meditatio', 'O que o texto diz a mim, hoje?'),
    ('Oratio', 'O que eu digo a Deus a partir desta Palavra?'),
    ('Contemplatio', 'Permaneça em silêncio diante de Deus.'),
  ];
  bool _immersive = false;

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(_immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: _immersive
          ? null
          : AppBar(
              title: const Text('Lectio Divina'),
              actions: [
                IconButton(tooltip: 'Modo imersivo', onPressed: _toggleImmersive, icon: const Icon(Icons.fullscreen)),
              ],
            ),
      body: GestureDetector(
        onDoubleTap: _toggleImmersive,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.xl, pad, VsSpacing.xxl),
            children: [
              if (widget.author != null) Eyebrow(widget.author!),
              const SizedBox(height: 8),
              Text(widget.title, style: t.headlineSmall),
              const CrossDivider(),
              SelectableText(widget.text, style: t.bodyLarge?.copyWith(fontSize: (t.bodyLarge?.fontSize ?? 18) + 2)),
              const CrossDivider(),
              for (final (name, prompt) in _steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: VsSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(name),
                      const SizedBox(height: 4),
                      Text(prompt, style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              if (widget.source != null)
                SourceAttribution(source: widget.source!, url: widget.url, license: widget.license),
              if (_immersive)
                Padding(
                  padding: const EdgeInsets.only(top: VsSpacing.lg),
                  child: Text('Toque duas vezes para sair do modo imersivo.', style: t.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
