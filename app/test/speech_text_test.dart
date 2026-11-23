// Texto falado pelas vozes (issue #55): sem marcas de leitura e com referências por extenso.
import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/services/speech_text.dart';

void main() {
  test('referências bíblicas por extenso', () {
    final cases = {
      'Salmos 4,7-9': 'Salmo 4, versículos 7 a 9',
      'Lc 19,41-44': 'Lucas 19, versículos 41 a 44',
      'Jo 3,16': 'João 3, versículo 16',
      'Sl 22(23),1-2a.2b-3.5-6': 'Salmo 22, versículos 1 a 2, 2 a 3 e 5 a 6',
      'Sl 149,1-2.3-4.5-6a e 9b': 'Salmo 149, versículos 1 a 2, 3 a 4, 5 a 6 e 9',
      '1Cor 15,20-26.28': 'Primeira Coríntios 15, versículos 20 a 26 e 28',
      '1 Rs 19,4': 'Primeiro Reis 19, versículo 4',
      '1Mc 2,15': 'Primeiro Macabeus 2, versículo 15',
      'Mc 1,15': 'Marcos 1, versículo 15',
      'Is 52,13-53,12': 'Isaías 52, versículo 13 ao capítulo 53, versículo 12',
      'Ap 20,1-4.11-21,2': 'Apocalipse 20, versículos 1 a 4 e 11 ao capítulo 21, versículo 2',
      'Leitura da Profecia de Ezequiel 34,11-12.15-17':
          'Leitura da Profecia de Ezequiel 34, versículos 11 a 12 e 15 a 17',
      '(cf. Jo 14,6)': '(conforme João 14, versículo 6)',
    };
    cases.forEach((input, spoken) => expect(speakableText(input), spoken, reason: input));
  });

  test('sem falso positivo em texto comum', () {
    for (final s in ['No ano 2026, 1 de janeiro', 'na 3,5 do texto', 'Mt 5', 'Apocalipse']) {
      expect(speakableText(s), s);
    }
  });

  test('tira marcas de leitura e expande abreviações', () {
    expect(
      speakableText('Pelos prados e campinas verdejantes *\nele me leva a descansar. R.'),
      'Pelos prados e campinas verdejantes\nele me leva a descansar.',
    );
    expect(speakableText('Aclamai o Senhor, ó terra inteira, †\nservi'), 'Aclamai o Senhor, ó terra inteira,\nservi');
    expect(
      speakableText('V. Nós vos adoramos, ó Cristo.\nR. Porque pela vossa santa cruz'),
      'Nós vos adoramos, ó Cristo.\nPorque pela vossa santa cruz',
    );
    expect(
      speakableText('S. José e N. Sra. com Sto. Antônio e Sta. Teresa'),
      'São José e Nossa Senhora com Santo Antônio e Santa Teresa',
    );
  });
}
