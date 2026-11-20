import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../services/bible_service.dart';
import '../../services/native_tts.dart';
import '../../services/notification_service.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../bible/translations_screen.dart';
import 'about_screen.dart';

/// Aba 5 — Ajustes, Notificações & Sobre o Projeto.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsService>();
    final services = context.read<AppServices>();
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);

    Future<void> reschedule() async =>
        services.notifications?.reschedule(services.settings, services.liturgyRepository);

    Future<void> pickTime(TimeOfDay initial, void Function(TimeOfDay) save) async {
      final picked = await showTimePicker(context: context, initialTime: initial, helpText: 'Horário do lembrete');
      if (picked != null) {
        save(picked);
        await reschedule();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          // ------------------------------------------------ Notificações
          const _Section('Lembretes (100% locais)'),
          if (kIsWeb)
            const _WebRemindersNotice()
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativar lembretes'),
              subtitle: const Text('Agendados no próprio aparelho. Nenhum servidor envia notificações.'),
              value: st.notificationsEnabled,
              onChanged: (v) async {
                if (v) {
                  final granted = await services.notifications?.requestPermission() ?? false;
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Permissão de notificações não concedida. Você pode ativá-la nos ajustes do sistema.',
                        ),
                      ),
                    );
                    return;
                  }
                }
                st.notificationsEnabled = v;
                await reschedule();
              },
            ),
          if (!kIsWeb && st.notificationsEnabled) ...[
            _ReminderTile(
              title: 'Liturgia Diária',
              example: NotificationService.liturgyMessage(DateTime.now(), services.liturgyRepository).$2,
              enabled: st.liturgyReminder,
              time: st.liturgyReminderTime,
              onToggle: (v) async {
                st.liturgyReminder = v;
                await reschedule();
              },
              onPickTime: () => pickTime(st.liturgyReminderTime, (t) => st.liturgyReminderTime = t),
            ),
            _ReminderTile(
              title: 'Santo Terço',
              example: NotificationService.rosaryMessage(DateTime.now()).$2,
              enabled: st.rosaryReminder,
              time: st.rosaryReminderTime,
              onToggle: (v) async {
                st.rosaryReminder = v;
                await reschedule();
              },
              onPickTime: () => pickTime(st.rosaryReminderTime, (t) => st.rosaryReminderTime = t),
            ),
          ],

          // ------------------------------------------------ Áudio
          const _Section('Leitura em voz alta'),
          Text('Velocidade padrão', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: [
              for (final s in SettingsService.speeds)
                ButtonSegment(value: s, label: Text('${s.toString().replaceAll('.', ',').replaceAll(',0', '')}×')),
            ],
            selected: {st.ttsSpeed},
            onSelectionChanged: (v) {
              st.ttsSpeed = v.first;
              context.read<ReadingAudioController>().setSpeed(v.first);
            },
          ),
          if (kIsWeb || nativeTtsIsSupported()) ...[
            const SizedBox(height: VsSpacing.md),
            Text('Voz neural (Kokoro-82M · pt-BR)', style: t.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [for (final v in KokoroVoice.all) ButtonSegment(value: v.id, label: Text(v.label))],
              selected: {st.kokoroVoice},
              onSelectionChanged: (v) {
                st.kokoroVoice = v.first;
                context.read<ReadingAudioController>().setKokoroVoice(v.first);
              },
            ),
            const _NeuralKokoroCacheTile(),
          ],
          if (!kIsWeb)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Voz de reserva do aparelho'),
              subtitle: Text(st.ttsVoiceName ?? 'Padrão do sistema (usada caso a voz neural não esteja baixada)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickVoice(context),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preferir áudio narrado quando disponível'),
            subtitle: const Text('Áudio MP3 pronto da Liturgia e Homilia; senão usa a voz neural offline.'),
            value: st.preferRecordedAudio,
            onChanged: (v) => st.preferRecordedAudio = v,
          ),

          // ------------------------------------------------ Constância
          const _Section('Constância'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar sequência de dias em oração'),
            subtitle: const Text('Discreto e opcional. Os registros ficam só neste aparelho.'),
            value: st.showStreak,
            onChanged: (v) => st.showStreak = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibração no terço'),
            subtitle: const Text('Vibração suave a cada conta e dupla ao concluir a dezena.'),
            value: st.haptics,
            onChanged: (v) => st.haptics = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Abrir orações em latim'),
            value: st.preferLatin,
            onChanged: (v) => st.preferLatin = v,
          ),

          // ------------------------------------------------ Tipografia e tema
          const _Section('Leitura e aparência'),
          Text('Tema', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Pergaminho'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Igreja'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {st.themeMode},
            onSelectionChanged: (v) => st.themeMode = v.first,
          ),
          const SizedBox(height: VsSpacing.md),
          Text('Fonte', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ReadingFont>(
            segments: const [
              ButtonSegment(value: ReadingFont.serif, label: Text('Serifada clássica')),
              ButtonSegment(value: ReadingFont.sans, label: Text('Sem serifa')),
            ],
            selected: {st.readingFont},
            onSelectionChanged: (v) => st.readingFont = v.first,
          ),
          const SizedBox(height: VsSpacing.md),
          Text('Tamanho da letra', style: t.titleSmall),
          Slider(
            value: st.textScale,
            min: SettingsService.minTextScale,
            max: SettingsService.maxTextScale,
            divisions: 15,
            label: '${(st.textScale * 100).round()}%',
            onChanged: (v) => st.textScale = v,
          ),
          Text('Espaçamento entre linhas', style: t.titleSmall),
          Slider(
            value: st.lineHeight,
            min: 1.3,
            max: 2.1,
            divisions: 8,
            label: st.lineHeight.toStringAsFixed(1),
            onChanged: (v) => st.lineHeight = v,
          ),
          Container(
            padding: const EdgeInsets.all(VsSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Naquele tempo, disse Jesus: “Eu sou o caminho, a verdade e a vida.”', style: t.bodyLarge),
          ),

          // ------------------------------------------------ Bíblia Sagrada
          const _Section('Bíblia Sagrada'),
          Builder(
            builder: (context) {
              final count = context.watch<BibleService>().translations.length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.translate_outlined),
                title: const Text('Gerenciar e Importar Traduções'),
                subtitle: Text(
                  count == 0
                      ? 'Importar arquivos .json ou remover traduções'
                      : '$count tradução(ões) instalada(s) neste aparelho',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TranslationsScreen())),
              );
            },
          ),

          // ------------------------------------------------ Sobre
          const _Section('Sobre'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o Via Sacra & Licenças'),
            subtitle: const Text('Autoria, créditos, fontes e código aberto'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVoice(BuildContext context) async {
    final audio = context.read<ReadingAudioController>();
    final st = context.read<SettingsService>();
    final voices = await audio.voices();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Padrão do sistema'),
              trailing: st.ttsVoiceName == null ? const Icon(Icons.check) : null,
              onTap: () {
                st.setTtsVoice(null, null);
                audio.setVoice(null, null); // volta o player ativo à voz padrão
                Navigator.pop(ctx);
              },
            ),
            if (voices.isEmpty)
              const ListTile(
                title: Text('Nenhuma voz em português encontrada'),
                subtitle: Text('Instale uma voz pt-BR nas configurações de "Texto para fala" do sistema.'),
              ),
            for (final v in voices)
              ListTile(
                title: Text(v.name),
                subtitle: Text(v.locale),
                trailing: st.ttsVoiceName == v.name ? const Icon(Icons.check) : null,
                onTap: () {
                  st.setTtsVoice(v.name, v.locale);
                  audio.setVoice(v.name, v.locale);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NeuralKokoroCacheTile extends StatelessWidget {
  const _NeuralKokoroCacheTile();

  @override
  Widget build(BuildContext context) {
    final status = context.select<ReadingAudioController, NeuralTtsStatus>((a) => a.neuralTtsStatus);
    final audio = context.read<ReadingAudioController>();
    final t = Theme.of(context).textTheme;

    if (status.isBusy) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: VsSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status.label ?? 'Preparando voz neural offline…', style: t.bodySmall),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: status.progress),
          ],
        ),
      );
    }

    final sizeHint = kIsWeb ? '~92 MB' : '~126 MB';
    final cachedWhere = kIsWeb ? 'Salvo no navegador' : 'Salvo neste aparelho';
    final subtitle = status.cached
        ? '$cachedWhere (${status.cacheSizeLabel})'
              '${status.deviceLabel.isNotEmpty ? ' · ${status.deviceLabel}' : ''}'
        : status.error != null
        ? 'Falha no download · tente novamente ($sizeHint offline)'
        : '$sizeHint · baixado uma única vez para uso offline';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Modelo de voz offline (Kokoro-82M)'),
      subtitle: Text(subtitle),
      trailing: status.cached
          ? TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await audio.clearNeuralTtsCache();
                messenger.showSnackBar(const SnackBar(content: Text('Cache da voz neural removido.')));
              },
              child: const Text('Limpar cache'),
            )
          : OutlinedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await audio.preloadNeuralTts();
                if (!ok) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Não foi possível baixar o modelo de voz agora.')),
                  );
                }
              },
              child: const Text('Baixar agora'),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: VsSpacing.lg, bottom: VsSpacing.xs),
    child: Eyebrow(title),
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.example,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final String example;
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VsSpacing.md, 4, 4, VsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.titleMedium)),
                TextButton(onPressed: enabled ? onPickTime : null, child: Text(time.format(context))),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
            Text('Exemplo: “$example”', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Na versão Web, lembretes agendados não são confiáveis (o navegador não
/// executa nada com o app fechado), então indicamos o app nativo.
class _WebRemindersNotice extends StatelessWidget {
  const _WebRemindersNotice();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(VsSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você está usando a versão Web. Os lembretes agendados da Liturgia e do Terço estão '
              'disponíveis no app para Android e iOS.',
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
