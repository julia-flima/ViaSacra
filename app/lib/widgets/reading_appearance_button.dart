import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/settings_service.dart';
import 'common.dart';

/// Botão compacto "Aa" para ajustar rapidamente tema (Pergaminho / Modo Igreja),
/// tamanho do texto e tipografia sem sair da tela de leitura.
class ReadingAppearanceButton extends StatelessWidget {
  const ReadingAppearanceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Aparência da leitura (fonte e Modo Igreja)',
      icon: const Icon(Icons.text_fields_rounded),
      onPressed: () => showReadingAppearanceSheet(context),
    );
  }
}

Future<void> showReadingAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Consumer<SettingsService>(
        builder: (context, s, _) {
          final t = Theme.of(context).textTheme;
          final cs = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(VsSpacing.lg, 0, VsSpacing.lg, VsSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('APARÊNCIA DA LEITURA', color: cs.secondary),
                const SizedBox(height: VsSpacing.sm),
                Text('Tema', style: t.titleSmall),
                const SizedBox(height: VsSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Pergaminho'),
                        icon: Icon(Icons.wb_sunny_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Modo Igreja'),
                        icon: Icon(Icons.church_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                        icon: Icon(Icons.brightness_auto_outlined, size: 16),
                      ),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => s.themeMode = v.first,
                  ),
                ),
                const SizedBox(height: VsSpacing.md),
                Row(
                  children: [
                    Text('Tamanho da letra', style: t.titleSmall),
                    const Spacer(),
                    Text('${(s.textScale * 100).round()}%', style: t.labelMedium),
                  ],
                ),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: CommitSlider(
                        value: s.textScale,
                        min: SettingsService.minTextScale,
                        max: SettingsService.maxTextScale,
                        divisions: 21,
                        onCommit: (v) => s.textScale = v,
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: VsSpacing.xs),
                Row(
                  children: [
                    Text('Tipografia', style: t.titleSmall),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Serifa'),
                      selected: s.readingFont == ReadingFont.serif,
                      onSelected: (_) => s.readingFont = ReadingFont.serif,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Sem serifa'),
                      selected: s.readingFont == ReadingFont.sans,
                      onSelected: (_) => s.readingFont = ReadingFont.sans,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
