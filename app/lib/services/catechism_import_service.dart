import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../data/catechism_repository.dart';
import '../data/models/catechism.dart';

Map<String, dynamic> _decodeJsonObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw CatechismModuleException('O arquivo JSON deve conter um objeto na raiz ({ ... }).');
  }
  return decoded;
}

/// Resumo de um catecismo importado localmente pelo usuário.
class CatechismImportResult {
  const CatechismImportResult({required this.id, required this.name, required this.entryCount});

  final String id;
  final String name;
  final int entryCount;
}

typedef CatechismImportProgress = void Function(double progress, String label);

/// Importador modular local (.json) para catecismos (ex.: CIC 1992 ou Compêndio),
/// reaproveitando a arquitetura do `BibleImportService` com `file_picker`.
class CatechismImportService {
  CatechismImportService(this._repo);

  final CatechismRepository _repo;

  /// Abre o seletor de arquivos do aparelho para importar um módulo `.json`.
  /// Retorna `null` se o usuário cancelar.
  Future<CatechismImportResult?> importFromFile({CatechismImportProgress? onProgress}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Escolha o módulo de catecismo (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    onProgress?.call(0.1, 'Lendo arquivo selecionado…');
    return importFromBytes(await file.readAsBytes(), onProgress: onProgress);
  }

  /// Valida e grava localmente um módulo `.json` a partir de bytes UTF-8.
  Future<CatechismImportResult> importFromBytes(Uint8List bytes, {CatechismImportProgress? onProgress}) async {
    if (bytes.isEmpty) {
      throw CatechismModuleException('O arquivo selecionado está vazio.');
    }
    onProgress?.call(0.2, 'Validando estrutura do JSON…');
    final String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      throw CatechismModuleException('O arquivo não está codificado em UTF-8 válido.');
    }
    final Map<String, dynamic> json;
    try {
      json = await compute(_decodeJsonObject, raw);
    } on FormatException catch (e) {
      throw CatechismModuleException('JSON malformado: ${e.message}');
    }
    final module = CatechismModule.parse(json);
    onProgress?.call(0.5, 'Indexando ${module.name} (${module.entryCount} entradas)…');
    await _repo.installWork(module);
    onProgress?.call(1.0, 'Concluído');
    return CatechismImportResult(id: module.id, name: module.name, entryCount: module.entryCount);
  }

  /// Exclui um catecismo importado localmente para liberar espaço.
  Future<void> deleteWork(String id) async {
    final w = _repo.work(id);
    if (w == null) return;
    if (w.bundled) {
      throw CatechismModuleException('Catecismos embutidos (domínio público) não podem ser excluídos.');
    }
    await _repo.removeWork(id);
  }
}
