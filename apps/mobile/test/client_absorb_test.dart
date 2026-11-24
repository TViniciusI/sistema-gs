import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';

ClientSystem _sys(String id, String tag) => ClientSystem(
  id: id,
  systemType: 'Sistema de Carregamento',
  installLocation: 'Plataforma de Carregamento',
  tag: tag,
  kind: ClientAssemblyKind.preset,
  manufacturer: 'FmcTechnologies',
  model: 'Accuload',
  serialNumber: 'PF2915',
  instruments: [ClientInstrument(id: '$id-m', tag: tag)],
);

SavedClient _client(
  List<ClientSystem> systems, {
  DateTime? updatedAt,
}) => SavedClient(
  id: 'cli-1',
  name: 'Cliente teste',
  cnpj: '00.000.000/0001-00',
  systems: systems,
  updatedAt: updatedAt ?? DateTime(2026, 11, 21, 12),
);

void main() {
  test('exclusão na nuvem apaga cadastro maior que só existia no aparelho', () {
    final local = _client([
      _sys('a', 'FIQ-30'),
      _sys('b', 'FIQ-31'),
    ]);
    final remote = _client([_sys('b', 'FIQ-31')]);

    final merged = absorbRemoteClient(local: local, remote: remote);

    expect(merged.resolvedSystems.map((s) => s.id), ['b']);
    expect(merged.resolvedSystems.any((s) => s.tag == 'FIQ-30'), isFalse);
  });

  test('resumo vazio da nuvem não limpa o cadastro local', () {
    final local = _client([_sys('a', 'FIQ-30')]);
    final remote = _client(const []);

    final merged = absorbRemoteClient(local: local, remote: remote);

    expect(merged.resolvedSystems.map((s) => s.id), ['a']);
  });

  test('rebase: ilha apagada noutro aparelho some mesmo com rascunho local', () {
    final base = _client([
      _sys('a', 'FIQ-30'),
      _sys('b', 'FIQ-31'),
    ]);
    // Usuário só mudou o nome; não mexeu nas ilhas.
    final draft = base.copyWith(name: 'Cliente editado');
    final cloud = _client([_sys('b', 'FIQ-31')]);

    final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);

    expect(merged.name, 'Cliente editado');
    expect(merged.resolvedSystems.map((s) => s.id), ['b']);
    expect(merged.resolvedSystems.any((s) => s.tag == 'FIQ-30'), isFalse);
  });

  test('rebase: exclusão feita nesta tela continua apagada', () {
    final base = _client([
      _sys('a', 'FIQ-30'),
      _sys('b', 'FIQ-31'),
    ]);
    final draft = _client([_sys('b', 'FIQ-31')]);
    final cloud = _client([
      _sys('a', 'FIQ-30'),
      _sys('b', 'FIQ-31'),
      _sys('c', 'FIQ-32'),
    ]);

    final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);

    // a apagada aqui; c nova na nuvem entra.
    expect(merged.resolvedSystems.map((s) => s.id).toList()..sort(), [
      'b',
      'c',
    ]);
  });
}
