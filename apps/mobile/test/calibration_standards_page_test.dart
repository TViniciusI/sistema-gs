import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/features/calibration/calibration_standards_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('padrões agrupados por categoria e cadastro com locais', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'gs_calibration_standards_v1': jsonEncode([
        const CatalogStandard(
          id: 'a',
          name: 'GS 001',
          type: 'MEDIDOR CORIOLIS',
          categories: [StandardCategory.volumetric],
        ).toJson(),
        const CatalogStandard(
          id: 'b',
          name: 'GS 001 - D',
          type: 'Medidor Coriolis',
          categories: [StandardCategory.density],
          owner: standardOwnerClient,
          ownerClientName: 'VIBRA',
          locations: ['Goiânia/GO', 'Rio Verde/GO'],
        ).toJson(),
        const CatalogStandard(
          id: 'c',
          name: 'FLB-40.121/2025',
          type: 'TERMÔMETRO DIGITAL',
          uncertainty: '0,2°C',
        ).toJson(),
      ]),
    });
    CalibrationCatalog.instance.resetForTest();
    await tester.runAsync(() => CalibrationCatalog.instance.load());
    await tester.pumpWidget(
      const MaterialApp(home: CalibrationStandardsPage()),
    );
    await tester.pump();

    expect(find.text('Volumétrica · 1'), findsOneWidget);
    expect(find.text('Densidade · 1'), findsOneWidget);
    expect(find.text('Sem categoria · 1'), findsOneWidget);
    expect(find.text('Cliente: VIBRA · Locais: Goiânia/GO, Rio Verde/GO'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('padrao-filtro-densidade')));
    await tester.pump();
    expect(find.text('GS 001 - D'), findsOneWidget);
    expect(find.text('GS 001'), findsNothing);

    await tester.tap(find.byKey(const Key('padrao-filtro-todos')));
    await tester.pump();
    await tester.tap(find.text('FLB-40.121/2025'));
    await tester.pumpAndSettle();
    final temp = tester.widget<FilterChip>(
      find.byKey(const Key('padrao-categoria-temperatura')),
    );
    expect(temp.selected, isTrue);
    expect(find.text('Sugestão pelo nome e pela unidade. Confira e salve.'),
        findsOneWidget);

    await tester.tap(find.text('Do cliente'));
    await tester.pump();
    expect(find.byKey(const Key('padrao-cliente')), findsOneWidget);
    await tester.tap(find.byKey(const Key('padrao-locais-mais')));
    await tester.tap(find.byKey(const Key('padrao-locais-mais')));
    await tester.pump();
    expect(find.byKey(const Key('padrao-local-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
