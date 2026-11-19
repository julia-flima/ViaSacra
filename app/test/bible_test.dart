import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/data/bible/bible_canon.dart';
import 'package:via_sacra/data/bible/bible_models.dart';
import 'package:via_sacra/data/bible/bible_module.dart';
import 'package:via_sacra/data/bible/bible_reference.dart';
import 'package:via_sacra/data/bible/bible_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/services/bible_import_service.dart';

void main() {
  group('Cânon católico', () {
    test('73 livros: 46 AT (com deuterocanônicos) + 27 NT', () {
      expect(bibleCanon, hasLength(73));
      expect(bibleCanon.where((b) => b.testament == Testament.at), hasLength(46));
      expect(
        bibleCanon.where((b) => b.deutero).map((b) => b.id),
        containsAll(['tb', 'jt', '1mc', '2mc', 'sb', 'eclo', 'br']),
      );
    });

    test('Paridade com assets/bible/canon.json (gerado por tool/bible/canon.py)', () {
      final json = jsonDecode(File('assets/bible/canon.json').readAsStringSync()) as List<dynamic>;
      expect(json.map((b) => (b as Map)['id']), bibleCanon.map((b) => b.id));
      expect(json.map((b) => (b as Map)['abreviacao']), bibleCanon.map((b) => b.abbreviation));
    });
  });

  group('BibleRef.parse', () {
    test('formatos brasileiros', () {
      final a = BibleRef.parse('Lc 19,41-44')!;
      expect((a.book.id, a.chapter, a.verseStart, a.verseEnd), ('lc', 19, 41, 44));
      final b = BibleRef.parse('1Cor 15,20-26.28')!;
      expect(b.book.id, '1cor');
      expect(b.extraVerses, [28]);
      expect(b.contains(28), isTrue);
      expect(b.contains(27), isFalse);
      final c = BibleRef.parse('Sl 121(122),1-2')!;
      expect((c.book.id, c.chapter, c.alternateChapter, c.chapterFor('hebraica')), ('sl', 121, 122, 122));
      expect(BibleRef.parse('Jo 3,16')!.book.id, 'jo');
      expect(BibleRef.parse('Jó 1,21')!.book.id, 'jb');
      expect(BibleRef.parse('João 3:16')!.verseStart, 16);
      expect(BibleRef.parse('Ap 5')!.hasVerses, isFalse);
      expect(BibleRef.parse('Eclo 3,2-6')!.book.id, 'eclo');
      expect(BibleRef.parse('graça de Deus'), isNull);
    });
  });

  group('BibleModule', () {
    test('valida e aceita capítulos em lista, pares e objeto', () {
      final m = BibleModule.parse({
        'formato': 'viasacra-biblia',
        'versao': 1,
        'id': 'teste',
        'nome': 'Teste',
        'abreviacao': 'TST',
        'idioma': 'pt-BR',
        'licenca': 'CC0',
        'livros': [
          {
            'id': 'jo',
            'capitulos': [
              ['a', 'b'],
              [
                [1, 'x'],
                [3, 'y'],
              ],
              {'2': 'q', '1': 'p'},
            ],
          },
        ],
      });
      expect(m.verseCount, 6);
      expect(m.books['jo']![1].map((v) => v.$1), [1, 3]);
      expect(m.books['jo']![2].first, (1, 'p'));
    });

    test('aceita metadado "sigla", licença opcional e capítulos como objeto', () {
      final m = BibleModule.parse({
        'formato': 'viasacra-biblia',
        'versao': 1,
        'id': 'matos_soares',
        'nome': 'Bíblia Sagrada — Matos Soares',
        'sigla': 'MS',
        'idioma': 'pt-BR',
        'livros': [
          {
            'id': 'gn',
            'capitulos': {
              '1': {'1': 'No princípio, criou Deus o céu e a terra.'},
            },
          },
        ],
      });
      expect(m.abbreviation, 'MS');
      expect(m.verseCount, 1);
      expect(m.books['gn']!.first.first, (1, 'No princípio, criou Deus o céu e a terra.'));
    });

    test('rejeita livro fora do cânon e formato errado', () {
      expect(() => BibleModule.parse({'formato': 'outro'}), throwsA(isA<BibleModuleException>()));
      expect(
        () => BibleModule.parse({
          'formato': 'viasacra-biblia',
          'versao': 1,
          'id': 'x1',
          'nome': 'X',
          'abreviacao': 'X',
          'idioma': 'pt',
          'licenca': 'CC0',
          'livros': [
            {'id': 'enoque', 'capitulos': []},
          ],
        }),
        throwsA(isA<BibleModuleException>()),
      );
    });
  });

  group('BibleRepository (Vulgata real)', () {
    late AppDatabase db;
    late BibleRepository repo;

    setUpAll(() async {
      db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
      repo = BibleRepository(db);
      final module = BibleModule.parse(
        jsonDecode(File('assets/bible/vulgata.json').readAsStringSync()) as Map<String, dynamic>,
      );
      await repo.install(module, bundled: true);
    });

    tearDownAll(() => db.close());

    test('instalação completa', () {
      final t = repo.translation('vulgata')!;
      expect(t.verseCount, 35807);
      expect(t.bundled, isTrue);
      expect(repo.books('vulgata'), hasLength(73));
      expect(repo.chapterCount('vulgata', 'sl'), 150);
      expect(repo.chapter('vulgata', 'gn', 1).first.text, startsWith('In principio creavit Deus'));
    });

    test('busca por referência e por palavra (FTS5, sem acentos)', () {
      final ref = repo.search('vulgata', 'Jo 3,16');
      expect(ref.single.text, contains('Sic enim Deus dilexit mundum'));
      final words = repo.search('vulgata', 'dilexit mundum');
      expect(words.map((v) => v.reference), contains('Jo 3,16'));
      expect(words.first.snippet, contains('«'));
      expect(repo.search('vulgata', 'creavit caelum').map((v) => v.reference), contains('Gn 1,1')); // texto: cælum
    });

    test('Salmos: numeração grega da Vulgata (Sl 22(23) = Dominus regit me)', () {
      final r = repo.resolve(BibleRef.parse('Sl 22(23),1')!, 'vulgata')!;
      expect(r.chapter, 22);
      expect(repo.chapter('vulgata', 'sl', r.chapter).first.text.toLowerCase(), contains('dominus regit me'));
    });

    test('marcações, favoritos e anotações independem da tradução', () {
      repo.saveAnnotation('jo', 3, 16, const VerseAnnotation(color: HighlightColor.ouro, favorite: true, note: 'Amor'));
      final a = repo.annotations('jo', 3)[16]!;
      expect((a.color, a.favorite, a.note), (HighlightColor.ouro, true, 'Amor'));
      expect(repo.marked(favoritesOnly: true).single.verse, 16);
      repo.saveAnnotation('jo', 3, 16, const VerseAnnotation());
      expect(repo.annotations('jo', 3), isEmpty);
    });

    test('última leitura ("Continuar lendo")', () {
      repo.savePosition(const ReadingPosition('vulgata', 'lc', 19, 41));
      final p = repo.lastPosition()!;
      expect((p.translationId, p.bookId, p.chapter, p.verse), ('vulgata', 'lc', 19, 41));
    });

    test('BibleImportService importa JSON modular, filtra FTS5 por tradução e permite excluir', () async {
      final importer = BibleImportService(repo);
      final payload = utf8.encode(
        jsonEncode({
          'formato': 'viasacra-biblia',
          'versao': 1,
          'id': 'figueiredo_amostra',
          'nome': 'Pe. Antônio Pereira de Figueiredo',
          'sigla': 'FIG',
          'idioma': 'pt-BR',
          'livros': [
            {
              'id': 'jo',
              'capitulos': {
                '3': {'16': 'Porque de tal maneira amou Deus ao mundo, que lhe deu seu Filho unigênito.'},
              },
            },
          ],
        }),
      );
      final res = await importer.importFromBytes(Uint8List.fromList(payload));
      expect((res.id, res.abbreviation, res.verseCount), ('figueiredo_amostra', 'FIG', 1));
      // Busca FTS5 isolada na tradução ativa ("maneira" existe só em português, não na Vulgata)
      expect(repo.search('figueiredo_amostra', 'maneira').single.reference, 'Jo 3,16');
      expect(repo.search('vulgata', 'maneira'), isEmpty);
      // Protege tradução embutida e permite excluir importada
      await expectLater(importer.deleteTranslation('vulgata'), throwsA(isA<BibleModuleException>()));
      await importer.deleteTranslation('figueiredo_amostra');
      expect(repo.translation('figueiredo_amostra'), isNull);
    });

    test('Bíblia Portuguesa Mundial (BPM) embutida: 73 livros, Salmos hebraicos e busca pt-BR', () async {
      final bpm = BibleModule.parse(
        jsonDecode(File('assets/bible/bpm.json').readAsStringSync()) as Map<String, dynamic>,
      );
      await repo.install(bpm, bundled: true);

      final t = repo.translation('bpm')!;
      expect(t.bundled, isTrue);
      expect(t.language, 'pt-BR');
      expect(t.psalmNumbering, 'hebraica');
      expect(repo.books('bpm'), hasLength(73));
      expect(repo.chapterCount('bpm', 'br'), 6);
      expect(repo.chapterCount('bpm', 'dn'), 14);
      expect(repo.translations().first.id, 'bpm');

      final sl = repo.resolve(BibleRef.parse('Sl 22(23),1')!, 'bpm')!;
      expect(sl.chapter, 23);
      expect(repo.chapter('bpm', 'sl', sl.chapter).first.text.toLowerCase(), contains('meu pastor'));
      expect(repo.search('bpm', 'amou o mundo').map((v) => v.reference), contains('Jo 3,16'));
    });
  });
}
