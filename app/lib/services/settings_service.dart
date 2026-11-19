import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

/// Preferências do usuário (locais, via SharedPreferences).
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async => SettingsService(await SharedPreferences.getInstance());

  T _get<T>(String k, T def) => (_prefs.get(k) as T?) ?? def;

  Future<void> _set(String k, Object v) async {
    switch (v) {
      case final bool b:
        await _prefs.setBool(k, b);
      case final int i:
        await _prefs.setInt(k, i);
      case final double d:
        await _prefs.setDouble(k, d);
      case final String s:
        await _prefs.setString(k, s);
    }
    notifyListeners();
  }

  // ---------- Onboarding ----------
  bool get onboardingDone => _get('onboarding_done', false);
  Future<void> setOnboardingDone() => _set('onboarding_done', true);

  // ---------- Tema e tipografia ----------
  ThemeMode get themeMode => ThemeMode.values[_get('theme_mode', ThemeMode.system.index)];
  set themeMode(ThemeMode m) => _set('theme_mode', m.index);

  ReadingFont get readingFont => ReadingFont.values[_get('reading_font', ReadingFont.serif.index)];
  set readingFont(ReadingFont f) => _set('reading_font', f.index);

  double get textScale => _get('text_scale', 1.0);
  set textScale(double v) => _set('text_scale', v.clamp(0.85, 1.6));

  double get lineHeight => _get('line_height', 1.6);
  set lineHeight(double v) => _set('line_height', v.clamp(1.3, 2.1));

  // ---------- Áudio / TTS ----------
  static const speeds = [0.75, 1.0, 1.25, 1.5];
  double get ttsSpeed => _get('tts_speed', 1.0);
  set ttsSpeed(double v) => _set('tts_speed', v);

  String? get ttsVoiceName => _prefs.getString('tts_voice_name');
  String? get ttsVoiceLocale => _prefs.getString('tts_voice_locale');
  Future<void> setTtsVoice(String? name, String? locale) async {
    if (name == null) {
      await _prefs.remove('tts_voice_name');
      await _prefs.remove('tts_voice_locale');
      notifyListeners();
      return;
    }
    await _prefs.setString('tts_voice_name', name);
    await _set('tts_voice_locale', locale ?? 'pt-BR');
  }

  /// Usar áudio narrado aberto quando disponível (senão, sempre TTS).
  bool get preferRecordedAudio => _get('prefer_recorded_audio', true);
  set preferRecordedAudio(bool v) => _set('prefer_recorded_audio', v);

  // ---------- Constância ----------
  bool get showStreak => _get('show_streak', true);
  set showStreak(bool v) => _set('show_streak', v);

  bool get haptics => _get('haptics', true);
  set haptics(bool v) => _set('haptics', v);

  // ---------- Orações ----------
  bool get preferLatin => _get('prefer_latin', false);
  set preferLatin(bool v) => _set('prefer_latin', v);

  // ---------- Notificações (todas desativadas por padrão) ----------
  bool get notificationsEnabled => _get('notif_enabled', false);
  set notificationsEnabled(bool v) => _set('notif_enabled', v);

  bool get liturgyReminder => _get('notif_liturgy', true);
  set liturgyReminder(bool v) => _set('notif_liturgy', v);

  TimeOfDay get liturgyReminderTime => _time('notif_liturgy_time', const TimeOfDay(hour: 7, minute: 0));
  set liturgyReminderTime(TimeOfDay t) => _set('notif_liturgy_time', t.hour * 60 + t.minute);

  bool get rosaryReminder => _get('notif_rosary', true);
  set rosaryReminder(bool v) => _set('notif_rosary', v);

  TimeOfDay get rosaryReminderTime => _time('notif_rosary_time', const TimeOfDay(hour: 18, minute: 0));
  set rosaryReminderTime(TimeOfDay t) => _set('notif_rosary_time', t.hour * 60 + t.minute);

  TimeOfDay _time(String k, TimeOfDay def) {
    final v = _prefs.getInt(k);
    return v == null ? def : TimeOfDay(hour: v ~/ 60, minute: v % 60);
  }
}
