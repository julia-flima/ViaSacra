import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'app_navigation.dart';
import 'core/liturgical_calendar.dart';
import 'core/liturgical_color.dart';
import 'data/bible/bible_repository.dart';
import 'data/catechism_repository.dart';
import 'data/content_repository.dart';
import 'data/database.dart';
import 'data/liturgy_repository.dart';
import 'data/models/liturgy.dart';
import 'data/user_data_repository.dart';
import 'services/bible_service.dart';
import 'services/native_tts.dart';
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
    required this.bible,
    NavigationController? navigation,
  }) : navigation = navigation ?? NavigationController();

  final SettingsService settings;
  final AppDatabase database;
  final LiturgyRepository liturgyRepository;
  final ContentRepository content;
  final CatechismRepository catechism;
  final UserDataRepository userData;
  final ReadingAudioController audio;

  /// null na Web: lembretes agendados existem só no app nativo.
  final NotificationService? notifications;
  final BibleService bible;

  /// Aba atual; criada antes do app para que o toque num lembrete abra a aba certa.
  final NavigationController navigation;

  static Future<AppServices> bootstrap() async {
    // O que não depende entre si roda junto: o 1º quadro aparece mais cedo.
    final content = ContentRepository();
    final (settings, db, _, audio) = await (
      SettingsService.load(),
      AppDatabase.open(),
      content.load(),
      ReadingAudioController.create(),
    ).wait;
    final liturgy = LiturgyRepository(db)..prune();
    await audio.setSpeed(settings.ttsSpeed);
    await audio.setKokoroVoice(settings.kokoroVoice);
    await audio.setPiperVoice(settings.piperVoice);
    // O Piper só existe no celular; na Web a escolha volta para o Automático.
    await audio.setEngine(kIsWeb && settings.ttsEngine == TtsEngine.piper ? TtsEngine.auto : settings.ttsEngine);
    if (settings.ttsVoiceName != null) await audio.setVoice(settings.ttsVoiceName, settings.ttsVoiceLocale);
    if (kIsWeb) unawaited(audio.refreshNeuralTtsStatus());
    final navigation = NavigationController();
    NotificationService? notifications;
    if (!kIsWeb) {
      try {
        notifications = await NotificationService.create(onTap: navigation.openFromNotification);
        // Não precisa segurar a abertura do app.
        unawaited(notifications.reschedule(settings, liturgy).catchError((Object e) => debugPrint('Lembretes: $e')));
        // App aberto a frio pelo toque no lembrete.
        navigation.openFromNotification(await notifications.launchPayload());
      } catch (e) {
        debugPrint('Notificações indisponíveis: $e');
      }
    }
    // Semana offline automática (issue #51): pouco depois da abertura e ao voltar ao app.
    DateTime? lastWeek;
    Future<void> prefetchWeek() async {
      final now = DateTime.now();
      if (lastWeek != null && now.difference(lastWeek!) < const Duration(hours: 6)) return;
      lastWeek = now;
      if (await liturgy.prefetchWeek(now) > 0) await notifications?.reschedule(settings, liturgy);
    }

    void prefetchLater() => unawaited(
      Future<void>.delayed(const Duration(seconds: 5), prefetchWeek).catchError((Object e) {
        debugPrint('Semana offline: $e');
      }),
    );
    prefetchLater();
    AppLifecycleListener(onResume: prefetchLater);
    final bible = BibleService(BibleRepository(db));
    if (kIsWeb) {
      // Depois do primeiro quadro, sem disputar a abertura do app.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 3), bible.prefetchPortuguese).catchError((Object e) {
          debugPrint('Bíblia em segundo plano: $e');
        }),
      );
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
      bible: bible,
      navigation: navigation,
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

  LiturgicalColor get color => liturgy.day.color;
  LiturgicalDay get day => liturgy.day;

  bool get isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  Future<void> load(DateTime d, {bool force = false}) async {
    date = DateTime(d.year, d.month, d.day);
    loading = true;
    error = null; // não carrega o erro da data anterior
    final local = _repo.cached(date);
    liturgy = local ?? DailyLiturgy.calendarOnly(date);
    notifyListeners();
    final result = await _repo.load(date, forceRefresh: force, local: local);
    if (DateTime(d.year, d.month, d.day) != date) return; // usuário trocou de data
    liturgy = result.liturgy;
    origin = result.origin;
    error = result.error;
    loading = false;
    notifyListeners();
  }

  bool isCached(DateTime d) => _repo.isCached(d);
}
