import 'package:material_ui/material_ui.dart';

import '../data/models/mystery.dart';
import 'common.dart';

/// Pintura em domínio público com legenda discreta (título, autor, status).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: a?.assetPath == null
                ? placeholder
                : Semantics(
                    image: true,
                    label: semanticLabel ?? '${a!.title}, de ${a.artist}',
                    child: Image.asset(
                      a!.assetPath!,
                      height: height,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      cacheWidth: 800,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => placeholder,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }
}
