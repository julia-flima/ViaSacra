// Referências bíblicas, tabela dos Salmos e validação de módulos (issue #10).
import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/data/bible/bible_module.dart';
import 'package:via_sacra/data/bible/bible_reference.dart';
import 'package:via_sacra/data/bible/psalm_numbering.dart';

void main() {
  group('BibleRef.parse', () {
    test('formas já suportadas continuam iguais', () {
      final a = BibleRef.parse('Lc 19,41-44')!;
      expect((a.book.id, a.chapter, a.verseStart, a.verseEnd, a.chapterEnd), ('lc', 19, 41, 44, null));
      final b = BibleRef.parse('1Cor 15,20-26.28')!;
      expect((b.verseStart, b.verseEnd), (20, 26));
      expect(b.extraVerses, [28]);
      final c = BibleRef.parse('Sl 121(122),1-2')!;
      expect((c.chapter, c.alternateChapter, c.chapterFor('hebraica')), (121, 122, 122));
      expect(BibleRef.parse('João 3:16')!.label, 'Jo 3,16');
      expect(BibleRef.parse('Mt 5')!.hasVerses, isFalse);
    });

    test('trecho entre capítulos', () {
      final r = BibleRef.parse('Is 52,13-53,12')!;
      expect((r.chapter, r.verseStart, r.chapterEnd, r.verseEnd, r.chapterSpan), (52, 13, 53, 12, 1));
      expect(r.label, 'Is 52,13-53,12');
      expect(r.containsAt(0, 12), isFalse);
      expect(r.containsAt(0, 15), isTrue); // 52,15
      expect(r.containsAt(1, 1), isTrue); // 53,1
      expect(r.containsAt(1, 12), isTrue);
      expect(r.containsAt(1, 13), isFalse);
      expect(r.containsAt(2, 1), isFalse);

      final paixao = BibleRef.parse('Mt 26,14-27,66')!;
      expect((paixao.chapter, paixao.chapterEnd, paixao.verseEnd), (26, 27, 66));
    });

    test('livros de um só capítulo', () {
      final fm = BibleRef.parse('Fm 9-10')!;
      expect((fm.book.id, fm.chapter, fm.verseStart, fm.verseEnd), ('fm', 1, 9, 10));
      final jd = BibleRef.parse('Jd 3')!;
      expect((jd.chapter, jd.verseStart), (1, 3));
      expect(BibleRef.parse('Fm 1,7')!.verseStart, 7); // forma explícita continua válida
    });

    test('trechos extras com intervalo (lecionário)', () {
      final r = BibleRef.parse('Lc 3,15-16.21-22')!;
      expect((r.verseStart, r.verseEnd), (15, 16));
      expect(r.extraVerses, [21, 22]);
      expect(r.contains(20), isFalse);
      expect(r.contains(22), isTrue);
    });

    test('intervalo de capítulos inteiros e entradas inválidas', () {
      final r = BibleRef.parse('Mt 5-7')!;
      expect((r.chapter, r.chapterEnd, r.hasVerses), (5, 7, false));
      expect(BibleRef.parse('Is 53,1-52,3'), isNull); // capítulo final antes do inicial
      expect(BibleRef.parse('xyz 3,16'), isNull);
    });
  });

  group('PsalmNumbering', () {
    test('grega → hebraica', () {
      final cases = {1: 1, 8: 8, 9: 9, 10: 11, 22: 23, 112: 113, 113: 114, 114: 116, 115: 116, 116: 117};
      cases.addAll({145: 146, 146: 147, 147: 147, 148: 148, 150: 150});
      cases.forEach((g, h) => expect(PsalmNumbering.greekToHebrew(g), h, reason: 'G$g'));
    });

    test('hebraica → grega', () {
      final cases = {1: 1, 9: 9, 10: 9, 11: 10, 23: 22, 113: 112, 114: 113, 115: 113, 116: 114, 117: 116};
      cases.addAll({146: 145, 147: 146, 148: 148});
      cases.forEach((h, g) => expect(PsalmNumbering.hebrewToGreek(h), g, reason: 'H$h'));
    });

    test('ida e volta preserva os salmos sem fusão/divisão', () {
      for (var g = 1; g <= 150; g++) {
        if ({9, 113, 114, 115, 146, 147}.contains(g)) continue;
        expect(PsalmNumbering.hebrewToGreek(PsalmNumbering.greekToHebrew(g)), g, reason: 'G$g');
      }
    });
  });

  group('BibleModule.parse', () {
    Map<String, dynamic> module(Object capitulos) => {
      'id': 'teste',
      'nome': 'Teste',
      'sigla': 'TT',
      'idioma': 'pt-BR',
      'livros': [
        {'id': 'jo', 'capitulos': capitulos},
      ],
    };

    test('aceita versículos únicos', () {
      expect(
        BibleModule.parse(
          module([
            [
              [1, 'a'],
              [2, 'b'],
            ],
          ]),
        ).verseCount,
        2,
      );
    });

    test('rejeita versículo repetido', () {
      expect(
        () => BibleModule.parse(
          module([
            [
              [1, 'a'],
              [1, 'b'],
            ],
          ]),
        ),
        throwsA(isA<BibleModuleException>().having((e) => e.message, 'message', contains('repetido'))),
      );
      expect(
        () => BibleModule.parse(
          module({
            '1': {'1': 'a', '01': 'b'},
          }),
        ),
        throwsA(isA<BibleModuleException>()),
      );
    });

    test('rejeita capítulo repetido e versículo zero', () {
      expect(
        () => BibleModule.parse(
          module({
            '1': ['a'],
            '01': ['b'],
          }),
        ),
        throwsA(isA<BibleModuleException>()),
      );
      expect(
        () => BibleModule.parse(
          module([
            [
              [0, 'a'],
            ],
          ]),
        ),
        throwsA(isA<BibleModuleException>()),
      );
    });
  });
}
