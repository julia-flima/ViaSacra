import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'json_file.dart';
import '../data/bible/bible_module.dart';
import '../data/bible/bible_repository.dart';

/// Resumo de uma tradução importada com sucesso.
class BibleImportResult {
  const BibleImportResult({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.bookCount,
    required this.verseCount,
  });

  final String id;
  final String name;
  final String abbreviation;
  final int bookCount;
  final int verseCount;
}

typedef BibleImportProgress = void Function(double progress, String label);

/// Serviço modular para validação, importação local (.json) e remoção de
/// traduções da Bíblia Sagrada.
///
/// Usa `file_picker` (compatível com Android, iOS, Web e F-Droid) e grava
/// tudo localmente no banco SQLite/FTS5 sem violar a licença Open Source.
class BibleImportService {
  BibleImportService(this._repo, {http.Client? client}) : _client = client ?? http.Client();

  final BibleRepository _repo;
  final http.Client _client;

  /// Abre o seletor de arquivos do aparelho para escolher um módulo `.json`.
  /// Retorna `null` se o usuário cancelar.
  Future<BibleImportResult?> importFromFile({BibleImportProgress? onProgress}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Escolha o módulo de tradução (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    onProgress?.call(0.05, 'Lendo arquivo selecionado…');
    final bytes = await file.readAsBytes();
    return importFromBytes(bytes, onProgress: onProgress);
  }

  /// Baixa e importa um módulo `.json` a partir de uma URL `https://` informada pelo usuário.
  Future<BibleImportResult> importFromUrl(String url, {BibleImportProgress? onProgress}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') {
      throw BibleModuleException('Informe um endereço https:// válido.');
    }
    onProgress?.call(0.05, 'Baixando módulo…');
    final resp = await _client.get(uri).timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200) {
      throw BibleModuleException('Falha ao baixar o arquivo (HTTP ${resp.statusCode}).');
    }
    return importFromBytes(resp.bodyBytes, onProgress: onProgress);
  }

  /// Valida e instala um módulo JSON a partir de bytes UTF-8.
  Future<BibleImportResult> importFromBytes(Uint8List bytes, {BibleImportProgress? onProgress}) async {
    onProgress?.call(0.1, 'Validando estrutura do JSON…');
    final Map<String, dynamic> json;
    try {
      json = await decodeJsonFile(bytes);
    } on FormatException catch (e) {
      throw BibleModuleException(e.message);
    }

    final module = BibleModule.parse(json);
    onProgress?.call(0.15, 'Importando ${module.name} (${module.books.length} livros)…');
    await _repo.install(module, onProgress: (p) => onProgress?.call(0.15 + p * 0.85, 'Importando ${module.name}…'));
    return BibleImportResult(
      id: module.id,
      name: module.name,
      abbreviation: module.abbreviation,
      bookCount: module.books.length,
      verseCount: module.verseCount,
    );
  }

  /// Remove uma tradução importada localmente para liberar espaço.
  /// Traduções nativas embutidas não podem ser excluídas.
  Future<void> deleteTranslation(String translationId) async {
    final tr = _repo.translation(translationId);
    if (tr == null) return;
    if (tr.bundled) {
      throw BibleModuleException('Traduções nativas embutidas não podem ser removidas.');
    }
    await _repo.remove(translationId);
  }
}
