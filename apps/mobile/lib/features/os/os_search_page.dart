import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';

/// Pesquisa e reativação de OS — só Cleber.
class OsSearchPage extends StatefulWidget {
  const OsSearchPage({super.key});

  @override
  State<OsSearchPage> createState() => _OsSearchPageState();
}

class _OsSearchPageState extends State<OsSearchPage> {
  final _query = TextEditingController();
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    FieldStore.instance.sync();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await FieldStore.instance.sync();
    if (mounted) setState(() => _syncing = false);
  }

  List<SavedOs> _filtered(List<SavedOs> all) {
    final q = _query.text.trim().toLowerCase();
    final list = [...all]
      ..sort((a, b) {
        final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
        if (byStatus != 0) return byStatus;
        return b.createdAt.compareTo(a.createdAt);
      });
    if (q.isEmpty) return list;
    return [
      for (final os in list)
        if (_matches(os, q)) os,
    ];
  }

  int _statusRank(OsStatus status) {
    switch (status) {
      case OsStatus.servicoEncerrado:
        return 0;
      case OsStatus.emAndamento:
        return 1;
      case OsStatus.comTecnico:
        return 2;
      case OsStatus.rascunho:
        return 3;
      case OsStatus.encerrada:
        return 4;
    }
  }

  bool _matches(SavedOs os, String q) {
    final blob = [
      os.number,
      os.rdo.client,
      os.rdo.cnpj,
      os.rdo.site,
      os.technicianLabel,
      osStatusLabel(os.status),
    ].join(' ').toLowerCase();
    return blob.contains(q);
  }

  Future<void> _reactivate(SavedOs os) async {
    try {
      await FieldStore.instance.reopenOs(os.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'OS ${os.number} reativada. Os técnicos podem lançar RDO de novo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GsTheme.navy, content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    if (user?.canFinalizeAndReopenOs != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesquisar OS')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Só o Cleber pode pesquisar OS encerradas e reativá-las.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisar OS'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([FieldStore.instance, _query]),
        builder: (context, _) {
          final items = _filtered(FieldStore.instance.officeItems);
          final waiting = [
            for (final os in items)
              if (os.status == OsStatus.servicoEncerrado) os,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Busque por número, cliente, CNPJ ou técnico. Aqui você reativa OS e encerra de verdade as que o técnico já finalizou o serviço.',
                style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Pesquisar',
                  hintText: 'ex.: 044/26 ou nome do cliente',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
              if (waiting.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Aguardando seu encerramento (${waiting.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                for (final os in waiting) ...[
                  _SearchOsCard(
                    os: os,
                    highlight: true,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              OsHubPage(osId: os.id, officeMode: true),
                        ),
                      );
                    },
                    onReactivate: () => _reactivate(os),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 18),
              Text(
                items.isEmpty ? 'Nenhuma OS encontrada' : 'Todas (${items.length})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Nada com esse filtro. Toque em atualizar ou limpe a busca.',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  ),
                )
              else
                for (final os in items) ...[
                  if (os.status != OsStatus.servicoEncerrado ||
                      _query.text.trim().isNotEmpty) ...[
                    _SearchOsCard(
                      os: os,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OsHubPage(osId: os.id, officeMode: true),
                          ),
                        );
                      },
                      onReactivate: os.canReopenOs ? () => _reactivate(os) : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SearchOsCard extends StatelessWidget {
  const _SearchOsCard({
    required this.os,
    required this.onOpen,
    this.onReactivate,
    this.highlight = false,
  });

  final SavedOs os;
  final VoidCallback onOpen;
  final VoidCallback? onReactivate;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? const Color(0x14C4A35A) : Colors.white,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: highlight
                    ? GsTheme.brass
                    : os.status == OsStatus.encerrada
                        ? const Color(0xFF8A929A)
                        : GsTheme.navy,
                width: 5,
              ),
              top: const BorderSide(color: Color(0x331A2330)),
              right: const BorderSide(color: Color(0x331A2330)),
              bottom: const BorderSide(color: Color(0x331A2330)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'OS ${os.number}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                  fontSize: 18,
                ),
              ),
              if (os.rdo.client.isNotEmpty)
                Text(
                  os.rdo.client,
                  style: const TextStyle(fontSize: 15, color: GsTheme.navy),
                ),
              const SizedBox(height: 4),
              Text(
                [
                  if (os.technicianLabel.isNotEmpty) os.technicianLabel,
                  osStatusLabel(os.status),
                  '${os.rdos.length} RDO(s)',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C6570),
                ),
              ),
              if (onReactivate != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onReactivate,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Reativar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
