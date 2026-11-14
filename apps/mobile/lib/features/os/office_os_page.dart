import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/clients/clients_page.dart';
import 'package:gs_mobile/features/os/os_create_page.dart';
import 'package:gs_mobile/features/os/os_delete_actions.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:gs_mobile/features/os/os_search_page.dart';

class OfficeOsPage extends StatefulWidget {
  const OfficeOsPage({super.key});

  @override
  State<OfficeOsPage> createState() => _OfficeOsPageState();
}

class _OfficeOsPageState extends State<OfficeOsPage> {
  var _syncing = false;
  var _showClosed = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await FieldStore.instance.sync();
    await ClientStore.instance.sync();
    if (mounted) setState(() => _syncing = false);
  }

  bool _matches(SavedOs os, String query) {
    if (query.isEmpty) return true;
    final blob = foldPersonKey(
      [
        os.number,
        os.rdo.client,
        os.rdo.cnpj,
        os.rdo.cnpj.replaceAll(RegExp(r'\D'), ''),
        os.rdo.site,
        os.technicianLabel,
        osStatusLabel(os.status),
      ].join(' '),
    );
    return foldPersonKey(query)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .every(blob.contains);
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OsSearchPage()),
    );
  }

  List<Widget> _cards(List<SavedOs> list, bool canDelete) => [
    for (final os in list) ...[
      _OfficeOsCard(
        os: os,
        canDelete: canDelete,
        onDelete: () => deleteOsWithConfirm(context, os),
      ),
      const SizedBox(height: 10),
    ],
  ];

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: GsTheme.navy,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final canDelete = AuthSession.instance.user?.canGenerateOs == true;
    final canReopen = AuthSession.instance.user?.canFinalizeAndReopenOs == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar OS'),
        actions: [
          IconButton(
            tooltip: 'Atualizar OS da equipe',
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
        animation: FieldStore.instance,
        builder: (context, _) {
          final items = [...FieldStore.instance.officeItems]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final query = _query.text.trim();
          final found = [
            for (final os in items)
              if (_matches(os, query)) os,
          ];
          final open = [
            for (final os in found)
              if (os.status != OsStatus.encerrada) os,
          ];
          final closed = [
            for (final os in found)
              if (os.status == OsStatus.encerrada) os,
          ];
          final searching = query.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'OS, RDO, certificados e anexos ficam na planilha da empresa. O escritório vê o que cada técnico lançou — não só o Cleber, a equipe inteira.',
                style: TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('nova-os'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OsCreatePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 26),
                style: FilledButton.styleFrom(
                  backgroundColor: GsTheme.brass,
                  foregroundColor: Colors.black,
                ),
                label: const Text('Nova OS'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClientsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.apartment_outlined),
                label: const Text('Clientes cadastrados'),
              ),
              const SizedBox(height: 28),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Nenhuma OS ainda.\nGere a OS, delegue os técnicos e envie à agenda. O que cada um lançar aparece aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                )
              else ...[
                TextField(
                  key: const Key('office-os-busca'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar OS',
                    hintText: 'Nº, cliente, CNPJ, local ou técnico',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searching
                        ? IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_query.clear),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(
                  searching
                      ? 'Em aberto (${open.length})'
                      : 'OS em aberto (${open.length})',
                ),
                if (open.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      searching
                          ? 'Nenhuma OS em aberto com esse texto.'
                          : 'Nenhuma OS em aberto.',
                      style: const TextStyle(color: Color(0xFF5C6570)),
                    ),
                  ),
                ..._cards(open, canDelete),
                if (closed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (searching || _showClosed) ...[
                    _sectionTitle('Encerradas (${closed.length})'),
                    ..._cards(closed, canDelete),
                    if (!searching)
                      TextButton(
                        onPressed: () => setState(() => _showClosed = false),
                        child: const Text('Esconder encerradas'),
                      ),
                  ] else
                    OutlinedButton.icon(
                      key: const Key('office-os-ver-encerradas'),
                      onPressed: () => setState(() => _showClosed = true),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text('Ver encerradas (${closed.length})'),
                    ),
                  if (canReopen) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _openSearch,
                      icon: const Icon(Icons.replay),
                      label: const Text('Reativar OS encerrada'),
                    ),
                  ],
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OfficeOsCard extends StatelessWidget {
  const _OfficeOsCard({
    required this.os,
    required this.canDelete,
    required this.onDelete,
  });

  final SavedOs os;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OsHubPage(osId: os.id, officeMode: true),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: os.status == OsStatus.encerrada
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'OS ${os.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      key: Key('os-delete-${os.id}'),
                      tooltip: 'Apagar OS',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: const Color(0xFF8A3B3B),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (os.rdo.client.isNotEmpty)
                Text(
                  os.rdo.client,
                  style: const TextStyle(fontSize: 16, color: GsTheme.navy),
                ),
              if (os.rdo.cnpj.isNotEmpty)
                Text(
                  'CNPJ ${os.rdo.cnpj}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
                ),
              if (os.rdo.site.isNotEmpty)
                Text(
                  os.rdo.site,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
                ),
              const SizedBox(height: 8),
              Text(
                [
                  osStartLabel(os),
                  os.technicianLabel.isEmpty
                      ? 'Sem técnico'
                      : os.technicianLabel,
                  osStatusLabel(os.status),
                  '${os.rdos.length} RDO(s)',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
