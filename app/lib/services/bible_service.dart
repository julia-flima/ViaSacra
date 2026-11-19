import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../data/bible/bible_models.dart';
import '../data/bible/bible_module.dart';
import '../data/bible/bible_reference.dart';
import '../data/bible/bible_repository.dart';

Map<String, dynamic> _decode(String raw) => jsonDecode(raw) as Map<String, dynamic>;

/// Estado da Bíblia + serviço modular de traduções.
///
/// - Instala na primeira execução os módulos embutidos (domínio público)
///   listados em `assets/bible/bundled.json`.
/// - Importa módulos locais (.json no formato "viasacra-biblia") escolhidos
///   pelo usuário ou baixados de um endereço informado por ele. Traduções
///   protegidas (CNBB, Ave-Maria, Jerusalém, Pastoral) só devem ser importadas
///   com autorização do titular — o app não fornece nem indica esses arquivos.
class BibleService extends ChangeNotifier {
  BibleService(this.repo, {http.Client? client}) : _client = client ?? http.Client() {
    translations = repo.translations();
    position = repo.lastPosition();
  }

  final BibleRepository repo;
  final http.Client _client;

  List<BibleTranslation> translations = const [];
  ReadingPosition? position;

  /// Progresso da preparação inicial/importação (null = ocioso).
  double? progress;
  String? progressLabel;

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

  /// Instala/atualiza os módulos embutidos que faltam.
  Future<void> ensureBundled() async {
    final manifest = _decode(await rootBundle.loadString('assets/bible/bundled.json'));
    final ids = (manifest['modulos'] as List).cast<String>();
    for (final id in ids) {
      final raw = await rootBundle.loadString('assets/bible/$id.json');
      final module = BibleModule.parse(await compute(_decode, raw));
      final installed = repo.installedVersion(id);
      if (installed != null && installed >= module.version) continue;
      _setProgress(0, 'Preparando ${module.name}…');
      await repo.install(module, bundled: true, onProgress: (p) => _setProgress(p, 'Preparando ${module.name}…'));
    }
    _done();
  }

  /// Importa um módulo a partir de um arquivo escolhido pelo usuário.
  /// Retorna o nome da tradução importada, ou null se o usuário cancelar.
  Future<String?> importFromFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Escolha o módulo de tradução (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    return importFromBytes(await file.readAsBytes());
  }

  /// Importa a partir de um endereço (https) informado pelo próprio usuário.
  Future<String> importFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') throw BibleModuleException('Informe um endereço https:// válido.');
    final resp = await _client.get(uri).timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200) throw BibleModuleException('Falha ao baixar (HTTP ${resp.statusCode}).');
    return importFromBytes(resp.bodyBytes);
  }

  Future<String> importFromBytes(Uint8List bytes) async {
    _setProgress(0, 'Lendo módulo…');
    try {
      final Map<String, dynamic> json;
      try {
        json = await compute(_decode, utf8.decode(bytes));
      } on FormatException {
        throw BibleModuleException('O arquivo não é um JSON válido.');
      }
      final module = BibleModule.parse(json);
      await repo.install(module, onProgress: (p) => _setProgress(p, 'Importando ${module.name}…'));
      return module.name;
    } finally {
      _done();
    }
  }

  Future<void> remove(String id) async {
    await repo.remove(id);
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
