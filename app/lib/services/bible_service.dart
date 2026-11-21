import 'dart:async';
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
/// - No app nativo (Android/iOS), instala na primeira abertura da aba Bíblia as
///   traduções embutidas listadas em `assets/bible/bundled.json` (BPM, Vulgata e
///   Douay-Rheims — domínio público), sem re-parsear o que já está atualizado.
/// - Na Web, carrega apenas o catálogo leve (`bundled.json`) e baixa/indexa
///   cada tradução sob demanda quando o usuário toca nela.
/// - Delega importação local (.json via `file_picker`) e remoção ao [BibleImportService].
class BibleService extends ChangeNotifier {
  BibleService(
    this.repo, {
    http.Client? client,
    bool? autoInstallBundled,
    Future<String> Function(String path)? loadAsset,
  }) : importer = BibleImportService(repo, client: client),
       autoInstallBundled = autoInstallBundled ?? !kIsWeb,
       _loadAsset = loadAsset ?? rootBundle.loadString {
    translations = repo.translations();
    position = repo.lastPosition();
  }

  final BibleRepository repo;
  final BibleImportService importer;
  final bool autoInstallBundled;
  final Future<String> Function(String path) _loadAsset;

  List<BibleTranslation> translations = const [];
  List<BundledTranslationInfo> bundledCatalog = const [];
  ReadingPosition? position;

  /// Progresso da preparação inicial/importação (null = ocioso).
  double? progress;
  String? progressLabel;
  String? activeInstallId;
  Future<void>? _bundledFuture;
  Future<List<BundledTranslationInfo>>? _catalogFuture;

  /// Referência pedida por outra aba (ex.: leitura da Liturgia) — consumida pela tela.
  BibleRef? pendingRef;

  bool get ready => translations.isNotEmpty;

  /// Traduções embutidas ainda não instaladas (ou com atualização pendente).
  List<BundledTranslationInfo> get availableBundled {
    final installed = {for (final t in translations) t.id: t.moduleVersion};
    return bundledCatalog.where((item) => (installed[item.id] ?? 0) < item.version).toList();
  }

  String get currentTranslationId {
    final id = position?.translationId;
    if (id != null && translations.any((t) => t.id == id)) return id;
    if (translations.isEmpty) return 'bpm';
    final pt = translations.where((t) => t.language.startsWith('pt'));
    return (pt.isNotEmpty ? pt.first : translations.first).id;
  }

  BibleTranslation? translation(String id) => translations.where((t) => t.id == id).firstOrNull;

  BibleTranslation? get current => translations.isEmpty ? null : translation(currentTranslationId);

  /// Carrega apenas o catálogo leve de `assets/bible/bundled.json` (~1 KB).
  Future<List<BundledTranslationInfo>> ensureCatalog() {
    if (bundledCatalog.isNotEmpty) return Future.value(bundledCatalog);
    if (_catalogFuture != null) return _catalogFuture!;
    late final Future<List<BundledTranslationInfo>> future;
    future = () async {
      try {
        return await _loadCatalog();
      } catch (_) {
        if (identical(_catalogFuture, future)) _catalogFuture = null;
        rethrow;
      }
    }();
    return _catalogFuture = future;
  }

  Future<List<BundledTranslationInfo>> _loadCatalog() async {
    final manifest = _decode(await _loadAsset('assets/bible/bundled.json'));
    final rawCatalog = manifest['catalogo'] as List?;
    final list = rawCatalog != null
        ? rawCatalog
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => BundledTranslationInfo.fromJson(e.cast<String, dynamic>()))
              .toList()
        : [
            for (final id in (manifest['modulos'] as List? ?? const []).cast<String>())
              BundledTranslationInfo(
                id: id,
                name: id.toUpperCase(),
                abbreviation: id.toUpperCase(),
                language: 'pt-BR',
                license: 'Domínio público',
              ),
          ];
    bundledCatalog = List.unmodifiable(list);
    notifyListeners();
    return bundledCatalog;
  }

  /// No nativo, instala/atualiza as traduções embutidas que faltam (checando a
  /// versão instalada antes de decodificar o JSON). Na Web, carrega só o catálogo.
  Future<void> ensureBundled() {
    if (_bundledFuture != null) return _bundledFuture!;
    late final Future<void> future;
    future = () async {
      try {
        await _runEnsureBundled();
      } catch (_) {
        if (identical(_bundledFuture, future)) _bundledFuture = null;
        rethrow;
      }
    }();
    return _bundledFuture = future;
  }

  Future<void> _runEnsureBundled() async {
    final catalog = await ensureCatalog();
    if (!autoInstallBundled) return;
    var changed = false;
    try {
      for (final item in catalog) {
        final installed = repo.installedVersion(item.id);
        if (installed != null && installed >= item.version) continue;
        changed = true;
        activeInstallId = item.id;
        _setProgress(0, 'Preparando ${item.name}…');
        final raw = await _loadAsset('assets/bible/${item.id}.json');
        final module = BibleModule.parse(await compute(_decode, raw));
        await repo.install(module, bundled: true, onProgress: (p) => _setProgress(p, 'Preparando ${module.name}…'));
        // Atualiza a lista logo após cada tradução (Português fica pronto primeiro).
        translations = repo.translations();
        notifyListeners();
      }
    } finally {
      activeInstallId = null;
      if (changed || progress != null) _done();
    }
  }

  /// Instala ou atualiza sob demanda uma tradução embutida pelo seu [id].
  Future<void> installBundled(String id) async {
    if (activeInstallId != null || progress != null) return;
    activeInstallId = id;
    _setProgress(0, 'Preparando tradução…');
    try {
      final catalog = await ensureCatalog();
      final info = catalog.where((c) => c.id == id).firstOrNull;
      final expectedVersion = info?.version ?? 1;
      final installed = repo.installedVersion(id);
      if (installed != null && installed >= expectedVersion) return;
      _setProgress(0, 'Preparando ${info?.name ?? id}…');
      final raw = await _loadAsset('assets/bible/$id.json');
      final module = BibleModule.parse(await compute(_decode, raw));
      await repo.install(module, bundled: true, onProgress: (p) => _setProgress(p, 'Preparando ${module.name}…'));
    } finally {
      activeInstallId = null;
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

  Future<void> remove(String id) async {
    await importer.deleteTranslation(id);
    _done();
  }

  void open(String translationId, String bookId, int chapter, {int? verse}) {
    position = ReadingPosition(translationId, bookId, chapter, verse);
    repo.savePosition(position!);
    notifyListeners();
  }

  /// Guarda o versículo tocado como posição de leitura, sem reconstruir o leitor.
  void rememberVerse(String translationId, String bookId, int chapter, int verse) {
    position = ReadingPosition(translationId, bookId, chapter, verse);
    repo.savePosition(position!);
  }

  /// Pedido de abertura vindo de outra aba (a navegação troca para a Bíblia).
  void requestOpen(BibleRef ref) {
    pendingRef = ref;
    if (autoInstallBundled) {
      unawaited(ensureBundled().catchError((Object e) => debugPrint('Erro ao preparar Bíblia: $e')));
    } else if (!ready) {
      unawaited(installBundled('bpm').catchError((Object e) => debugPrint('Erro ao baixar BPM: $e')));
    }
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
