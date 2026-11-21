import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../data/models/mystery.dart';
import 'common.dart';

/// Banner editorial enquadrado com arte sacra em domínio público.
///
/// Projetado para manter enquadramento equilibrado tanto no navegador desktop
/// quanto no celular (sem cortar pinturas em faixas finas) e rolagem fluida.
class SacredArtBanner extends StatelessWidget {
  const SacredArtBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.art,
    this.accentColor,
    this.height,
    this.alignment,
  });

  final String title;
  final String? subtitle;
  final SacredArt? art;
  final Color? accentColor;
  final double? height;

  /// Enquadramento da pintura; por padrão, o foco da própria obra (rostos principais).
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final bannerHeight = height ?? (wide ? 240.0 : 185.0);
    final a = art;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Troca de obra (outro dia ou tempo) com transição suave; sem animação se o sistema pedir.
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 450),
                child: a?.assetPath != null
                    ? Image.asset(
                        a!.assetPath!,
                        key: ValueKey(a.id),
                        fit: BoxFit.cover,
                        alignment: alignment ?? a.focus,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: decodeWidth(context, MediaQuery.sizeOf(context).width),
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => _ArtFallback(cs: cs),
                      )
                    : _ArtFallback(key: const ValueKey('sem-arte'), cs: cs),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              if (a != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.48),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Sobre esta obra',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                      onPressed: () => showSacredArtCreditsSheet(context, a),
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.90),
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54)],
                        ),
                      ),
                    if (subtitle != null) const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 3, // celebrações longas ("…, Memória") não são cortadas
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(
                        color: Colors.white,
                        shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ],
                ),
              ),
              if (accentColor != null)
                Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 3, color: accentColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card ilustrado com pintura sacra para vitrines visuais (ex.: Biblioteca).
class SacredArtCard extends StatelessWidget {
  const SacredArtCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.art,
    this.badge,
    this.icon,
    this.height = 190,
    this.alignment,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final SacredArt? art;
  final String? badge;
  final IconData? icon;
  final double height;

  /// Enquadramento da pintura; por padrão, o foco da própria obra (rostos principais).
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final a = art;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (a?.assetPath != null)
                    Image.asset(
                      a!.assetPath!,
                      fit: BoxFit.cover,
                      alignment: alignment ?? a.focus,
                      cacheWidth: decodeWidth(context, MediaQuery.sizeOf(context).width),
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => _ArtFallback(cs: cs),
                    )
                  else
                    _ArtFallback(cs: cs),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.black.withValues(alpha: 0.38),
                          Colors.black.withValues(alpha: 0.86),
                        ],
                        stops: const [0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          badge!,
                          style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (icon != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                        child: Icon(icon, size: 18, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: t.titleLarge?.copyWith(
                            color: Colors.white,
                            shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54)],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.90), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Largura em pixels para decodificar uma pintura exibida com [logicalWidth]: nítida na tela, sem
/// gastar memória além do arquivo (as imagens têm até 1080 px).
int decodeWidth(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(320, 1080);

/// Abre um bottom sheet discreto com os créditos completos da pintura em domínio público.
Future<void> showSacredArtCreditsSheet(BuildContext context, SacredArt art) {
  final t = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VsSpacing.lg, 0, VsSpacing.lg, VsSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('ARTE SACRA · DOMÍNIO PÚBLICO', color: cs.secondary),
            const SizedBox(height: 6),
            Text(art.title, style: t.titleLarge),
            const SizedBox(height: 4),
            Text('${art.artist} (${art.year})', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (art.collection.isNotEmpty) ...[const SizedBox(height: 2), Text(art.collection, style: t.bodySmall)],
            const SizedBox(height: VsSpacing.md),
            Text('Obra em ${art.license} disponibilizada via Wikimedia Commons.', style: t.bodySmall),
            if (art.commonsPage != null) ...[
              const SizedBox(height: VsSpacing.md),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  openExternal(context, art.commonsPage);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ver no Wikimedia Commons'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback({super.key, required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cs.primary, cs.secondary],
      ),
    ),
    alignment: Alignment.center,
    child: Text('✝', style: TextStyle(fontSize: 44, color: Colors.white.withValues(alpha: 0.35))),
  );
}
