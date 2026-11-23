import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/backup_repository.dart';
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
              example: NotificationService.liturgyExample(services.liturgyRepository),
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
                ButtonSegment(value: s, label: Text(SettingsService.speedLabel(s))),
            ],
            selected: {st.ttsSpeed},
            onSelectionChanged: (v) {
              st.ttsSpeed = v.first;
              context.read<ReadingAudioController>().setSpeed(v.first);
            },
          ),
          const SizedBox(height: VsSpacing.md),
          const _VoiceSettings(),
          if (!kIsWeb)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(st.ttsEngine == TtsEngine.system ? 'Voz do aparelho' : 'Voz de reserva do aparelho'),
              subtitle: Text(st.ttsVoiceName ?? 'Padrão do sistema'),
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
              ButtonSegment(value: ThemeMode.light, label: Text('Pergaminho'), icon: Icon(Icons.wb_sunny_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Modo Igreja'), icon: Icon(Icons.church_outlined)),
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
              ButtonSegment(value: ReadingFont.serif, label: Text('Serifa')),
              ButtonSegment(value: ReadingFont.sans, label: Text('Sem serifa')),
            ],
            selected: {st.readingFont},
            onSelectionChanged: (v) => st.readingFont = v.first,
          ),
          const SizedBox(height: VsSpacing.md),
          Text('Tamanho da letra', style: t.titleSmall),
          CommitSlider(
            value: st.textScale,
            min: SettingsService.minTextScale,
            max: SettingsService.maxTextScale,
            divisions: 21,
            label: (v) => '${(v * 100).round()}%',
            onCommit: (v) => st.textScale = v,
          ),
          Text('Espaçamento entre linhas', style: t.titleSmall),
          CommitSlider(
            value: st.lineHeight,
            min: 1.3,
            max: 2.1,
            divisions: 8,
            label: (v) => v.toStringAsFixed(1),
            onCommit: (v) => st.lineHeight = v,
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

          // ------------------------------------------------ Backup
          const _Section('Backup dos seus dados'),
          const _BackupTiles(),

          // ------------------------------------------------ Redefinir
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restart_alt),
            title: const Text('Redefinir ajustes'),
            subtitle: const Text('Volta aparência, voz e lembretes ao padrão, sem apagar seus dados'),
            onTap: () => _confirmReset(context, services),
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

/// Escolha do motor de voz (Kokoro embutido, Piper baixável, voz do sistema) e das vozes.
class _VoiceSettings extends StatelessWidget {
  const _VoiceSettings();

  static const _sample =
      'Esta é a voz escolhida para ler a Liturgia, as orações e a Bíblia no Via Sacra. '
      'Compare as vozes e fique com a que achar mais agradável.';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsService>();
    final status = context.select<ReadingAudioController, NeuralTtsStatus>((a) => a.neuralTtsStatus);
    final audio = context.read<ReadingAudioController>();
    final t = Theme.of(context).textTheme;
    final neural = kIsWeb || nativeTtsIsSupported();
    final engine = neural ? st.ttsEngine : TtsEngine.system;

