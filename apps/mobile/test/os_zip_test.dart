import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/os_zip.dart';

void main() {
  test('zipOsFiles compacta vários PDFs em um arquivo', () {
    final zipBytes = zipOsFiles([
      (name: 'RDO_1.pdf', bytes: utf8.encode('pdf-um')),
      (name: 'RDO_2.pdf', bytes: utf8.encode('pdf-dois')),
      (name: 'RDO_1.pdf', bytes: utf8.encode('pdf-duplicado')),
    ]);
    expect(zipBytes, isNotEmpty);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    expect(archive.length, 3);
    final names = [for (final file in archive) file.name];
    expect(names, contains('RDO_1.pdf'));
    expect(names, contains('RDO_1_2.pdf'));
    expect(names, contains('RDO_2.pdf'));
  });

  test('zipAsDraft gera DraftFile .zip', () {
    final draft = zipAsDraft(
      osNumber: '048/26',
      files: [
        DraftFile(
          name: 'a.pdf',
          kind: OsFileKind.rdo,
          bytes: utf8.encode('aaa'),
        ),
        DraftFile(
          name: 'b.pdf',
          kind: OsFileKind.rdo,
          bytes: utf8.encode('bbb'),
        ),
      ],
    );
    expect(draft.name, endsWith('.zip'));
    expect(draft.name, contains('048-26'));
    expect(draft.bytes, isNotNull);
    expect(draft.bytes!, isNotEmpty);
  });
}
