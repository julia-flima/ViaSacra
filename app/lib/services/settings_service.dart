import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'neural_tts_types.dart';

/// Preferências do usuário (locais, via SharedPreferences).
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async => SettingsService(await SharedPreferences.getInstance());

  /// Valor salvo, ou [def] se ausente ou de outro tipo (ex.: preferência corrompida).
  T _get<T>(String k, T def) {
    final v = _prefs.get(k);
    if (v is T) return v;
    // Web (JSON no localStorage) pode devolver 1 em vez de 1.0.
    if (v is num && def is double) return v.toDouble() as T;
    return def;
  }

  /// Valor de enum salvo pelo índice; [def] se o índice for inválido.
  E _enum<E extends Enum>(String k, List<E> values, E def) {
    final i = _get<int>(k, def.index);
    return i >= 0 && i < values.length ? values[i] : def;
  }

  /// O SharedPreferences atualiza o cache em memória de forma síncrona, então
  /// os getters já refletem o novo valor e a UI é notificada imediatamente.
  /// A gravação em disco segue em segundo plano; quem precisar esperar por ela
  /// (ex.: antes de `NotificationService.reschedule`) pode usar [saved].
  Future<void> _set(String k, Object v) {
    final Future<bool> write = switch (v) {
      final bool b => _prefs.setBool(k, b),
      final int i => _prefs.setInt(k, i),
      final double d => _prefs.setDouble(k, d),
      final String s => _prefs.setString(k, s),
      _ => throw ArgumentError.value(v, k, 'tipo de preferência não suportado'),
    };
    _pending = Future.wait([_pending, write]);
    notifyListeners();
    return write;
  }

  Future<void> _pending = Future.value();

  /// Conclui quando todas as gravações pendentes chegaram ao disco.
  Future<void> get saved => _pending;

  // ---------- Onboarding ----------
  bool get onboardingDone => _get('onboarding_done', false);
  Future<void> setOnboardingDone() => _set('onboarding_done', true);

  // ---------- Tema e tipografia ----------
  ThemeMode get themeMode => _enum('theme_mode', ThemeMode.values, ThemeMode.system);
  set themeMode(ThemeMode m) => _set('theme_mode', m.index);

  ReadingFont get readingFont => _enum('reading_font', ReadingFont.values, ReadingFont.serif);
  set readingFont(ReadingFont f) => _set('reading_font', f.index);

  /// O "100%" dos Ajustes equivale a 85% do tamanho de texto do sistema: o tamanho padrão do
  /// Flutter ficava grande demais para leitura longa. A escala escolhida multiplica este valor.
  static const baseTextScale = 0.85;
  static const minTextScale = 0.85;
  static const maxTextScale = 1.9; // ≈ o máximo antigo (160% do tamanho do sistema)

  double get textScale {
    final saved = _prefs.get('text_scale_rel');
    if (saved is num) return saved.toDouble().clamp(minTextScale, maxTextScale);
    // Até a v1.6.0-beta.4 a escala era absoluta: converte para continuar no mesmo tamanho.
    final old = _prefs.get('text_scale');
    return old is num ? (old / baseTextScale).clamp(minTextScale, maxTextScale) : 1.0;
  }

  set textScale(double v) => _set('text_scale_rel', v.clamp(minTextScale, maxTextScale));

  double get lineHeight => _get('line_height', 1.6).clamp(1.3, 2.1);
  set lineHeight(double v) => _set('line_height', v.clamp(1.3, 2.1));

  // ---------- Leitura ----------
  /// Último capítulo aberto da Imitação de Cristo (ex.: "I-12").
  String? get imitationLastRef => _prefs.getString('imitacao_last');
  set imitationLastRef(String? ref) => ref == null ? _prefs.remove('imitacao_last') : _set('imitacao_last', ref);

  // ---------- Áudio / TTS ----------
  static const speeds = [0.75, 1.0, 1.25, 1.5];

  /// Ex.: 1.0 → "1×", 1.25 → "1,25×".
  static String speedLabel(double s) =>
      '${s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString().replaceAll('.', ',')}×';
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

  String get kokoroVoice => KokoroVoice.byId(_prefs.getString('kokoro_voice')).id;
  set kokoroVoice(String v) => _set('kokoro_voice', KokoroVoice.byId(v).id);

  TtsEngine get ttsEngine => TtsEngine.byName(_prefs.getString('tts_engine'));
  set ttsEngine(TtsEngine e) => _set('tts_engine', e.name);

  String get piperVoice => (PiperVoice.byId(_prefs.getString('piper_voice')) ?? PiperVoice.all.first).id;
  set piperVoice(String v) => _set('piper_voice', v);

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
    final v = _get<int?>(k, null);
    return v == null || v < 0 || v >= 24 * 60 ? def : TimeOfDay(hour: v ~/ 60, minute: v % 60);
  }
}
