import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/features/clients/client_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

ClientSystem _preset(String id, String tag) => ClientSystem(
  id: id,
  systemType: 'Sistema de Carregamento',
  installLocation: 'Plataforma de Carregamento',
  tag: tag,
  kind: ClientAssemblyKind.preset,
  instruments: [ClientInstrument(id: '$id-m', tag: tag, serialNumber: 'SN$id')],
);

SavedClient _cliente(List<ClientSystem> systems) => SavedClient(
  id: 'babet',
  name: 'BABET',
  cnpj: '34.274.233/0025-71',
  systems: systems,
  equipment: flattenClientSystems(systems),
  updatedAt: DateTime(2026, 11, 26, 14),
);

Future<bool> _appearsWhileScrolling(WidgetTester tester, String text) async {
  final list = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(list).position;
  await tester.drag(list, const Offset(0, 10000));
  await tester.pumpAndSettle();
  var seen = false;
  while (true) {
    if (find.textContaining(text).evaluate().isNotEmpty) seen = true;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(list, const Offset(0, -150));
    await tester.pump();
  }
  return seen;
}

void main() {
  final p26 = _preset('1', 'Preset P26');
  final fiq = _preset('2', 'Preset FIQ-30');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClientStore.instance.resetForTest();
  });

  testWidgets(
    'sistema excluído na tela de cadastro não volta ao reabrir depois de sincronizar',
    (tester) async {
      await tester.runAsync(
        () => ClientStore.instance.load(
          remoteClients: [
            _cliente([p26, fiq]).toJson(),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientEditPage(existing: ClientStore.instance.byId('babet')),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('FIQ-30'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final fiqCard = find
          .ancestor(of: find.text('Preset FIQ-30'), matching: find.byType(Card))
          .first;
      final fiqDelete = find.descendant(
        of: fiqCard,
        matching: find.byTooltip('Excluir'),
      );
      expect(fiqDelete, findsOneWidget);
      await tester.tap(fiqDelete);
      await tester.pump();
      expect(await _appearsWhileScrolling(tester, 'FIQ-30'), isFalse);

      final save = find.byKey(const Key('save-client'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(
        ClientStore.instance.byId('babet')!.resolvedSystems.map((s) => s.id),
        ['1'],
      );

      await tester.runAsync(
        () => ClientStore.instance.load(
          remoteClients: [
            _cliente([p26, fiq]).toJson(),
          ],
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ClientEditPage(existing: ClientStore.instance.byId('babet')),
        ),
      );
      await tester.pump();

      expect(await _appearsWhileScrolling(tester, 'Preset P26'), isTrue);
      expect(await _appearsWhileScrolling(tester, 'FIQ-30'), isFalse);
    },
  );
}
