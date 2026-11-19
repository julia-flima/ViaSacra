import 'package:flutter/foundation.dart';

import 'core/liturgical_calendar.dart';
import 'core/liturgical_color.dart';
import 'data/catechism_repository.dart';
import 'data/content_repository.dart';
import 'data/database.dart';
import 'data/liturgy_repository.dart';
import 'data/models/liturgy.dart';
import 'data/user_data_repository.dart';
import 'services/notification_service.dart';
import 'services/reading_audio_service.dart';
import 'services/settings_service.dart';

/// Injeção de dependências simples (sem service locators globais).
class AppServices {
  AppServices({
    required this.settings,
    required this.database,
    required this.liturgyRepository,
    required this.content,
    required this.catechism,
    required this.userData,
    required this.audio,
    required this.notifications,
  });

  final SettingsService settings;
  final AppDatabase database;
  final LiturgyRepository liturgyRepository;
  final ContentRepository content;
  final CatechismRepository catechism;
  final UserDataRepository userData;
  final ReadingAudioController audio;
  final NotificationService? notifications;

  static Future<AppServices> bootstrap() async {
    final settings = await SettingsService.load();
    final db = await AppDatabase.open();
    final content = ContentRepository();
    await content.load();
    final liturgy = LiturgyRepository(db)..prune();
    final audio = await ReadingAudioController.create();
    await audio.setSpeed(settings.ttsSpeed);
    if (settings.ttsVoiceName != null) await audio.setVoice(settings.ttsVoiceName, settings.ttsVoiceLocale);
    NotificationService? notifications;
    try {
      notifications = await NotificationService.create();
      await notifications.reschedule(settings, liturgy);
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
    return AppServices(
      settings: settings,
      database: db,
      liturgyRepository: liturgy,
      content: content,
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: audio,
      notifications: notifications,
    );
  }
}

/// Estado da aba Liturgia (data selecionada + conteúdo carregado). A cor
/// litúrgica do dia exibido define o acento do tema do app inteiro.
class LiturgyController extends ChangeNotifier {
  LiturgyController(this._repo) {
    load(DateTime.now());
  }

  final LiturgyRepository _repo;

  DateTime date = DateTime.now();
  DailyLiturgy liturgy = DailyLiturgy.calendarOnly(DateTime.now());
  LiturgyOrigin origin = LiturgyOrigin.calendarOnly;
  bool loading = true;
  String? error;
  double? downloadProgress;

  LiturgicalColor get color => liturgy.day.color;
  LiturgicalDay get day => liturgy.day;

  bool get isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  Future<void> load(DateTime d, {bool force = false}) async {
    date = DateTime(d.year, d.month, d.day);
    loading = true;
    liturgy = _repo.cached(date) ?? DailyLiturgy.calendarOnly(date);
    notifyListeners();
    final result = await _repo.load(date, forceRefresh: force);
    if (DateTime(d.year, d.month, d.day) != date) return; // usuário trocou de data
    liturgy = result.liturgy;
    origin = result.origin;
    error = result.error;
    loading = false;
    notifyListeners();
  }

  Future<int> downloadWeek() async {
    downloadProgress = 0;
    notifyListeners();
    final ok = await _repo.downloadWeek(
      DateTime.now(),
      onProgress: (done, total) {
        downloadProgress = done / total;
        notifyListeners();
      },
    );
    downloadProgress = null;
    notifyListeners();
    return ok;
  }

  bool isCached(DateTime d) => _repo.isCached(d);
}
