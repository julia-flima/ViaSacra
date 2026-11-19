import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/features/liturgy/widgets/reading_card.dart';

void main() {
  test('LiturgyAudio.fromJson lê salmo_video_id, salmo_video_titulo e crédito', () {
    final audio = LiturgyAudio.fromJson({
      'salmo_video_id': 'NHUXSd2fdhI',
      'salmo_video_titulo': 'Salmo 149 - 19/11/2026',
      'creditos': [
        {
          'campo': 'salmo_video_id',
          'interprete': 'Salmos para rezar...',
          'canal': 'Salmos para rezar...',
          'url_fonte': 'https://www.youtube.com/watch?v=NHUXSd2fdhI',
          'licenca': 'YouTube Embed Oficial (Termos de Serviço)',
        },
      ],
    });
    expect(audio.psalmVideoId, 'NHUXSd2fdhI');
    expect(audio.psalmVideoTitle, 'Salmo 149 - 19/11/2026');
    expect(audio.creditFor('salmo_video_id')?.channel, 'Salmos para rezar...');
  });

  testWidgets('PsalmCard exibe Ouvir Salmo Cantado quando há videoId e Buscar quando não há', (tester) async {
    const psalm = Reading(
      kind: ReadingKind.salmo,
      reference: 'Sl 149,1-2',
      refrain: 'Fizestes de nós, para Deus, sacerdotes e povo de reis.',
      text: 'Cantai ao Senhor Deus um canto novo.',
      source: 'CNBB',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PsalmCard(
              psalm: psalm,
              audio: const LiturgyAudio(psalmVideoId: 'NHUXSd2fdhI'),
              onListenFromHere: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ouvir Salmo Cantado'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PsalmCard(psalm: psalm, audio: const LiturgyAudio(), onListenFromHere: () {}),
          ),
        ),
      ),
    );
    expect(find.text('Buscar Salmo Cantado'), findsOneWidget);
  });
}
