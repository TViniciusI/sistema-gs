import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:gs_mobile/data/field_files_base.dart';
import 'package:web/web.dart' as web;

export 'package:gs_mobile/data/field_files_base.dart';

/// Anexos no navegador: memória + IndexedDB (sobrevive a F5 / reabrir o PWA).
class WebFieldFiles implements FieldFiles {
  static const _dbName = 'gs_campo_files_v1';
  static const _storeName = 'files';

  final _bytes = <String, Uint8List>{};
  Future<web.IDBDatabase>? _dbFuture;

  Future<web.IDBDatabase> _openDb() {
    return _dbFuture ??= () {
      final completer = Completer<web.IDBDatabase>();
      final req = web.window.indexedDB.open(_dbName, 1);
      req.onupgradeneeded = ((web.Event _) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }).toJS;
      req.onsuccess = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.complete(req.result as web.IDBDatabase);
        }
      }).toJS;
      req.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            req.error?.message ?? 'Falha ao abrir armazenamento local',
          );
        }
      }).toJS;
      return completer.future;
    }();
  }

  Future<void> _awaitRequest(web.IDBRequest req) {
    final completer = Completer<void>();
    req.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    req.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          req.error?.message ?? 'Falha no armazenamento local',
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<JSAny?> _awaitResult(web.IDBRequest req) {
    final completer = Completer<JSAny?>();
    req.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(req.result);
    }).toJS;
    req.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          req.error?.message ?? 'Falha no armazenamento local',
        );
      }
    }).toJS;
    return completer.future;
  }

  @override
  Future<String> save({
    required String ownerEmail,
    required String osId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'web/$ownerEmail/$osId/$fileName';
    final copy = Uint8List.fromList(bytes);
    _bytes[path] = copy;
    try {
      final db = await _openDb();
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      await _awaitRequest(store.put(copy.toJS, path.toJS));
    } catch (_) {
      // Memória já tem o arquivo; salvar na pasta da OS ainda funciona nesta sessão.
    }
    return path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    if (path.isEmpty) return null;
    final cached = _bytes[path];
    if (cached != null && cached.isNotEmpty) {
      return Uint8List.fromList(cached);
    }
    try {
      final db = await _openDb();
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final result = await _awaitResult(store.get(path.toJS));
      if (result == null) return null;
      final data = _bytesFromJs(result);
      if (data == null || data.isEmpty) return null;
      _bytes[path] = data;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _bytesFromJs(JSAny value) {
    if (value.isA<JSUint8Array>()) {
      return (value as JSUint8Array).toDart;
    }
    if (value.isA<JSArrayBuffer>()) {
      return (value as JSArrayBuffer).toDart.asUint8List();
    }
    return null;
  }
}

FieldFiles createFieldFiles() => WebFieldFiles();
