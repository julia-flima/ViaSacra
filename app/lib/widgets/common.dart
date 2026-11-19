import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

Future<void> openExternal(BuildContext context, String? url) async {
  if (url == null) return;
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
  }
}

/// Ornamento editorial: fio dourado com uma cruz ao centro.
class CrossDivider extends StatelessWidget {
  const CrossDivider({super.key, this.padding = const EdgeInsets.symmetric(vertical: VsSpacing.lg)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7);
    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Divider(color: c.withValues(alpha: 0.4), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('✝', style: TextStyle(color: c, fontSize: 14)),
            ),
            Expanded(child: Divider(color: c.withValues(alpha: 0.4), height: 1)),
          ],
        ),
      ),
    );
  }
}

/// Rótulo em versalete (ex.: "PRIMEIRA LEITURA").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color ?? Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );
}

/// Atribuição de fonte, sempre visível ("Fonte: CNBB · ver original").
class SourceAttribution extends StatelessWidget {
  const SourceAttribution({super.key, required this.source, this.url, this.license});

  final String source;
  final String? url;
  final String? license;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Semantics(
      link: url != null,
      label: 'Fonte: $source${url != null ? '. Toque para abrir o original' : ''}',
      child: InkWell(
        onTap: url == null ? null : () => openExternal(context, url),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('Fonte: $source', style: style)),
                    if (url != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.open_in_new, size: 13, color: style?.color),
                    ],
                  ],
                ),
                if (license != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(license!, style: style?.copyWith(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador discreto e encorajador de constância.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = days == 0
        ? 'Comece hoje sua caminhada de oração'
        : days == 1
        ? '1 dia em oração'
        : '$days dias seguidos em oração';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_outlined, size: 16, color: cs.secondary),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}
