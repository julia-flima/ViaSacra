import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/features/liturgy/widgets/audio_player_bar.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';
import 'package:via_sacra/services/web_tts_types.dart';

void _mockAudioPlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async => <String, dynamic>{},
  );
  messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'), (call) async => null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockAudioPlugins);

  test('KokoroVoice, WebTtsStatus e SettingsService.kokoroVoice', () async {
    expect(KokoroVoice.byId(null).id, 'pf_dora');
    expect(KokoroVoice.byId('desconhecida').id, 'pf_dora');
    expect(KokoroVoice.byId('pm_alex').label, 'Alex');

    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    expect(settings.kokoroVoice, 'pf_dora');
    settings.kokoroVoice = 'pm_alex';
    expect(settings.kokoroVoice, 'pm_alex');
    settings.kokoroVoice = 'invalida';
    expect(settings.kokoroVoice, 'pf_dora');

    const busy = WebTtsStatus(
      state: WebTtsState.downloading,
      progress: 0.5,
      label: 'Baixando voz neural Kokoro (50%)…',
      device: 'webgpu',
      cached: true,
      cacheBytes: 94371840,
    );
    expect(busy.isBusy, isTrue);
    expect(busy.cacheSizeLabel, '90,0 MB');
    expect(busy.deviceLabel, 'WebGPU');
  });

  test('speechRateFor e supportsWebKokoro', () {
    expect(ReadingAudioHandler.speechRateFor(1.0, isWeb: true), 1.0);
    expect(ReadingAudioHandler.speechRateFor(1.25, isWeb: true), 1.25);
    expect(ReadingAudioHandler.speechRateFor(0.75, isWeb: true), 0.75);
    expect(ReadingAudioHandler.speechRateFor(1.0, isWeb: false), 0.5);
    expect(ReadingAudioHandler.speechRateFor(1.5, isWeb: false), 0.75);

    expect(ReadingAudioHandler.supportsWebKokoro('pt-BR'), isTrue);
    expect(ReadingAudioHandler.supportsWebKokoro('la'), isTrue);
    expect(ReadingAudioHandler.supportsWebKokoro('en-US'), isTrue);
    expect(ReadingAudioHandler.supportsWebKokoro('es'), isTrue);
    expect(ReadingAudioHandler.supportsWebKokoro('fr'), isFalse);
  });

  test('ReadingAudioHandler envia lookahead N+1 e trata fallback/retry e pause', () async {
    final webCalls = <({String text, String voice, String language, String? nextText})>[];
    final fallbackCalls = <String>[];
    var webOk = true;

    final handler = ReadingAudioHandler(
      useWebEngine: true,
      webSpeak: (text, speed, {voice = 'pf_dora', language = 'pt-BR', nextText}) async {
        webCalls.add((text: text, voice: voice, language: language, nextText: nextText));
        return webOk;
      },
      webStop: () {},
      fallbackSpeak: (text, language, speed) async {
        fallbackCalls.add(text);
      },
    );

    final longText = [
      '${List.filled(20, 'Primeira parte.').join(' ')} ',
      '${List.filled(20, 'Segunda parte.').join(' ')} ',
      'Terceira parte.',
    ].join();
    final chunks = splitForSpeech(longText, maxLen: 280);
    expect(chunks.length, greaterThanOrEqualTo(3));

    await handler.setKokoroVoice('pm_alex');
    await handler.load([ReadingSegment(id: 's1', title: 'Teste', text: longText)]);
    await handler.play();

    expect(webCalls, hasLength(chunks.length));
    expect(fallbackCalls, isEmpty);
    expect(webCalls.first.voice, 'pm_alex');
    expect(webCalls.first.nextText, chunks[1]);
    expect(webCalls[1].nextText, chunks[2]);
    expect(webCalls.last.nextText, isNull);

    // Falha no Web TTS cai para fallback nos blocos restantes desta leitura...
    webCalls.clear();
    fallbackCalls.clear();
    webOk = false;
    await handler.load([ReadingSegment(id: 's2', title: 'Fallback', text: longText)]);
    await handler.play();
    expect(webCalls, hasLength(1));
    expect(fallbackCalls, chunks);

    // ...mas volta a tentar o Web TTS no próximo play() quando recuperar.
    webCalls.clear();
    fallbackCalls.clear();
    webOk = true;
    await handler.play();
    expect(webCalls, hasLength(chunks.length));
    expect(fallbackCalls, isEmpty);

    // Pause durante webSpeak não aciona fallback.
    final pauseCompleter = Completer<bool>();
    final handlerPause = ReadingAudioHandler(
      useWebEngine: true,
      webSpeak: (text, speed, {voice = 'pf_dora', language = 'pt-BR', nextText}) => pauseCompleter.future,
      webStop: () {
        if (!pauseCompleter.isCompleted) pauseCompleter.complete(true);
      },
      fallbackSpeak: (text, language, speed) async => fallbackCalls.add(text),
    );
    await handlerPause.load([const ReadingSegment(id: 's3', title: 'Pause', text: 'Frase em pausa.')]);
    final playFuture = handlerPause.play();
    await Future<void>.delayed(Duration.zero);
    await handlerPause.pause();
    await playFuture;
    expect(fallbackCalls, isEmpty);
  });

  testWidgets('AudioPlayerBar mostra barra de progresso durante download do Kokoro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final audio = ReadingAudioController.local();
    audio.setWebTtsStatusForTest(
      const WebTtsStatus(state: WebTtsState.downloading, progress: 0.42, label: 'Baixando voz neural Kokoro (42%)…'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: MaterialApp(
          home: Scaffold(body: AudioPlayerBar(onPlayAll: () {}, recorded: false)),
        ),
      ),
    );

    expect(find.text('Baixando voz neural Kokoro (42%)…'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.42);
  });
}
