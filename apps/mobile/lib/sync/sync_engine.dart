/// Fila de sincronização offline-first.
///
/// MVP: o app ainda fala direto com a API quando há rede.
/// Próximo passo: Drift + outbox (mutações com client_mutation_id).
class SyncEngine {
  const SyncEngine();

  Future<void> pull() async {}

  Future<void> push() async {}
}
