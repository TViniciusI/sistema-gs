import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/agenda/agenda_page.dart';
import 'package:gs_mobile/features/agenda/week_agenda_panel.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:gs_mobile/features/os/rdo_form_page.dart';
import 'package:gs_mobile/web/pwa_install.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/pwa_install_web.dart';
import 'package:gs_mobile/web/pwa_install_banner.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openList(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AgendaPage()));
  }

  void _openHub(BuildContext context, SavedOs os) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => OsHubPage(osId: os.id)));
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

  Future<void> _fillTodaysRdo(
    BuildContext context,
    List<SavedOs> fillable,
  ) async {
    final choices = rdoTodayOsChoices(fillable);
    SavedOs? os;
    if (choices.length == 1) {
      os = choices.first;
    } else {
      os = await showDialog<SavedOs>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Qual OS?'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in choices)
                    ListTile(
                      title: Text('OS ${item.number}'),
                      subtitle: Text(
                        [
                          if (item.rdo.client.isNotEmpty) item.rdo.client,
                          osStartLabel(item),
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.pop(dialogContext, item),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );
    }
    if (os == null || !context.mounted) return;
    final selected = os;
    final todayEntry = selected.rdoOnDay(DateTime.now());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RdoFormPage(os: selected, existing: todayEntry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final seeAll = user?.seesAllFieldOs == true;
    final firstName = (user?.name ?? 'técnico').split(' ').first;
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: Text(seeAll ? 'Área do técnico' : 'Agenda do técnico'),
        actions: [
          IconButton(
            tooltip: 'Atualizar agenda',
            onPressed: () => FieldStore.instance.sync(),
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'instalar') {
                showPwaInstallHelp(context);
                return;
              }
              if (value == 'sair') AuthSession.instance.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.name ?? 'Técnico'),
              ),
              if (PwaInstall.shouldOffer)
                const PopupMenuItem(
                  value: 'instalar',
                  child: Text('Instalar no celular'),
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
          final items = [
            for (final os in pending)
              if (seeAll || os.isAssignedToAny(viewerIds)) os,
          ];
          final query = _query.text.trim();
          final found = [
            for (final os in items)
              if (_matchesOs(os, query)) os,
          ];
          final open = [
            for (final os in found)
              if (os.status != OsStatus.encerrada) os,
          ];
          final rdoCount = [for (final os in found) ...os.rdos].length;
          final todayRdo = [
            for (final os in found)
              if (os.rdoOnDay(DateTime.now()) != null) os,
          ].length;
          final fillable = [
            for (final os in open)
              if (os.canFillRdo) os,
          ];
          final recent = found.take(6).toList();
          final searching = query.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Olá, $firstName',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                seeAll
                    ? 'Hoje, $today · OS da empresa. RDO, datas no adesivo e etiquetas desta área.'
                    : 'Hoje, $today · OS delegadas a você. O que você lançar aparece para o escritório.',
                style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 18),
              WeekAgendaPanel(
                key: const Key('week-agenda-tecnico'),
                onlyMine: !seeAll,
              ),
              const SizedBox(height: 18),
              if (seeAll || items.length > 6) ...[
                TextField(
                  key: const Key('tecnico-os-busca'),
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
              ],
              if (fillable.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () => _fillTodaysRdo(context, fillable),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 26),
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: Colors.black,
                  ),
                  label: const Text('Preencher RDO de hoje'),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      searching
                          ? 'OS encontradas (${found.length})'
                          : 'OS pendentes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openList(context),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    searching
                        ? 'Nenhuma OS com esse texto.'
                        : seeAll
                        ? 'Nenhuma OS pendente na empresa.\nQuando houver OS em aberto, ela aparece aqui.'
                        : 'Nenhuma OS pendente na sua agenda.\nQuando o escritório gerar e te delegar, ela aparece aqui.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                )
              else
                for (final os in recent)
                  _RecentOsTile(os: os, onOpen: () => _openHub(context, os)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'OS pendentes',
                      value: '${open.length}',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'RDO hoje',
                      value: '$todayRdo',
                      icon: Icons.today_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StatCard(
                label: 'RDOs lançados',
                value: '$rdoCount',
                icon: Icons.description_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GsTheme.navy, size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
          ),
        ],
      ),
    );
  }
}

class _RecentOsTile extends StatelessWidget {
  const _RecentOsTile({required this.os, required this.onOpen});

  final SavedOs os;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final client = os.rdo.client;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          title: Text(
            'OS ${os.number}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: GsTheme.navy,
            ),
          ),
          subtitle: Text(
            [
              if (client.isNotEmpty) client,
              if (os.technicianLabel.isNotEmpty) os.technicianLabel,
              osStartLabel(os),
              osStatusLabel(os.status),
              '${os.rdos.length} RDO(s)',
            ].join(' · '),
            style: const TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpen,
        ),
      ),
    );
  }
}
