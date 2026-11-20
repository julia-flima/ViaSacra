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

/// Lembretes 100% locais (sem Firebase Cloud Messaging, sem servidor).
///
/// Como o conteúdo muda a cada dia (Evangelho, mistérios), agendamos
/// notificações individuais para os próximos [daysAhead] dias, e
/// reagendamos sempre que o app abre ou baixa a semana offline.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
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
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true ? details?.notificationResponse?.payload : null;
  }

  /// Pede permissão ao sistema (Android 13+ / iOS). Retorna se foi concedida.
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Reagenda tudo de acordo com as preferências atuais.
  Future<void> reschedule(SettingsService settings, LiturgyRepository liturgy) async {
    await _plugin.cancelAll();
    if (!settings.notificationsEnabled) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < daysAhead; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (settings.liturgyReminder) {
        final when = _at(day, settings.liturgyReminderTime);
        if (when.isAfter(now)) {
          final (title, body) = liturgyMessage(day, liturgy);
          await _schedule(_liturgyBaseId + i, when, title, body, _liturgyChannel, 'liturgia');
        }
      }
      if (settings.rosaryReminder) {
        final when = _at(day, settings.rosaryReminderTime);
        if (when.isAfter(now)) {
          final (title, body) = rosaryMessage(day);
          await _schedule(_rosaryBaseId + i, when, title, body, _rosaryChannel, 'terco');
        }
      }
    }
  }

  tz.TZDateTime _at(DateTime day, TimeOfDay t) =>
      tz.TZDateTime(tz.local, day.year, day.month, day.day, t.hour, t.minute);

  Future<void> _schedule(
    int id,
    tz.TZDateTime when,
    String title,
    String body,
    AndroidNotificationDetails android,
    String payload,
  ) async {
    try {
      await _plugin.zonedSchedule(
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
