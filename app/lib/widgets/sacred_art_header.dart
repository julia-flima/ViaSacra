import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../data/models/mystery.dart';
import 'common.dart';

/// Cabeçalho editorial expansível com arte sacra em domínio público,
/// efeito parallax, degradê duplo (contraste garantido) e botão discreto de créditos.
class SacredArtSliverHeader extends StatelessWidget {
  const SacredArtSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.art,
    this.expandedHeight = 220,
    this.accentColor,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.imageAlignment = Alignment.topCenter,
  });

  final String title;
  final String? subtitle;
  final SacredArt? art;
  final double expandedHeight;
  final Color? accentColor;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final a = art;

    final allActions = [
      ...actions,
      if (a != null)
        IconButton(
          tooltip: 'Sobre esta obra',
          icon: const Icon(Icons.info_outline, size: 20),
          onPressed: () => showSacredArtCreditsSheet(context, a),
        ),
    ];

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: cs.surface,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      leading: leading,
      actions: allActions,
      bottom: bottom,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minH = kToolbarHeight + topPadding + (bottom?.preferredSize.height ?? 0);
          final ratio = ((constraints.maxHeight - minH) / (expandedHeight - minH).clamp(1, 999)).clamp(0.0, 1.0);
          final collapsed = ratio < 0.25;

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            titlePadding: EdgeInsetsDirectional.only(
              start: leading != null || Navigator.canPop(context) ? 56 : 20,
              end: 56,
              bottom: (bottom?.preferredSize.height ?? 0) + 14,
            ),
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: (t.titleMedium ?? const TextStyle(fontSize: 18)).copyWith(
                color: collapsed ? cs.onSurface : Colors.white,
                fontWeight: FontWeight.w600,
                shadows: collapsed ? null : const [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54)],
              ),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (a?.assetPath != null)
                  Image.asset(
                    a!.assetPath!,
                    fit: BoxFit.cover,
                    alignment: imageAlignment,
                    errorBuilder: (_, _, _) => _ArtFallback(cs: cs),
                  )
                else
                  _ArtFallback(cs: cs),
                // Degradê duplo: protege barra superior/ícones e ancora o título na base
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.52),
                        Colors.black.withValues(alpha: 0.14),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
                if (subtitle != null && ratio > 0.35)
                  Positioned(
                    left: leading != null || Navigator.canPop(context) ? 56 : 20,
                    right: 20,
                    bottom: (bottom?.preferredSize.height ?? 0) + 46,
                    child: Opacity(
                      opacity: ((ratio - 0.35) / 0.65).clamp(0.0, 1.0),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ),
                if (accentColor != null)
                  Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 3, color: accentColor)),
              ],
            ),
          );
        },
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
    this.height = 168,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final SacredArt? art;
  final String? badge;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final a = art;

    return Semantics(
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
                    alignment: Alignment.topCenter,
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
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.45),
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
                        style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
                          fontWeight: FontWeight.w600,
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
    );
  }
}

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
  const _ArtFallback({required this.cs});
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
