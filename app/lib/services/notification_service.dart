import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/liturgical_calendar.dart';
import '../data/liturgy_repository.dart';
import 'settings_service.dart';
import 'web_reminders.dart';

/// Lembretes 100% locais (sem Firebase Cloud Messaging, sem servidor).
///
/// Como o conteúdo muda a cada dia (Evangelho, mistérios), agendamos
/// notificações individuais para os próximos [daysAhead] dias, e
/// reagendamos sempre que o app abre ou baixa a semana offline.
///
/// Na Web não há agendamento do sistema: a lista vai para o `sw.js` (ver `web_reminders_web.dart`),
/// que mostra cada lembrete com o app aberto ou quando o navegador acorda o PWA instalado.
class NotificationService {
  NotificationService(this._plugin);

  /// null na Web.
  final FlutterLocalNotificationsPlugin? _plugin;
  Timer? _webTimer;
  static const daysAhead = 14; // iOS permite até 64 pendentes
  static const _liturgyBaseId = 1000;
  static const _rosaryBaseId = 2000;

  static const _liturgyChannel = AndroidNotificationDetails(
    'liturgia_diaria',
    'Liturgia Diária',
    channelDescription: 'Lembrete matinal com a celebração e o Evangelho do dia',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_cross',
    styleInformation: BigTextStyleInformation(''),
  );
  static const _rosaryChannel = AndroidNotificationDetails(
    'santo_terco',
    'Santo Terço',
    channelDescription: 'Lembrete do Santo Terço com os mistérios do dia',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_cross',
  );
  static const _darwin = DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: false);

  static Future<NotificationService> create({void Function(String? payload)? onTap}) async {
    if (kIsWeb) {
      webListenReminderTaps((p) => onTap?.call(p));
      return NotificationService(null);
    }
    final plugin = FlutterLocalNotificationsPlugin();
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_cross'),
        // Nunca pedimos permissão automaticamente: só quando o usuário ativa.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    return NotificationService(plugin);
  }

  /// Payload do lembrete que abriu o app (null se aberto normalmente).
  Future<String?> launchPayload() async {
    if (kIsWeb) return webLaunchPayload();
    final details = await _plugin!.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true ? details?.notificationResponse?.payload : null;
  }

  /// Pede permissão ao sistema (Android 13+ / iOS). Retorna se foi concedida.
  Future<bool> requestPermission() async {
    if (kIsWeb) return webRequestNotificationPermission();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin!.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return _sendToWeb(const []);
    await _plugin!.cancelAll();
  }

  /// Reagenda tudo de acordo com as preferências atuais.
  Future<void> reschedule(SettingsService settings, LiturgyRepository liturgy) async {
    final items = upcoming(settings, liturgy, DateTime.now());
    if (kIsWeb) return _sendToWeb(items);
    await _plugin!.cancelAll();
    for (final r in items) {
      final liturgia = r.payload == 'liturgia';
      await _schedule(
        (liturgia ? _liturgyBaseId : _rosaryBaseId) + r.day,
        tz.TZDateTime.from(r.when, tz.local),
        r.title,
        r.body,
        liturgia ? _liturgyChannel : _rosaryChannel,
        r.payload,
      );
    }
  }

  /// Lembretes dos próximos [daysAhead] dias ainda por vir, na hora local escolhida.
  @visibleForTesting
  static List<({int day, DateTime when, String title, String body, String payload})> upcoming(
    SettingsService settings,
    LiturgyRepository? liturgy,
    DateTime now,
  ) {
    final items = <({int day, DateTime when, String title, String body, String payload})>[];
    if (!settings.notificationsEnabled) return items;
    for (var i = 0; i < daysAhead; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (settings.liturgyReminder) {
        final when = _at(day, settings.liturgyReminderTime);
        if (when.isAfter(now)) {
          final (title, body) = liturgyMessage(day, liturgy);
          items.add((day: i, when: when, title: title, body: body, payload: 'liturgia'));
        }
      }
      if (settings.rosaryReminder) {
        final when = _at(day, settings.rosaryReminderTime);
        if (when.isAfter(now)) {
          final (title, body) = rosaryMessage(day);
          items.add((day: i, when: when, title: title, body: body, payload: 'terco'));
        }
      }
    }
    return items..sort((a, b) => a.when.compareTo(b.when));
  }

  static DateTime _at(DateTime day, TimeOfDay t) => DateTime(day.year, day.month, day.day, t.hour, t.minute);

  /// Web: entrega a lista ao service worker e, com o app aberto, acorda-o na hora do próximo.
  void _sendToWeb(List<({int day, DateTime when, String title, String body, String payload})> items) {
    webSendReminders([
      for (final r in items)
        {
          'tag': '${r.payload}-${DateFormat('yyyy-MM-dd').format(r.when)}',
          'at': r.when.millisecondsSinceEpoch,
          'title': r.title,
          'body': r.body,
          'payload': r.payload,
        },
    ]);
    _armWebTimer(items.map((r) => r.when).toList());
  }

  void _armWebTimer(List<DateTime> times) {
    _webTimer?.cancel();
    if (times.isEmpty) return;
    final wait = times.first.difference(DateTime.now());
    _webTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      webCheckReminders();
      _armWebTimer(times.sublist(1));
    });
  }

  Future<void> _schedule(
    int id,
    tz.TZDateTime when,
    String title,
    String body,
    AndroidNotificationDetails android,
    String payload,
  ) async {
    try {
      await _plugin!.zonedSchedule(
        id: id,
        scheduledDate: when,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(android: android, iOS: _darwin),
        // Inexato: não exige a permissão SCHEDULE_EXACT_ALARM (amigável ao F-Droid/Play).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Falha ao agendar notificação $id: $e');
    }
  }

  /// Ex.: "Quinta-feira, 33ª Semana do Tempo Comum (Verde) — Evangelho de hoje: Lc 19,41-44"
  static (String, String) liturgyMessage(DateTime day, LiturgyRepository? repo) {
    final cached = repo?.cached(day);
    final d = cached?.day ?? LiturgicalCalendar.compute(day);
    final date = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(day);
    final gospel = cached?.gospel?.reference;
    final celebration = _shortCelebration(d);
    final body = StringBuffer('$celebration (${d.color.label})');
    body.write(gospel != null ? ' — Evangelho de hoje: $gospel' : ' — Toque para ler as leituras de hoje');
    return ('Liturgia Diária · ${_capitalize(date)}', body.toString());
  }

  /// Exemplo de hoje mostrado nas Configurações. Guardado por dia: o `build` da tela roda a cada
  /// ajuste (ex.: slider) e a mensagem consulta o banco e decodifica a liturgia.
  static String liturgyExample(LiturgyRepository repo) {
    final today = DateTime.now();
    final key = DateFormat('yyyy-MM-dd').format(today);
    if (_example?.$1 != key) _example = (key, liturgyMessage(today, repo).$2);
    return _example!.$2;
  }

  static (String, String)? _example;

  /// Ex.: "Hora do Santo Terço: Hoje contemplamos os Mistérios Luminosos"
  static (String, String) rosaryMessage(DateTime day) {
    final set = LiturgicalCalendar.mysteriesFor(day);
    return ('Hora do Santo Terço', 'Hoje contemplamos os ${set.label}');
  }

  static String _shortCelebration(LiturgicalDay d) {
    // "Quinta-feira da 33ª Semana do Tempo Comum" → "Quinta-feira, 33ª Semana do Tempo Comum"
    final m = RegExp(r'^(\S+(?:-feira)?) da (\d+ª Semana .+)$').firstMatch(d.celebration);
    return m != null ? '${m.group(1)}, ${m.group(2)}' : d.celebration;
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
