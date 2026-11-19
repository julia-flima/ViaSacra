import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';

/// Onboarding leve: apresentação + escolha livre sobre lembretes.
/// A escolha do usuário é respeitada — nunca perguntamos de novo.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;

  Future<void> _finish({required bool reminders}) async {
    setState(() => _busy = true);
    final s = context.read<AppServices>();
    final settings = context.read<SettingsService>();
    if (reminders) {
      final granted = await s.notifications?.requestPermission() ?? false;
      settings.notificationsEnabled = granted;
      await s.notifications?.reschedule(settings, s.liturgyRepository);
    }
    await settings.setOnboardingDone();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, VsSpacing.xxl, pad, VsSpacing.xl),
          children: [
            Text('✝', style: TextStyle(fontSize: 44, color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: VsSpacing.md),
            Text('Via Sacra', style: t.displaySmall),
            const SizedBox(height: VsSpacing.sm),
            Text('Liturgia, Bíblia, Terço, Catecismo e Orações — em silêncio, sem distrações.', style: t.bodyLarge),
            const CrossDivider(),
            for (final (icon, title, body) in const [
              (Icons.volunteer_activism_outlined, 'Gratuito para sempre', 'Sem anúncios, sem assinaturas.'),
              (Icons.shield_outlined, 'Sem rastreadores', 'Nenhum dado seu sai do aparelho.'),
              (Icons.cloud_off_outlined, 'Funciona offline', 'Orações, Terço e leitura em voz alta sem internet.'),
              (Icons.code, 'Código aberto', 'Licença GPL-3.0, feito com carinho por Júlia Lima.'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon),
                title: Text(title, style: t.titleMedium),
                subtitle: Text(body, style: t.bodySmall),
              ),
            const CrossDivider(),
            if (kIsWeb) ...[
              Text(
                'Dica: adicione o Via Sacra à tela inicial do celular para abri-lo como um app, mesmo sem '
                'internet. Os lembretes agendados estão disponíveis no app para Android e iOS.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: VsSpacing.lg),
              FilledButton(onPressed: _busy ? null : () => _finish(reminders: false), child: const Text('Começar')),
            ] else ...[
              Text('Deseja receber lembretes?', style: t.titleLarge),
              const SizedBox(height: VsSpacing.sm),
              Text(
                'Um lembrete matinal da Liturgia (com o Evangelho do dia) e um lembrete do Santo Terço '
                '(com os mistérios do dia). Tudo agendado no próprio aparelho — você pode mudar os horários '
                'ou desativar a qualquer momento em Ajustes.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: VsSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : () => _finish(reminders: true),
                child: const Text('Sim, ativar lembretes'),
              ),
              const SizedBox(height: VsSpacing.sm),
              OutlinedButton(onPressed: _busy ? null : () => _finish(reminders: false), child: const Text('Agora não')),
            ],
          ],
        ),
      ),
    );
  }
}
