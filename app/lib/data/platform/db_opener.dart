/// Abertura do SQLite por plataforma (import condicional).
///  • Android/iOS: arquivo no diretório de suporte do app (package:sqlite3 nativo, FTS5).
///  • Web/PWA: SQLite compilado para WebAssembly (`web/sqlite3.wasm`) persistido no
///    IndexedDB do navegador — o mesmo motor usado pelo drift na web, sem geração de código.
library;

export 'db_opener_native.dart' if (dart.library.js_interop) 'db_opener_web.dart';
