import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Lembretes na Web: o app calcula os próximos dias e entrega ao `sw.js`, que mostra cada
/// notificação na hora (app aberto, mesmo em segundo plano) ou quando o navegador acorda o
/// PWA instalado (Periodic Background Sync do Chrome, horário aproximado). Sem servidor.

Future<bool> webRequestNotificationPermission() async {
  try {
    if (web.Notification.permission == 'granted') return true;
    return (await web.Notification.requestPermission().toDart).toDart == 'granted';
  } catch (_) {
    return false; // navegador sem notificações
  }
}

void _post(Map<String, Object> msg) {
  try {
    web.window.navigator.serviceWorker.ready.toDart.then((reg) => reg.active?.postMessage(msg.jsify()));
  } catch (_) {}
}

/// Substitui os lembretes guardados no service worker ([] apaga todos).
void webSendReminders(List<Map<String, Object>> reminders) => _post({'tipo': 'lembretes', 'itens': reminders});

/// Pede ao service worker que mostre os lembretes cuja hora chegou.
void webCheckReminders() => _post({'tipo': 'verificar'});

/// Toque numa notificação com o app já aberto (o `sw.js` avisa a aba).
void webListenReminderTaps(void Function(String payload) onTap) {
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      (web.MessageEvent e) {
        final data = e.data.dartify();
        if (data is Map && data['tipo'] == 'abrir' && data['payload'] is String) onTap(data['payload'] as String);
      }.toJS,
    );
  } catch (_) {}
}

/// Toque numa notificação com o app fechado: o `sw.js` abre "./?abrir=liturgia".
String? webLaunchPayload() => Uri.base.queryParameters['abrir'];
