// Padronização da leitura (issue #8): prévia da Homilia e compartilhar do Salmo.
import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/data/models/imitation.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/features/liturgy/widgets/homily_section.dart';
import 'package:via_sacra/features/liturgy/widgets/reading_card.dart';

void main() {
  group('homilyPreview', () {
    test('texto curto fica inteiro', () {
      expect(homilyPreview('Paz e bem.', max: 50), 'Paz e bem.');
    });

    test('corta no fim de uma palavra, sem pontuação solta', () {
      const text = 'Irmãos, o Senhor está perto; alegrai-vos sempre no Senhor.';
      final p = homilyPreview(text, max: 30); // o limite cai no meio de "alegrai-vos"
      expect(p, 'Irmãos, o Senhor está perto…');
      expect(text.startsWith(p.substring(0, p.length - 1)), isTrue);
    });

    test('palavra única maior que o limite ainda é cortada', () {
      expect(homilyPreview('a' * 20, max: 10), '${'a' * 10}…');
    });
  });

  test('Salmo compartilhado inclui o refrão', () {
    const psalm = Reading(
      kind: ReadingKind.salmo,
      reference: 'Sl 22(23)',
      refrain: 'O Senhor é o pastor que me conduz.',
      text: 'Pelos prados e campinas verdejantes ele me leva a descansar.',
    );
    final s = formatReadingForSharing(psalm);
    expect(s, startsWith('Salmo Responsorial — Sl 22(23)'));
    expect(s, contains('R. O Senhor é o pastor que me conduz.'));
    expect(s, contains('Pelos prados'));
  });

  test('Imitação: referência estável por capítulo', () {
    final work = ImitationOfChrist.fromJson({
      'livros': [
        {
          'numero': 'I',
          'titulo': 'Livro I',
          'capitulos': [
            {
              'numero': 1,
              'titulo': 'Da imitação de Cristo',
              'paragrafos': ['…'],
            },
          ],
        },
      ],
    });
    expect(work.chapters.single.ref, 'I-1');
    expect(work.chapters.single.label, 'Livro I · Cap. 1');
    expect(work.license, 'Domínio público');
  });
}
