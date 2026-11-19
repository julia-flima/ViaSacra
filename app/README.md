# Via Sacra — app Flutter

Código do aplicativo (Android + iOS). Veja o [README principal](../README.md) para instalação,
e [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) para a estrutura.

```bash
flutter pub get && flutter run
```

```bash
flutter analyze && flutter test
```

Gerar capturas de tela (fastlane):

```bash
flutter test test/screens_test.dart --update-goldens --dart-define=FONT_DIR=/usr/share/fonts/truetype
```
