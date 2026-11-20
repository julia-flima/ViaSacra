import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:via_sacra/app_navigation.dart';
import 'package:via_sacra/services/reading_audio_service.dart';

import 'support/app_harness.dart';

/// Fala "infinita" controlada pelo teste: só termina quando o handler chama stop.
class _SpeechGate {
  final calls = <String>[];
  final _gates = <Completer<bool>>[];

  Future<bool> speak(
    String text,
    double speed, {
    String voice = 'pf_dora',
    String language = 'pt-BR',
    String? nextText,
  }) {
    calls.add(text);
    final c = Completer<bool>();
    _gates.add(c);
    return c.future;
  }

  void stopAll() {
    for (final g in _gates) {
      if (!g.isCompleted) g.complete(true);
    }
  }
}

final _player = find.byKey(const ValueKey('global-audio-mini-player'));
Finder _inPlayer(Finder f) => find.descendant(of: _player, matching: f);

void main() {
  setUpScreens();
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async => {});
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'), (call) async => null);
  });

  testWidgets('Mini-player global: Liturgia sem duplicar, Bíblia e telas empurradas sem sair da tela', (tester) async {
    final gate = _SpeechGate();
    final audio = ReadingAudioController.local(
      handler: ReadingAudioHandler(
        useNeuralEngine: true,
        neuralSpeak: gate.speak,
        neuralStop: gate.stopAll,
        fallbackSpeak: (text, language, speed) async {},
      ),
    );
    final s = await buildServices(onboardingDone: true, audio: audio);
    await pumpApp(tester, s);

    // Sem fila carregada, nada de mini-player.
    expect(_player, findsNothing);

    // Na aba Liturgia o mini-player não duplica a barra "Ouvir Liturgia".
    unawaited(
      audio.playQueue('liturgia-2026-11-19#segmented', const [
        ReadingSegment(id: '1', title: '1ª Leitura', text: 'A.'),
        ReadingSegment(id: '2', title: 'Evangelho', text: 'B.'),
      ]),
    );
    await settle(tester, frames: 3);
    expect(_player, findsNothing);

    // Em outra aba, o mesmo áudio aparece no mini-player com anterior/próximo.
    tester.element(find.byType(NavigationBar)).read<NavigationController>().go(AppTab.terco);
    await settle(tester, frames: 3);
    expect(_player, findsOneWidget);
    expect(_inPlayer(find.text('1 de 2')), findsOneWidget);
    await tester.tap(_inPlayer(find.byIcon(Icons.skip_next_rounded)));
    await settle(tester, frames: 3);
    expect(audio.index, 1);

    final nav = tester.element(find.byType(NavigationBar)).read<NavigationController>();
    nav.go(AppTab.biblia);
    await settle(tester);

    unawaited(audio.playSingle(const ReadingSegment(id: 'biblia-bpm-Gn-1', title: 'Gênesis 1', text: 'No princípio.')));
    await settle(tester, frames: 3);
    expect(_player, findsOneWidget);
    expect(_inPlayer(find.text('Gênesis 1')), findsOneWidget);
    expect(audio.playing, isTrue);

    // Pausar e retomar.
    await tester.tap(_inPlayer(find.byIcon(Icons.pause_rounded)));
    await settle(tester, frames: 3);
    expect(audio.playing, isFalse);
    await tester.tap(_inPlayer(find.byIcon(Icons.play_arrow_rounded)));
    await settle(tester, frames: 3);
    expect(audio.playing, isTrue);

    // Velocidade rápida: 1× → 1,25×.
    await tester.tap(_inPlayer(find.text('1×')));
    await settle(tester, frames: 3);
    expect(audio.speed, 1.25);
    expect(s.settings.ttsSpeed, 1.25);

    // Em uma tela empurrada (ex.: Imitação, Via Sacra), o mini-player continua visível.
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Tela de leitura')))),
    );
    await settle(tester);
    expect(find.text('Tela de leitura'), findsOneWidget);
    expect(_player, findsOneWidget);
    await tester.tap(_inPlayer(find.byIcon(Icons.pause_rounded)));
    await settle(tester, frames: 3);
    expect(audio.playing, isFalse);

    // Parar e fechar descarrega a fila e esconde o player.
    await tester.tap(_inPlayer(find.byIcon(Icons.close_rounded)));
    await settle(tester, frames: 3);
    expect(audio.hasQueue, isFalse);
    expect(_player, findsNothing);
    expect(find.text('Tela de leitura'), findsOneWidget, reason: 'fechar o player não remonta o Navigator');

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
  });
}
