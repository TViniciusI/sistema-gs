import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';

ClientSystem _ilha(String id, String tag, {String serial = ''}) => ClientSystem(
  id: id,
  systemType: 'Sistema de Carregamento',
  installLocation: 'Plataforma de Carregamento',
  tag: tag,
  kind: ClientAssemblyKind.preset,
  instruments: [
    ClientInstrument(id: '$id-m', tag: tag, serialNumber: serial),
  ],
);

SavedClient _cliente(String name, List<ClientSystem> systems, int minute) =>
    SavedClient(
      id: 'babet',
      name: name,
      cnpj: '34.274.233/0025-71',
      systems: systems,
      updatedAt: DateTime(2026, 10, 13, 20, minute),
    );

void main() {
  test('edição antiga não apaga ilhas nem nome trocados em outro aparelho', () {
    final base = _cliente('Vibra Energia - BABET', [_ilha('1', 'Ilha 1')], 0);
    // Outro aparelho: cadastrou mais ilhas e trocou o nome.
    final cloud = _cliente('VIBRA ENERGIA S.A - BABET', [
      _ilha('1', 'Ilha 1'),
      _ilha('2', 'Ilha 2'),
      _ilha('3', 'Ilha 3'),
    ], 30);
    // Este aparelho: só corrigiu o N/S da Ilha 1.
    final draft = _cliente('Vibra Energia - BABET', [
      _ilha('1', 'Ilha 1', serial: 'SN-123'),
    ], 45);

    final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);

    expect(merged.name, 'VIBRA ENERGIA S.A - BABET');
    expect(merged.resolvedSystems.map((s) => s.tag), [
      'Ilha 1',
      'Ilha 2',
      'Ilha 3',
    ]);
    expect(
      merged.resolvedSystems.first.instruments.first.serialNumber,
      'SN-123',
    );
  });

  test('o que o usuário mudou vale, inclusive apagar ilha', () {
    final base = _cliente('BABET', [
      _ilha('1', 'Ilha 1'),
      _ilha('2', 'Ilha 2'),
    ], 0);
    final cloud = _cliente('BABET', [
      _ilha('1', 'Ilha 1'),
      _ilha('2', 'Ilha 2'),
      _ilha('9', 'Ilha 9'),
    ], 30);
    final draft = _cliente('BABET NOVO', [_ilha('1', 'Ilha 1')], 45);

    final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);

    expect(merged.name, 'BABET NOVO');
    expect(merged.resolvedSystems.map((s) => s.id), ['1', '9']);
  });
}
