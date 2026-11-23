import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/liturgical_color.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/services/notification_service.dart';
import 'package:via_sacra/services/reading_audio_service.dart';

void main() {
  final json = jsonDecode(File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync()) as Map<String, dynamic>;

  test('DailyLiturgy.fromJson (saída real do scraper)', () {
    final l = DailyLiturgy.fromJson(json);
    expect(l.day.color, LiturgicalColor.verde);
    expect(l.readings.map((r) => r.kind), [ReadingKind.primeiraLeitura, ReadingKind.salmo, ReadingKind.evangelho]);
    expect(l.gospel!.reference, 'Lc 19,41-44');
    final psalm = l.reading(ReadingKind.salmo)!;
    expect(psalm.refrain, isNotNull);
    expect(psalm.stanzas, hasLength(2));
    expect(l.vaticanHomily, isNotNull);
    expect(l.patristic, isNotEmpty);
    expect(l.sources.map((s) => s.id), contains('cnbb'));
  });

  test('Cor da CNBB só vale em memória, festa ou solenidade', () {
    DailyLiturgy day(String data, String celebracao) => DailyLiturgy.fromJson({
      'data': data,
      'calendario': {'cor': 'vermelho', 'celebracao': celebracao},
    });
    // 23/11/2026: férias com São Clemente (facultativa) — a cor é a do tempo.
    expect(day('2026-11-23', '34ª Semana do Tempo Comum, Ano Par (II)').day.color, LiturgicalColor.verde);
    expect(
      day('2026-11-24', 'Santo André Dung-Lac e companheiros mártires, Memória').day.color,
      LiturgicalColor.vermelho,
    );
  });

  test('Fila "Ouvir Liturgia" usa TTS quando não há áudio aberto', () {
    final l = DailyLiturgy.fromJson(json);
    final q = buildLiturgyQueue(l);
    expect(q, hasLength(3));
    expect(q.every((s) => !s.isRecorded), isTrue);
    expect(q.last.text, contains('Palavra da Salvação'));
    expect(q[1].text, contains('Refrão'));
  });

  test('splitForSpeech respeita o limite e não perde texto', () {
    final text = List.generate(200, (i) => 'Frase número $i do Evangelho.').join(' ');
    final chunks = splitForSpeech(text, maxLen: 300);
    expect(chunks.every((c) => c.length <= 300), isTrue);
    expect(chunks.join(' ').replaceAll(' ', ''), text.replaceAll(' ', ''));
  });

  test('splitForSpeech começa com trecho curto e nunca corta palavras', () {
    const text =
        'Naquele tempo, quando Jesus se aproximou de Jerusalém e viu a cidade, começou a chorar sobre ela, dizendo: '
        'Se tu também compreendesses hoje o que te pode trazer a paz! Agora, porém, isso está escondido aos teus olhos. '
        'Pois dias virão em que os teus inimigos te cercarão de trincheiras, te rodearão e te apertarão de todos os lados.';
    final chunks = splitForSpeech(text, maxLen: 280, firstLen: 90);
    expect(chunks.first.length, lessThanOrEqualTo(90));
    expect(chunks[1].length, lessThanOrEqualTo(180));
    expect(chunks.every((c) => c.length <= 280), isTrue);
    final words = text.split(RegExp(r'\s+')).toSet();
    for (final c in chunks) {
      expect(c.split(' ').every(words.contains), isTrue, reason: 'trecho cortou palavra: "$c"');
    }
    expect(chunks.join(' '), text);
  });

  test('splitForSpeech divide frase longa sem pontuação entre palavras', () {
    final text = List.filled(120, 'palavra').join(' ');
    final chunks = splitForSpeech(text, maxLen: 100);
    expect(
      chunks.every((c) => c.length <= 100 && !c.startsWith(' ') && c.split(' ').every((w) => w == 'palavra')),
      isTrue,
    );
    expect(chunks.join(' '), text);
  });

  test('Mensagens das notificações', () {
    final (_, rosary) = NotificationService.rosaryMessage(DateTime(2026, 11, 19));
    expect(rosary, 'Hoje contemplamos os Mistérios Luminosos');
  });

  test('Dia sem conteúdo baixado usa o calendário local', () {
    final l = DailyLiturgy.calendarOnly(DateTime(2026, 11, 19));
    expect(l.hasReadings, isFalse);
    expect(l.fromNetwork, isFalse);
    expect(l.day.week, 33);
  });
}
