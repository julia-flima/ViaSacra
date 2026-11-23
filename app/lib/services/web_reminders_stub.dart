// Fora da Web os lembretes usam o flutter_local_notifications (ver notification_service.dart).

Future<bool> webRequestNotificationPermission() async => false;

void webSendReminders(List<Map<String, Object>> reminders) {}

void webCheckReminders() {}

void webListenReminderTaps(void Function(String payload) onTap) {}

String? webLaunchPayload() => null;
