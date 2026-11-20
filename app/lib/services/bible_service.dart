import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../data/bible/bible_models.dart';
import '../data/bible/bible_module.dart';
import '../data/bible/bible_reference.dart';
import '../data/bible/bible_repository.dart';
import 'bible_import_service.dart';

Map<String, dynamic> _decode(String raw) => jsonDecode(raw) as Map<String, dynamic>;

/// Estado da Bíblia + serviço modular de traduções.
///
/// - Instala na primeira execução os módulos nativos (embutidos) listados em
///   `assets/bible/bundled.json` (Bíblia Portuguesa Mundial em pt-BR, Vulgata
///   Clementina em Latim e Douay-Rheims em Inglês — todos em domínio público).
/// - Delega a validação, importação local (.json via `file_picker`) e remoção
///   de traduções ao [BibleImportService].
class BibleService extends ChangeNotifier {
  BibleService(this.repo, {http.Client? client}) : importer = BibleImportService(repo, client: client) {
    translations = repo.translations();
    position = repo.lastPosition();
  }

  final BibleRepository repo;
  final BibleImportService importer;

  List<BibleTranslation> translations = const [];
  ReadingPosition? position;

  /// Progresso da preparação inicial/importação (null = ocioso).
  double? progress;
  String? progressLabel;
  Future<void>? _bundledFuture;

  /// Referência pedida por outra aba (ex.: leitura da Liturgia) — consumida pela tela.
  BibleRef? pendingRef;

  bool get ready => translations.isNotEmpty;

  String get currentTranslationId {
    final id = position?.translationId;
    if (id != null && translations.any((t) => t.id == id)) return id;
    final pt = translations.where((t) => t.language.startsWith('pt'));
    return (pt.isNotEmpty ? pt.first : translations.first).id;
  }

  BibleTranslation? translation(String id) => translations.where((t) => t.id == id).firstOrNull;

  BibleTranslation? get current => translations.where((t) => t.id == currentTranslationId).firstOrNull;

  /// Instala/atualiza os módulos embutidos que faltam (executado sob demanda
  /// ao abrir a aba Bíblia, sem travar a abertura inicial da Liturgia).
  Future<void> ensureBundled() => _bundledFuture ??= _runEnsureBundled();

  Future<void> _runEnsureBundled() async {
    try {
      final manifest = _decode(await rootBundle.loadString('assets/bible/bundled.json'));
      final ids = (manifest['modulos'] as List).cast<String>();
      for (final id in ids) {
        final raw = await rootBundle.loadString('assets/bible/$id.json');
        final module = BibleModule.parse(await compute(_decode, raw));
        final installed = repo.installedVersion(id);
        if (installed != null && installed >= module.version) continue;
        _setProgress(0, 'Preparando ${module.name}…');
        await repo.install(module, bundled: true, onProgress: (p) => _setProgress(p, 'Preparando ${module.name}…'));
        // Atualiza a lista logo após cada tradução (Português fica pronto primeiro).
        translations = repo.translations();
        notifyListeners();
      }
    } finally {
      _done();
    }
  }

  /// Importa um módulo a partir de um arquivo `.json` escolhido pelo usuário.
  /// Retorna o resultado da importação, ou `null` se o usuário cancelar.
  Future<BibleImportResult?> importFromFile() async {
    try {
      return await importer.importFromFile(onProgress: _setProgress);
    } finally {
      _done();
    }
  }

  /// Importa a partir de um endereço (https) informado pelo próprio usuário.
  Future<BibleImportResult> importFromUrl(String url) async {
    try {
      return await importer.importFromUrl(url, onProgress: _setProgress);
    } finally {
      _done();
    }
  }

  Future<BibleImportResult> importFromBytes(Uint8List bytes) async {
    try {
      return await importer.importFromBytes(bytes, onProgress: _setProgress);
    } finally {
      _done();
    }
  }

  Future<void> remove(String id) async {
    await importer.deleteTranslation(id);
    _done();
  }

  void open(String translationId, String bookId, int chapter, {int? verse}) {
    position = ReadingPosition(translationId, bookId, chapter, verse);
    repo.savePosition(position!);
    notifyListeners();
  }

  /// Pedido de abertura vindo de outra aba (a navegação troca para a Bíblia).
  void requestOpen(BibleRef ref) {
    pendingRef = ref;
    ensureBundled();
    notifyListeners();
  }

  void _setProgress(double p, String label) {
    progress = p;
    progressLabel = label;
    notifyListeners();
  }

  void _done() {
    progress = null;
    progressLabel = null;
    translations = repo.translations();
    notifyListeners();
  }
}