    void setEngine(TtsEngine e) {
      st.ttsEngine = e;
      audio.setEngine(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (neural) ...[
          Text('Voz da leitura', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<TtsEngine>(
            segments: [
              for (final e in TtsEngine.values)
                if (e != TtsEngine.piper || !kIsWeb)
                  ButtonSegment(value: e, label: Text(e == TtsEngine.auto ? 'Auto' : e.label)),
            ],
            selected: {engine},
            onSelectionChanged: (v) => setEngine(v.first),
          ),
          const SizedBox(height: VsSpacing.sm),
        ],
        if (status.isBusy) ...[
          Text(status.label ?? 'Preparando voz…', style: t.bodySmall),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: status.progress),
          if (status.state == NeuralTtsState.downloading)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: audio.cancelVoiceDownload, child: const Text('Cancelar')),
            ),
        ],
        if (engine == TtsEngine.auto)
          Padding(
            padding: const EdgeInsets.only(bottom: VsSpacing.sm),
            child: Text(switch (audio.deviceEngine) {
              TtsEngine.kokoro =>
                'Usando a voz Kokoro (a de melhor qualidade). Muda sozinho se o aparelho ficar lento.',
              TtsEngine.piper => 'Usando a voz Piper: neste aparelho a Kokoro é mais lenta que a fala.',
              _ => 'Usando a voz do aparelho: aqui a Kokoro é mais lenta que a fala.',
            }, style: t.bodySmall),
          ),
        if (engine == TtsEngine.auto || engine == TtsEngine.kokoro) ...[
          SegmentedButton<String>(
            segments: [for (final v in KokoroVoice.all) ButtonSegment(value: v.id, label: Text(v.label))],
            selected: {st.kokoroVoice},
            onSelectionChanged: (v) {
              st.kokoroVoice = v.first;
              audio.setKokoroVoice(v.first);
            },
          ),
          if (kIsWeb) const _WebKokoroCacheTile() else _KokoroInfo(status),
          if (engine == TtsEngine.kokoro && status.kokoroSlow)
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Neste aparelho, a voz Kokoro é mais lenta que a fala'),
                subtitle: const Text('Por isso há pausas na leitura. O modo Automático usa uma voz mais rápida.'),
                trailing: TextButton(onPressed: () => setEngine(TtsEngine.auto), child: const Text('Usar Auto')),
              ),
            ),
        ],
        if (engine == TtsEngine.piper)
          for (final v in PiperVoice.all) _PiperVoiceTile(voice: v, status: status, selected: st.piperVoice == v.id),
        if (neural && engine != TtsEngine.system)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.record_voice_over_outlined),
              label: const Text('Ouvir exemplo'),
              onPressed: () =>
                  audio.playSingle(const ReadingSegment(id: 'exemplo-voz', title: 'Exemplo de voz', text: _sample)),
            ),
          ),
      ],
    );
  }
}

class _KokoroInfo extends StatelessWidget {
  const _KokoroInfo(this.status);

  final NeuralTtsStatus status;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Kokoro-82M · incluída no app'),
    subtitle: Text(
      status.cached
          ? 'Funciona sem internet · ${status.cacheSizeLabel} · Apache-2.0'
          : status.error != null
          ? 'Não foi possível preparar a voz; usando a voz do aparelho.'
          : 'Preparando a voz offline…',
    ),
  );
}

class _PiperVoiceTile extends StatelessWidget {
  const _PiperVoiceTile({required this.voice, required this.status, required this.selected});

  final PiperVoice voice;
  final NeuralTtsStatus status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final st = context.read<SettingsService>();
    final audio = context.read<ReadingAudioController>();
    final bytes = status.piperBytes[voice.id];
    final installed = bytes != null;
    final bundled = voice == PiperVoice.faber && status.faberBundled;

    void select() {
      st.piperVoice = voice.id;
      audio.setPiperVoice(voice.id);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected && installed ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: installed ? null : Theme.of(context).disabledColor,
      ),
      title: Text('${voice.label} · ${voice.description}'),
      subtitle: Text(
        bundled
            ? 'Incluída no app · ${voice.license}'
            : installed
            ? '${NeuralTtsStatus.sizeLabel(bytes)} neste aparelho · ${voice.license}'
            : '~21 MB para baixar · ${voice.license}',
      ),
      onTap: installed ? select : null,
      trailing: bundled
          ? null
          : installed
          ? TextButton(onPressed: () => audio.removePiperVoice(voice.id), child: const Text('Remover'))
          : OutlinedButton(
              onPressed: status.isBusy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (await audio.downloadPiperVoice(voice.id)) {
                        select();
                      } else if (audio.neuralTtsStatus.state == NeuralTtsState.error) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Não foi possível baixar a voz agora. Confira a internet.')),
                        );
                      }
                    },
              child: const Text('Baixar'),
            ),
    );
  }
}

