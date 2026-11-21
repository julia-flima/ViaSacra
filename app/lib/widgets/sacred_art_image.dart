import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../data/models/mystery.dart';
import 'common.dart';
import 'sacred_art_header.dart';

/// Pintura em domínio público mostrada inteira (sem cortar rostos nem bordas), sobre um fundo
/// desfocado da própria obra, com legenda discreta (título, autor, acervo e licença).
class SacredArtImage extends StatelessWidget {
  const SacredArtImage({super.key, required this.art, this.height = 260, this.semanticLabel});

  final SacredArt? art;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.secondaryContainer, cs.primaryContainer],
        ),
      ),
      alignment: Alignment.center,
      child: Text('✝', style: TextStyle(fontSize: 48, color: cs.secondary.withValues(alpha: 0.6))),
    );
    final a = art;
    final path = a?.assetPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: path == null
                ? placeholder
                : Semantics(
                    image: true,
                    label: semanticLabel ?? '${a!.title}, de ${a.artist}',
                    child: SizedBox(
                      height: height,
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          fit: StackFit.expand,
                          children: [
                            // Fundo: a mesma obra, desfocada e escurecida (pequena: só cor e luz).
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Image.asset(path, fit: BoxFit.cover, cacheWidth: 160, excludeFromSemantics: true),
                            ),
                            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
                            Image.asset(
                              path,
                              fit: BoxFit.contain,
                              cacheWidth: decodeWidth(context, box.maxWidth),
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => placeholder,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (a != null)
          InkWell(
            onTap: a.commonsPage == null ? null : () => openExternal(context, a.commonsPage),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${a.title} — ${a.artist}, ${a.year}. ${a.collection}. ${a.license} (Wikimedia Commons).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }
}
