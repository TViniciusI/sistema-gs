import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matchesOs(SavedOs os, String query) {
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
    return foldPersonKey(
      query,
    ).split(' ').where((word) => word.isNotEmpty).every(blob.contains);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final seeAll = user?.seesAllFieldOs == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(seeAll ? 'OS da empresa' : 'OS pendentes'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'sair') AuthSession.instance.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.name ?? 'Técnico'),
              ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: FieldStore.instance,
        builder: (context, _) {
          final viewerIds = user == null
              ? const <String>{}
              : assigneeKeysFor(user);
          final pending = FieldStore.instance.pendingItems;
          final base = [
            for (final os in pending)
              if (seeAll || os.isAssignedToAny(viewerIds)) os,
          ];
          final query = _query.text.trim();
          final items = [
            for (final os in base)
              if (_matchesOs(os, query)) os,
          ];
          final searching = query.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                seeAll
                    ? 'Todas as OS em aberto da empresa. Toque para RDO, datas no adesivo e etiquetas.'
                    : 'Só o que o escritório te mandou. A OS já vem com CNPJ, cliente e dados do RDO.',
                style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('agenda-os-busca'),
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
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    searching
                        ? 'Nenhuma OS com esse texto.'
                        : seeAll
                        ? 'Nenhuma OS pendente na empresa.'
                        : 'Nenhuma OS pendente.\nQuando o escritório gerar e te delegar, ela aparece aqui.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                )
              else ...[
                Text(
                  searching
                      ? 'Encontradas (${items.length})'
                      : 'Pendentes (${items.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 10),
                for (final os in items) ...[
                  _OsCard(os: os),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OsCard extends StatelessWidget {
  const _OsCard({required this.os});

  final SavedOs os;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => OsHubPage(osId: os.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: os.status == OsStatus.encerrada
                    ? GsTheme.brass
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
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              if (os.rdo.client.isNotEmpty)
                Text(
                  os.rdo.client,
                  style: const TextStyle(fontSize: 16, color: GsTheme.navy),
                ),
              if (os.rdo.site.isNotEmpty)
                Text(
                  os.rdo.site,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C6570),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                [
                  osStartLabel(os),
                  if (os.technicianLabel.isNotEmpty) os.technicianLabel,
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
