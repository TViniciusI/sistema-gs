import 'package:flutter/foundation.dart';
import 'package:gs_mobile/data/field_files.dart'
    if (dart.library.io) 'package:gs_mobile/data/field_files_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/field_files_web.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/prefs_json.dart';

class OfficeStore extends ChangeNotifier {
  OfficeStore._();
  static final instance = OfficeStore._();

  static const _owner = 'administracao';

  final _files = createFieldFiles();
  final _memoryBytes = <String, Uint8List>{};
  List<SavedOs> items = [];

  Future<void> load() async {
    await removePrefsKey(officeRdosPrefsKey);
    items = [];
    notifyListeners();
  }

  Uint8List? bytesFor(SavedFile file) {
    if (file.bytes != null) return Uint8List.fromList(file.bytes!);
    return _memoryBytes[file.path];
  }

  Future<void> receive(SavedOs os) async {
    await removePrefsKey(officeRdosPrefsKey);
    final copied = <SavedFile>[];
    for (final file in os.files) {
      final bytes =
          FieldStore.instance.bytesFor(file) ??
          (file.bytes != null ? Uint8List.fromList(file.bytes!) : null);
      if (bytes == null) continue;
      var path = 'mem/$_owner/${os.id}/${file.name}';
      try {
        path = await _files.save(
          ownerEmail: _owner,
          osId: os.id,
          fileName: file.name,
          bytes: bytes,
        );
      } catch (_) {}
      _memoryBytes[path] = bytes;
      copied.add(
        SavedFile(
          name: file.name,
          path: path,
          kind: file.kind,
          bytes: bytes,
          label: file.label,
        ),
      );
    }
    final record = SavedOs(
      id: os.id,
      number: os.number,
      ownerEmail: os.ownerEmail,
      createdAt: os.createdAt,
      files: copied,
      emailed: true,
      signerName: os.signerName,
      rdo: os.rdo,
      technicianEmail: os.technicianEmail,
      technicianName: os.technicianName,
      technicianEmails: os.technicianEmails,
      status: os.status,
      rdos: [
        for (final entry in os.rdos)
          entry.copyWith(
            files: [
              for (final file in entry.files)
                SavedFile(
                  name: file.name,
                  path: file.path,
                  kind: file.kind,
                  label: file.label,
                ),
            ],
          ),
      ],
    );
    items = [record, ...items.where((item) => item.id != os.id)];
    if (items.length > 30) items = items.take(30).toList();
    notifyListeners();
  }
}
