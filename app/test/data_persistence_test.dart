// Dados locais (issue #9): cache offline da Liturgia, anotações e SettingsService.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/core/theme.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/liturgy_repository.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:via_sacra/services/settings_service.dart';

Future<AppDatabase> _db() => AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiturgyRepository', () {
    final fixture = utf8.encode(File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync());
    final day = DateTime(2026, 11, 19);
    late int requests;
    late bool online;
    late LiturgyRepository repo;

    setUp(() async {
      requests = 0;
      online = true;
      final client = MockClient((_) async {
        requests++;
        if (!online) throw const SocketException('sem rede');
        return http.Response.bytes(fixture, 200);
      });
      repo = LiturgyRepository(await _db(), client: client);
    });

    test('data passada completa não é buscada de novo na rede', () async {
      final first = await repo.load(day, now: DateTime(2026, 11, 20));
      expect(first.origin, LiturgyOrigin.network);
      expect(LiturgyRepository.isComplete(first.liturgy), isTrue);

      // Mesmo muito depois do intervalo de atualização.
      final again = await repo.load(day, now: DateTime(2027, 1, 1));
      expect(again.origin, LiturgyOrigin.cache);
      expect(again.error, isNull);
      expect(requests, 1);
    });

    test('hoje é atualizado após o intervalo, mas offline usa o cache em silêncio', () async {
      // O fetched_at usa o relógio real. Usa amanhã (data futura, também atualizável):
      // com "agora + 1 h" ela nunca vira data passada, mesmo perto da meia-noite
      // (o CI chegou a falhar às 23:30 UTC quando a data era "hoje").
      final today = DateTime.now().add(const Duration(days: 1));
      await repo.load(today);
      expect(requests, 1);

      // Hoje, dentro do intervalo: cache.
      expect((await repo.load(today, now: DateTime.now())).origin, LiturgyOrigin.cache);
      expect(requests, 1);

      // Hoje, intervalo vencido e sem rede: cache completo, sem aviso de erro.
      online = false;
      final offline = await repo.load(today, now: DateTime.now().add(const Duration(hours: 1)));
      expect(requests, greaterThan(1)); // tentou a rede (um pedido por endpoint)
      expect(offline.origin, LiturgyOrigin.cache);
      expect(offline.error, isNull);

      // Atualização pedida pelo usuário sem rede: avisa o erro, mas mantém o cache.
      final forced = await repo.load(today, forceRefresh: true);
      expect(forced.origin, LiturgyOrigin.cache);
      expect(forced.error, isNotNull);
    });

    test('semana automática baixa só o que falta e para no primeiro dia que falhar', () async {
      final from = DateTime(2026, 11, 19);
      expect(await repo.prefetchWeek(from), 7);
      expect(requests, 7);
      for (var i = 0; i < 7; i++) {
        expect(repo.isCached(DateTime(2026, 11, 19 + i)), isTrue);
      }

      // Dias já completos não são buscados de novo; só o novo 7º dia.
      expect(await repo.prefetchWeek(from.add(const Duration(days: 1))), 1);
      expect(requests, 8);

      // Sem rede: tenta o primeiro dia que falta e desiste (um pedido por endpoint).
      online = false;
      final before = requests;
      expect(await repo.prefetchWeek(DateTime(2026, 12, 1)), 0);
      expect(repo.isCached(DateTime(2026, 12, 2)), isFalse);
      expect(requests - before, lessThanOrEqualTo(3));
    });

    test('sem cache e sem rede: só o calendário, com erro', () async {
      online = false;
      final r = await repo.load(day, now: DateTime(2026, 11, 20));
      expect(r.origin, LiturgyOrigin.calendarOnly);
      expect(r.error, isNotNull);
    });
  });

  group('Anotações', () {
    test('editar preserva created_at; apagar o texto remove a anotação', () async {
      final user = UserDataRepository(await _db());
      user.saveNote('lectio', 'x', '  Primeira  ');
      expect(user.note('lectio', 'x'), 'Primeira');
      final created = user.noteCreatedAt('lectio', 'x');

      await Future<void>.delayed(const Duration(milliseconds: 5));
      user.saveNote('lectio', 'x', 'Segunda');
      expect(user.note('lectio', 'x'), 'Segunda');
      expect(user.noteCreatedAt('lectio', 'x'), created);

      user.saveNote('lectio', 'x', '   ');
      expect(user.note('lectio', 'x'), isNull);
    });

    test('banco em memória ativa foreign_keys', () async {
      final db = await _db();
      expect(db.db.select('PRAGMA foreign_keys').first.columnAt(0), 1);
    });
  });

  group('SettingsService', () {
    test('setter notifica imediatamente e o getter já reflete o valor', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsService.load();
      var notified = 0;
      s.addListener(() => notified++);

      s.haptics = false;
      expect(notified, 1); // antes de qualquer await
      expect(s.haptics, isFalse);
      await s.saved;
      expect((await SharedPreferences.getInstance()).getBool('haptics'), isFalse);
    });

    test('escala de texto: 85% antigo vira o novo 100%; quem escolheu um tamanho continua nele', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await SettingsService.load()).textScale, 1.0); // padrão novo = 85% do sistema
      SharedPreferences.setMockInitialValues({'text_scale': 0.85});
      expect((await SettingsService.load()).textScale, closeTo(1.0, 1e-9));
      SharedPreferences.setMockInitialValues({'text_scale': 1.0}); // tinha escolhido o tamanho do sistema
      final s = await SettingsService.load();
      expect(s.textScale * SettingsService.baseTextScale, closeTo(1.0, 1e-9));
      s.textScale = 1.2;
      expect((await SettingsService.load()).textScale, 1.2);
    });

    test('valores corrompidos ou fora do intervalo caem no padrão', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 99,
        'reading_font': -1,
        'haptics': 'sim',
        'text_scale': 3.0,
        'line_height': 1, // int vindo do localStorage na Web
        'notif_liturgy_time': 99999,
      });
      final s = await SettingsService.load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.readingFont, ReadingFont.serif);
      expect(s.haptics, isTrue);
      expect(s.textScale, SettingsService.maxTextScale);
      expect(s.lineHeight, 1.3);
      expect(s.liturgyReminderTime, const TimeOfDay(hour: 7, minute: 0));
    });
  });
}
