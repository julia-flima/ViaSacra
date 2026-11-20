import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/features/liturgy/widgets/audio_player_bar.dart';
import 'package:via_sacra/services/native_tts_io.dart';
import 'package:via_sacra/services/neural_tts_types.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';

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

  test('KokoroVoice, NeuralTtsStatus e SettingsService.kokoroVoice', () async {
    expect(KokoroVoice.dora.sid, 42);
    expect(KokoroVoice.alex.sid, 43);
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

    const busy = NeuralTtsStatus(
      state: NeuralTtsState.downloading,
      progress: 0.5,
      label: 'Baixando voz neural Kokoro (50%)…',
      device: 'webgpu',
      cached: true,
      cacheBytes: 94371840,
    );
    expect(busy.isBusy, isTrue);
    expect(busy.cacheSizeLabel, '90,0 MB');
    expect(busy.deviceLabel, 'WebGPU');

    const nativeStatus = NeuralTtsStatus(state: NeuralTtsState.ready, device: 'onnx-cpu', cached: true);
    expect(nativeStatus.isBusy, isFalse);
    expect(nativeStatus.deviceLabel, 'ONNX CPU');
  });

  test('resolveKokoroSpeaker mapeia idiomas e sids exatos v1.0', () {
    final ptF = resolveKokoroSpeaker(voiceId: 'pf_dora', language: 'pt-BR');
    expect((ptF.voiceId, ptF.sid, ptF.espeakLang), ('pf_dora', 42, 'pt-br'));
    final ptM = resolveKokoroSpeaker(voiceId: 'pm_alex', language: 'pt-BR');
    expect((ptM.voiceId, ptM.sid, ptM.espeakLang), ('pm_alex', 43, 'pt-br'));

    final enF = resolveKokoroSpeaker(voiceId: 'pf_dora', language: 'en-US');
    expect((enF.voiceId, enF.sid, enF.espeakLang), ('af_heart', 3, 'en-us'));
    final enM = resolveKokoroSpeaker(voiceId: 'pm_alex', language: 'en-US');
    expect((enM.voiceId, enM.sid, enM.espeakLang), ('am_michael', 16, 'en-us'));

    final laF = resolveKokoroSpeaker(voiceId: 'pf_dora', language: 'la');
    expect((laF.voiceId, laF.sid, laF.espeakLang), ('if_sara', 35, 'it'));
    final itM = resolveKokoroSpeaker(voiceId: 'pm_alex', language: 'it-IT');
    expect((itM.voiceId, itM.sid, itM.espeakLang), ('im_nicola', 36, 'it'));

    final esF = resolveKokoroSpeaker(voiceId: 'pf_dora', language: 'es');
    expect((esF.voiceId, esF.sid, esF.espeakLang), ('ef_dora', 28, 'es'));
    final esM = resolveKokoroSpeaker(voiceId: 'pm_alex', language: 'es-ES');
    expect((esM.voiceId, esM.sid, esM.espeakLang), ('em_alex', 29, 'es'));
  });

  test('normalizeTextForKokoro normaliza sinais tipográficos e símbolos', () {
    expect(
      normalizeTextForKokoro('✝ «Jesus» — § 123 • ‘Amém’\n  Aleluia!'),
      '"Jesus" , parágrafo 123 \'Amém\' Aleluia!',
    );
  });

  test('speechRateFor e supportsKokoro', () {
    expect(ReadingAudioHandler.speechRateFor(1.0, isWeb: true), 1.0);
    expect(ReadingAudioHandler.speechRateFor(1.25, isWeb: true), 1.25);
    expect(ReadingAudioHandler.speechRateFor(0.75, isWeb: true), 0.75);
    expect(ReadingAudioHandler.speechRateFor(1.0, isWeb: false), 0.5);
    expect(ReadingAudioHandler.speechRateFor(1.5, isWeb: false), 0.75);

    expect(ReadingAudioHandler.supportsKokoro('pt-BR'), isTrue);
    expect(ReadingAudioHandler.supportsKokoro('la'), isTrue);
    expect(ReadingAudioHandler.supportsKokoro('en-US'), isTrue);
    expect(ReadingAudioHandler.supportsKokoro('es'), isTrue);
    expect(ReadingAudioHandler.supportsKokoro('fr'), isFalse);
  });

  test('KokoroModelStore valida arquivos, baixa/extrai .tar.bz2 e limpa cache', () async {
    final tempDir = await Directory.systemTemp.createTemp('kokoro_store_test_');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    final store = KokoroModelStore(tempDir);
    expect(store.isReady, isFalse);
    expect(store.resolveModelFiles(), isNull);
    expect(store.computeCacheBytes(), 0);

    // Constrói um .tar.bz2 mínimo em memória com a estrutura esperada do tarball.
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('${KokoroModelStore.extractSubdir}/model.int8.onnx', List<int>.filled(16, 1)))
      ..addFile(ArchiveFile.bytes('${KokoroModelStore.extractSubdir}/voices.bin', List<int>.filled(8, 2)))
      ..addFile(ArchiveFile.bytes('${KokoroModelStore.extractSubdir}/tokens.txt', 'a 1\n'.codeUnits))
      ..addFile(ArchiveFile.bytes('${KokoroModelStore.extractSubdir}/espeak-ng-data/pt_dict', [1, 2, 3, 4]));
    final tarBytes = TarEncoder().encode(archive);
    final tarBz2 = BZip2Encoder().encode(tarBytes);

    final mockClient = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(Stream.value(tarBz2), 200, contentLength: tarBz2.length),
    );

    final statuses = <(double?, String)>[];
    final files = await store.ensureDownloaded(
      onProgress: (p, l) => statuses.add((p, l)),
      client: mockClient,
      url: 'https://example.com/kokoro.tar.bz2',
      minArchiveBytes: 1,
    );

    expect(files.modelPath, endsWith('model.int8.onnx'));
    expect(files.voicesPath, endsWith('voices.bin'));
    expect(files.tokensPath, endsWith('tokens.txt'));
    expect(files.espeakDataDir, endsWith('espeak-ng-data'));
    expect(store.isReady, isTrue);
    expect(store.computeCacheBytes(), greaterThan(0));
    expect(statuses.any((s) => s.$2.contains('Extraindo')), isTrue);

    // Sem sentinela .ready-v1 o modelo não é considerado pronto.
    await store.readySentinel.delete();
    expect(store.isReady, isFalse);

    // Fallback para model.onnx quando model.int8.onnx não existir.
    await File(files.modelPath).rename('${Directory(files.modelPath).parent.path}/model.onnx');
    final fullModel = store.resolveModelFiles();
    expect(fullModel?.modelPath, endsWith('model.onnx'));

    // Ignora arquivo temporário .tar.bz2.part no cálculo de bytes em cache.
    await File('${tempDir.path}/model.tar.bz2.part').writeAsBytes(List<int>.filled(100, 9));
    final withoutPart = store.computeCacheBytes();
    await File('${tempDir.path}/model.tar.bz2.part').delete();
    expect(store.computeCacheBytes(), withoutPart);

    await store.clearCache();
    expect(store.isReady, isFalse);
    expect(store.computeCacheBytes(), 0);
  });

  test('ReadingAudioHandler envia lookahead N+1, troca voz ao vivo e trata fallback/pause', () async {
    final neuralCalls = <({String text, String voice, String language, String? nextText})>[];
    final fallbackCalls = <String>[];
    var neuralOk = true;

    final handler = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: (text, speed, {voice = 'pf_dora', language = 'pt-BR', nextText}) async {
        neuralCalls.add((text: text, voice: voice, language: language, nextText: nextText));
        return neuralOk;
      },
      neuralStop: () {},
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

    expect(neuralCalls, hasLength(chunks.length));
    expect(fallbackCalls, isEmpty);
    expect(neuralCalls.first.voice, 'pm_alex');
    expect(neuralCalls.first.nextText, chunks[1]);
    expect(neuralCalls[1].nextText, chunks[2]);
    expect(neuralCalls.last.nextText, isNull);

    // Falha no motor neural cai para fallback nos blocos restantes desta leitura...
    neuralCalls.clear();
    fallbackCalls.clear();
    neuralOk = false;
    await handler.load([ReadingSegment(id: 's2', title: 'Fallback', text: longText)]);
    await handler.play();
    expect(neuralCalls, hasLength(1));
    expect(fallbackCalls, chunks);

    // ...mas volta a tentar o motor neural no próximo play() quando recuperar.
    neuralCalls.clear();
    fallbackCalls.clear();
    neuralOk = true;
    await handler.play();
    expect(neuralCalls, hasLength(chunks.length));
    expect(fallbackCalls, isEmpty);

    // Pause durante neuralSpeak não aciona fallback.
    final pauseCompleter = Completer<bool>();
    final handlerPause = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: (text, speed, {voice = 'pf_dora', language = 'pt-BR', nextText}) => pauseCompleter.future,
      neuralStop: () {
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

    // Troca de voz durante reprodução reinicia frase com a nova voz.
    final swapStarted = Completer<void>();
    final firstSpeakGate = Completer<bool>();
    var callsOnSwap = 0;
    String? latestVoice;
    final handlerSwap = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: (text, speed, {voice = 'pf_dora', language = 'pt-BR', nextText}) async {
        callsOnSwap++;
        latestVoice = voice;
        if (callsOnSwap == 1) {
          if (!swapStarted.isCompleted) swapStarted.complete();
          return firstSpeakGate.future;
        }
        return true;
      },
      neuralStop: () {
        if (!firstSpeakGate.isCompleted) firstSpeakGate.complete(true);
      },
      fallbackSpeak: (text, language, speed) async => fallbackCalls.add(text),
    );
    await handlerSwap.load([const ReadingSegment(id: 's4', title: 'Swap', text: 'Primeira frase.')]);
    unawaited(handlerSwap.play());
    await swapStarted.future;
    await handlerSwap.setKokoroVoice('pm_alex');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(callsOnSwap, 2);
    expect(latestVoice, 'pm_alex');
  });

  testWidgets('AudioPlayerBar mostra barra de progresso durante download do Kokoro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final audio = ReadingAudioController.local();
    audio.setNeuralTtsStatusForTest(
      const NeuralTtsStatus(
        state: NeuralTtsState.downloading,
        progress: 0.42,
        label: 'Baixando voz neural Kokoro (42%)…',
      ),
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
