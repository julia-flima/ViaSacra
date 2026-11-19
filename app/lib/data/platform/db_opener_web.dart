import 'package:sqlite3/wasm.dart';

IndexedDbFileSystem? _fs;
WasmSqlite3? _sqlite;

Future<WasmSqlite3> _load() async {
  if (_sqlite != null) return _sqlite!;
  // sqlite3.wasm é copiado para web/ no build (ver .github/workflows/deploy-web.yml)
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.base.resolve('sqlite3.wasm'));
  _fs = await IndexedDbFileSystem.open(dbName: 'via_sacra');
  sqlite.registerVirtualFileSystem(_fs!, makeDefault: true);
  return _sqlite = sqlite;
}

Future<CommonDatabase> openPlatformDatabase(String name) async {
  final sqlite = await _load();
  return sqlite.open('/$name.db');
}

CommonDatabase openMemoryDatabase() =>
    throw UnsupportedError('Banco em memória síncrono indisponível na web; use openPlatformDatabase.');

/// Garante que as páginas pendentes foram gravadas no IndexedDB.
Future<void> flushPlatformDatabase() async => _fs?.flush();
