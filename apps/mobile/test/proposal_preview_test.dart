import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/proposal_pdf.dart';

void main() {
  testWidgets('exporta proposta técnica comercial para inspeção visual', (
    tester,
  ) async {
    final bytes = await buildTechnicalProposal();
    Directory('build').createSync(recursive: true);
    File('build/proposta.pdf').writeAsBytesSync(bytes);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(8000));
  });

  testWidgets('exporta capa e apresentação GS para o book do cliente', (
    tester,
  ) async {
    final bytes = await buildGsClientBookFront();
    Directory('build').createSync(recursive: true);
    File('build/book_gs.pdf').writeAsBytesSync(bytes);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
