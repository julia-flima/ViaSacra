// Lista de lembretes usada pelo celular e pela Web (issue #59).
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/services/notification_service.dart';
import 'package:via_sacra/services/settings_service.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('só horários futuros, em ordem, pelos próximos 14 dias', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await SettingsService.load();
    expect(NotificationService.upcoming(s, null, DateTime(2026, 11, 22, 12)), isEmpty); // desligados por padrão

    s
      ..notificationsEnabled = true
      ..liturgyReminderTime = const TimeOfDay(hour: 7, minute: 0)
      ..rosaryReminderTime = const TimeOfDay(hour: 18, minute: 30);
    final items = NotificationService.upcoming(s, null, DateTime(2026, 11, 22, 12)); // meio-dia
    // Hoje só o Terço (a Liturgia das 7h já passou); depois os dois por dia.
    expect(items.length, 1 + 2 * (NotificationService.daysAhead - 1));
    expect(items.first.payload, 'terco');
    expect(items.first.when, DateTime(2026, 11, 22, 18, 30));
    expect(items[1].payload, 'liturgia');
    expect(items[1].when, DateTime(2026, 11, 23, 7));
    expect(items[1].title, contains('Segunda-feira, 23 de novembro'));
    for (var i = 1; i < items.length; i++) {
      expect(items[i].when.isAfter(items[i - 1].when), isTrue);
    }

    s.rosaryReminder = false;
    expect(
      NotificationService.upcoming(s, null, DateTime(2026, 11, 22, 12)).every((r) => r.payload == 'liturgia'),
      isTrue,
    );
  });
}
