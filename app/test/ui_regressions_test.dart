// Regressões de UI da issue #7 (widgets isolados, sem o app completo).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/data/bible/bible_models.dart';
import 'package:via_sacra/features/bible/widgets/verse_actions_sheet.dart';
import 'package:via_sacra/services/settings_service.dart';
import 'package:via_sacra/widgets/reading_appearance_button.dart';

void main() {
  testWidgets('Aa abre sem erro com texto no máximo dos Ajustes (190%)', (tester) async {
    SharedPreferences.setMockInitialValues({'text_scale_rel': SettingsService.maxTextScale});
    final settings = await SettingsService.load();
    expect(settings.textScale, 1.9);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [ReadingAppearanceButton()])),
        ),
      ),
    );
    await tester.tap(find.byType(ReadingAppearanceButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('190%'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, greaterThanOrEqualTo(settings.textScale));
  });

  testWidgets('Ações do versículo cabem em 320dp com fonte a 160%', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showVerseActions(
                  context,
                  verse: const BibleVerse(bookId: 'jo', chapter: 3, verse: 16, text: 'Porque Deus amou o mundo…'),
                  translation: const BibleTranslation(
                    id: 'teste',
                    name: 'Tradução de teste',
                    abbreviation: 'TT',
                    language: 'pt',
                    license: 'Domínio Público',
                  ),
                  annotation: const VerseAnnotation(),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // sem RenderFlex overflow
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });
}