/// Web: o modelo Kokoro fica no cache do navegador (baixado uma vez).
class _WebKokoroCacheTile extends StatelessWidget {
  const _WebKokoroCacheTile();

  @override
  Widget build(BuildContext context) {
    final status = context.select<ReadingAudioController, NeuralTtsStatus>((a) => a.neuralTtsStatus);
    final audio = context.read<ReadingAudioController>();
    if (status.isBusy) return const SizedBox.shrink();

    final subtitle = status.cached
        ? 'Salvo no navegador (${status.cacheSizeLabel})'
              '${status.deviceLabel.isNotEmpty ? ' · ${status.deviceLabel}' : ''}'
        : status.error != null
        ? 'Falha no download · tente novamente (~92 MB offline)'
        : '~92 MB · baixado uma única vez para uso offline';

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
                if (!await audio.preloadNeuralTts()) {
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

/// Exportar / importar um `.json` com favoritos, anotações, constância e
/// marcações da Bíblia — para trocar de aparelho ou limpar o navegador sem perder nada.
class _BackupTiles extends StatelessWidget {
  const _BackupTiles();

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = BackupRepository(context.read<AppServices>().database).export();
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(backup));
    final day = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'via-sacra-backup-$day.json',
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/json',
        dialogTitle: 'Salvar backup do Via Sacra',
      );
      if (saved != null) messenger.showSnackBar(const SnackBar(content: Text('Backup salvo.')));
    } catch (e) {
      debugPrint('Salvar backup: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível salvar o backup.')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = BackupRepository(context.read<AppServices>().database);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Escolha o backup do Via Sacra (.json)',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final json = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (json is! Map<String, dynamic>) throw BackupException('Este arquivo não é um backup do Via Sacra.');
      final r = await repo.import(json);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r.total == 0
                ? 'Nada novo: tudo deste backup já estava no aparelho.'
                : 'Backup restaurado: ${r.favorites} favorito(s), ${r.notes} anotação(ões), '
                      '${r.prayers} oração(ões) e ${r.bible} marcação(ões) da Bíblia.',
          ),
        ),
      );
    } on FormatException {
      messenger.showSnackBar(const SnackBar(content: Text('O arquivo não é um JSON válido.')));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Restaurar backup: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível restaurar este backup.')));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Exportar backup (.json)'),
        subtitle: const Text('Favoritos, anotações, constância e marcações da Bíblia'),
        onTap: () => _export(context),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.file_upload_outlined),
        title: const Text('Importar backup'),
        subtitle: const Text('Junta com o que já está no aparelho, sem apagar nada'),
        onTap: () => _import(context),
      ),
    ],
  );
}

Future<void> _confirmReset(BuildContext context, AppServices services) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Redefinir ajustes?'),
      content: const Text(
        'Tema, fonte, tamanho do texto, voz da leitura e lembretes voltam ao padrão.\n\n'
        'Suas Bíblias e catecismos importados, anotações, favoritos, marcações, constância, '
        'liturgias e vozes baixadas continuam no aparelho.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Redefinir')),
      ],
    ),
  );
  if (ok != true) return;
  final st = services.settings;
  final audio = services.audio;
  await st.resetToDefaults();
  // O player guarda a voz e a velocidade em uso: aplica os padrões, como na abertura do app.
  await audio.setSpeed(st.ttsSpeed);
  await audio.setKokoroVoice(st.kokoroVoice);
  await audio.setPiperVoice(st.piperVoice);
  await audio.setEngine(st.ttsEngine);
  await audio.setVoice(null, null);
  await services.notifications?.reschedule(st, services.liturgyRepository);
  messenger.showSnackBar(const SnackBar(content: Text('Ajustes redefinidos.')));
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
