import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

Future<CommonDatabase> openPlatformDatabase(String name) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final db = sqlite3.open(p.join(dir.path, '$name.db'));
  db.execute('PRAGMA journal_mode = WAL;');
  return db;
}

CommonDatabase openMemoryDatabase() => sqlite3.openInMemory();

/// Persistência explícita (no nativo, o SQLite já grava em disco).
Future<void> flushPlatformDatabase() async {}
