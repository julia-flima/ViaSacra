import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Lê um arquivo `.json` importado pelo usuário (fora do thread da interface).
/// Erros saem como [FormatException] com mensagem pronta para mostrar.
Future<Map<String, dynamic>> decodeJsonFile(Uint8List bytes) async {
  if (bytes.isEmpty) throw const FormatException('O arquivo selecionado está vazio.');
  return compute(_decode, bytes);
}

Map<String, dynamic> _decode(Uint8List bytes) {
  final String raw;
  try {
    raw = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('O arquivo não está codificado em UTF-8 válido.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw FormatException('JSON malformado: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('O arquivo JSON deve conter um objeto na raiz ({ ... }).');
  }
  return decoded;
}
