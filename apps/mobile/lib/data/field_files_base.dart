import 'dart:typed_data';

abstract class FieldFiles {
  Future<String> save({
    required String ownerEmail,
    required String osId,
    required String fileName,
    required Uint8List bytes,
  });

  Future<Uint8List?> read(String path);
}
