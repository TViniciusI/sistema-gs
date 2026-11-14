import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/technician_cargo_field.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/staff_digital_cert.dart';
import 'package:gs_mobile/features/staff/hours_analyze_page.dart';
import 'package:gs_mobile/features/staff/hours_report_panel.dart';
import 'package:gs_mobile/features/staff/staff_docs_page.dart';

enum _RosterFilter { all, pending, technicians, office, inactive, refused }

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  var _busyEmail = '';
  String? _hoursEmail;
  var _syncing = true;
  var _filter = _RosterFilter.all;
  final _hoursKey = GlobalKey();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) setState(() {});
    });
    StaffStore.instance.refresh().whenComplete(() {
      if (mounted) setState(() => _syncing = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await StaffStore.instance.refresh();
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _run(String email, Future<AccountResult> Function() action) async {
    setState(() => _busyEmail = email);
    final result = await action();
    await StaffStore.instance.applyResult(result);
    if (!result.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(result.error ?? 'Não foi possível atualizar.'),
        ),
      );
    }
    if (mounted) setState(() => _busyEmail = '');
  }

  /// Técnico sempre leva Meus documentos (RH / holerite).
  Future<void> _makeTechnician(RemoteAccount user) async {
    setState(() => _busyEmail = user.email);
    final role = await AccountApi.instance.setRole(
      email: user.email,
      role: 'tecnico',
    );
    await StaffStore.instance.applyResult(role);
    if (!role.ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text(role.error ?? 'Não foi possível atualizar o papel.'),
          ),
        );
        setState(() => _busyEmail = '');
      }
      return;
    }
    const perms = 'tecnico,documentos';
    await StaffStore.instance.patchPermissions(user.email, perms);
    final result = await AccountApi.instance.setPermissions(
      email: user.email,
      permissions: perms,
    );
    if (result.ok) {
      await StaffStore.instance.applyResult(result);
    } else if (mounted && (result.error ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            isUnsupportedSheetAction(result.error)
                ? 'Papel técnico ok. A planilha ainda não grava permissões — '
                      'cole o login_gate.gs e publique Nova versão.'
                : result.error!,
          ),
        ),
      );
    }
    if (mounted) {
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text(
              'Técnico com Meus documentos. Peça para sair e entrar de novo.',
            ),
          ),
        );
      }
      setState(() => _busyEmail = '');
    }
  }

  Future<void> _saveCargo(RemoteAccount user, String cargo) async {
    setState(() => _busyEmail = user.email);
    await StaffStore.instance.patchCargo(user.email, cargo);
    final result = await AccountApi.instance.setCargo(
      email: user.email,
      cargo: cargo,
    );
    if (result.ok) {
      await StaffStore.instance.applyResult(result);
    } else if (mounted && (result.error ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            isUnsupportedSheetAction(result.error)
                ? 'Cargo salvo neste aparelho. Cole o script novo na planilha para gravar na equipe.'
                : result.error!,
          ),
        ),
      );
    }
    if (mounted) {
      if (result.ok || isUnsupportedSheetAction(result.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text('Cargo atualizado. Esse texto sai no RDO.'),
          ),
        );
      }
      setState(() => _busyEmail = '');
    }
  }

  Future<void> _saveCalibration(
    RemoteAccount user,
    CalibrationAccess access,
  ) async {
    setState(() => _busyEmail = user.email);
    await StaffStore.instance.patchCalibrationAccess(user.email, access);
    final result = await AccountApi.instance.setCalibrationAccess(
      email: user.email,
      access: access,
    );
    if (result.ok) {
      await StaffStore.instance.applyResult(result);
    } else if (mounted && (result.error ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            isUnsupportedSheetAction(result.error)
                ? 'Acesso de calibração salvo neste aparelho. Cole o script novo na planilha para gravar na equipe.'
                : result.error!,
          ),
        ),
      );
    }
    if (mounted) {
      if (result.ok || isUnsupportedSheetAction(result.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text(
              'Acesso de calibração atualizado. Técnico sem emissão só envia para análise.',
            ),
          ),
        );
      }
      setState(() => _busyEmail = '');
    }
  }

  Future<void> _savePermissions(
    RemoteAccount user,
    String permissions,
  ) async {
    setState(() => _busyEmail = user.email);
    await StaffStore.instance.patchPermissions(user.email, permissions);
    final result = await AccountApi.instance.setPermissions(
      email: user.email,
      permissions: permissions,
    );
    if (result.ok) {
      await StaffStore.instance.applyResult(result);
    } else if (mounted && (result.error ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            isUnsupportedSheetAction(result.error)
                ? 'A planilha ainda não grava permissões. Cole o login_gate.gs novo e publique Nova versão; senão o técnico continua com acesso amplo.'
                : result.error!,
          ),
        ),
      );
    }
    if (mounted) {
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text(
              'Permissões atualizadas. Peça ao técnico para sair e entrar de novo.',
            ),
          ),
        );
      }
      setState(() => _busyEmail = '');
    }
  }

  Future<void> _approveAdminWithDialog(RemoteAccount user) async {
    final perms = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AdminApprovalSheet(user: user),
    );
    if (perms != null) {
      await _run(
        user.email,
        () => AccountApi.instance.decide(
          email: user.email,
          status: 'aprovado',
          role: 'admin',
          permissions: perms,
        ),
      );
    }
  }

  List<RemoteAccount> _sortedDirectory(StaffStore store) {
    final list = [...store.directory];
    list.sort((a, b) {
      final byRank = _recordRank(a).compareTo(_recordRank(b));
      if (byRank != 0) return byRank;
      return staffRecordName(a).toLowerCase().compareTo(
        staffRecordName(b).toLowerCase(),
      );
    });
    return list;
  }

  List<RemoteAccount> _visible(StaffStore store) {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final user in _sortedDirectory(store))
        if (_matchesFilter(user) && _matchesQuery(user, query)) user,
    ];
  }

  bool _matchesFilter(RemoteAccount user) {
    switch (_filter) {
      case _RosterFilter.all:
        return true;
      case _RosterFilter.pending:
        return user.status == 'pendente';
      case _RosterFilter.technicians:
        return user.status == 'aprovado' && isStaffTechnician(user);
      case _RosterFilter.office:
        return user.status == 'aprovado' && isStaffOffice(user);
      case _RosterFilter.inactive:
        return user.status == 'aprovado' && !user.active;
      case _RosterFilter.refused:
        return user.status == 'recusado';
    }
  }

  bool _matchesQuery(RemoteAccount user, String query) {
    if (query.isEmpty) return true;
    return [
      staffRecordName(user),
      user.login,
      user.email,
      user.phone,
      user.cargo,
      user.funcao,
      staffSectorLabel(user),
      staffStatusLabel(user),
    ].any((value) => value.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funcionários'),
        actions: [
          IconButton(
            tooltip: 'Atualizar equipe',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GsTheme.paper,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: StaffStore.instance,
        builder: (context, _) {
          final store = StaffStore.instance;
          final visible = _visible(store);
          final office = [
            for (final user in store.employees)
              if (user.active && isStaffOffice(user)) user,
          ];
          final inactive = [
            for (final user in store.employees)
              if (!user.active) user,
          ];
          return ListView(
            key: const Key('staff-list'),
            cacheExtent: 1200,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Cadastro da equipe',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'O RH vê todos os registros: nome, login, e-mail, telefone, setor, cargo e situação. Busque, filtre e abra as horas do técnico.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Color(0xFF5C6570),
                ),
              ),
              if (store.lastError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF7E8E8),
                  child: Text(
                    store.lastError!,
                    style: const TextStyle(color: Color(0xFF8B2E2E), height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatCard(
                    label: 'Equipe',
                    count: store.directory.length,
                    selected: _filter == _RosterFilter.all,
                    onTap: () => setState(() => _filter = _RosterFilter.all),
                  ),
                  _StatCard(
                    label: 'Técnicos',
                    count: store.technicianAccounts.length,
                    selected: _filter == _RosterFilter.technicians,
                    onTap: () =>
                        setState(() => _filter = _RosterFilter.technicians),
                  ),
                  _StatCard(
                    label: 'Administrativo',
                    count: office.length,
                    selected: _filter == _RosterFilter.office,
                    onTap: () => setState(() => _filter = _RosterFilter.office),
                  ),
                  _StatCard(
                    label: 'Pendentes',
                    count: store.pending.length,
                    selected: _filter == _RosterFilter.pending,
                    accent: store.pending.isNotEmpty,
                    onTap: () => setState(() => _filter = _RosterFilter.pending),
                  ),
                  _StatCard(
                    label: 'Desligados',
                    count: inactive.length,
                    selected: _filter == _RosterFilter.inactive,
                    onTap: () =>
                        setState(() => _filter = _RosterFilter.inactive),
                  ),
                  if (store.rejected.isNotEmpty)
                    _StatCard(
                      label: 'Recusados',
                      count: store.rejected.length,
                      selected: _filter == _RosterFilter.refused,
                      onTap: () =>
                          setState(() => _filter = _RosterFilter.refused),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('staff-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Buscar na equipe',
                  hintText: 'Nome, login, e-mail, telefone ou cargo',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in _filterOptions) ...[
                      ChoiceChip(
                        label: Text(option.label),
                        selected: _filter == option.filter,
                        selectedColor: GsTheme.brass,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _filter == option.filter
                              ? GsTheme.navy
                              : const Color(0xFF5C6570),
                        ),
                        onSelected: (_) =>
                            setState(() => _filter = option.filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (store.directory.isEmpty)
                const Text(
                  'Nenhum funcionário cadastrado ainda. Quem criar conta aparece aqui para o RH confirmar.',
                  style: TextStyle(color: Color(0xFF5C6570), height: 1.4),
                )
              else ...[
                Text(
                  visible.isEmpty
                      ? 'Nenhum registro neste filtro.'
                      : '${visible.length} registro${visible.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 10),
                if (visible.isNotEmpty)
                  LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final cards = [
                      for (final user in visible)
                        _StaffCard(
                          user: user,
                          busy: _busyEmail == user.email,
                          pending: user.status == 'pendente',
                          onSaveCargo: user.status == 'aprovado'
                              ? (cargo) => _saveCargo(user, cargo)
                              : null,
                          onSaveCalibration:
                              user.status == 'aprovado' &&
                                      !calibrationAccessLocked(
                                        email: user.email,
                                        login: user.login,
                                      )
                              ? (access) => _saveCalibration(user, access)
                              : null,
                          onSavePermissions:
                              user.status == 'aprovado' &&
                                      !_isOwner(user) &&
                                      user.role != 'dev'
                              ? (perms) => _savePermissions(user, perms)
                              : null,
                          onAnalyzeHours: user.status == 'aprovado' &&
                                  user.active
                              ? () => _analyzeHours(user)
                              : null,
                          onDocuments: user.status == 'aprovado'
                              ? () => _openDocuments(user)
                              : null,
                          onApproveAdmin: user.status == 'pendente'
                              ? () => _approveAdminWithDialog(user)
                              : null,
                          onApproveTech: user.status == 'pendente'
                              ? () => _run(
                                    user.email,
                                    () => AccountApi.instance.decide(
                                      email: user.email,
                                      status: 'aprovado',
                                      role: 'tecnico',
                                      permissions: 'tecnico,documentos',
                                    ),
                                  )
                              : null,
                          onReject: user.status == 'pendente'
                              ? () => _run(
                                    user.email,
                                    () => AccountApi.instance.decide(
                                      email: user.email,
                                      status: 'recusado',
                                      role: user.role,
                                    ),
                                  )
                              : null,
                          onMakeAdmin:
                              user.status != 'aprovado' ||
                                  user.role == 'dev' ||
                                  _isOwner(user)
                              ? null
                              : () => _run(
                                  user.email,
                                  () => AccountApi.instance.setRole(
                                    email: user.email,
                                    role: 'admin',
                                  ),
                                ),
                          onMakeTech:
                              user.status != 'aprovado' ||
                                  user.role == 'dev' ||
                                  _isOwner(user)
                              ? null
                              : () => _makeTechnician(user),
                          onToggleActive:
                              user.status != 'aprovado' ||
                                  user.role == 'dev' ||
                                  _isOwner(user)
                              ? null
                              : () => _run(
                                  user.email,
                                  () => AccountApi.instance.setActive(
                                    email: user.email,
                                    active: !user.active,
                                  ),
                                ),
                        ),
                    ];
                    if (!wide) {
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i < cards.length - 1) const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final card in cards)
                          SizedBox(width: cardWidth, child: card),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              HoursReportPanel(
                key: _hoursKey,
                selectedEmail: _hoursEmail,
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isOwner(RemoteAccount user) =>
      isCompanyOwnerIdentity(email: user.email, login: user.login);

  void _analyzeHours(RemoteAccount user) {
    setState(() => _hoursEmail = user.email);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HoursAnalyzePage(email: user.email),
      ),
    );
  }

  void _openDocuments(RemoteAccount user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StaffDocsPage(user: user),
      ),
    );
  }
}

const _filterOptions = [
  (filter: _RosterFilter.all, label: 'Todos'),
  (filter: _RosterFilter.pending, label: 'Pendentes'),
  (filter: _RosterFilter.technicians, label: 'Técnicos'),
  (filter: _RosterFilter.office, label: 'Administrativo'),
  (filter: _RosterFilter.inactive, label: 'Desligados'),
  (filter: _RosterFilter.refused, label: 'Recusados'),
];

int _recordRank(RemoteAccount user) {
  if (user.status == 'pendente') return 0;
  if (user.status == 'aprovado' && user.active) return 1;
  if (user.status == 'aprovado') return 2;
  return 3;
}

String staffRecordName(RemoteAccount user) {
  final name = user.name.trim();
  return name.isEmpty ? user.login : name;
}

bool isStaffTechnician(RemoteAccount user) {
  return user.role == 'tecnico' ||
      user.role == 'dev' ||
      user.role == 'ambos' ||
      isCleberIdentity(email: user.email, login: user.login);
}

bool isStaffOffice(RemoteAccount user) {
  return user.role == 'admin' ||
      user.role == 'ambos' ||
      user.role == 'dev' ||
      isPrincipalIdentity(email: user.email, login: user.login) ||
      isCleberIdentity(email: user.email, login: user.login);
}

String staffSectorLabel(RemoteAccount user) {
  if (isPrincipalIdentity(email: user.email, login: user.login)) {
    return 'Acesso principal · GS Soluções';
  }
  if (isCleberIdentity(email: user.email, login: user.login) ||
      user.role == 'ambos') {
    return 'Técnico e administrativo';
  }
  if (user.role == 'admin') return 'Administrativo';
  if (user.role == 'dev') return 'Desenvolvedor';
  return 'Técnico';
}

String staffStatusLabel(RemoteAccount user) {
  if (user.status == 'pendente') return 'Pendente';
  if (user.status == 'recusado') return 'Recusado';
  if (!user.active) return 'Desligado';
  return 'Ativo';
}

String staffInitials(RemoteAccount user) {
  final name = staffRecordName(user).trim();
  if (name.isEmpty) return '?';
  final parts = [
    for (final part in name.split(RegExp(r'\s+')))
      if (part.isNotEmpty) part,
  ];
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = selected || accent;
    return Material(
      color: highlight ? const Color(0xFFF7F1E1) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 118,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: highlight ? GsTheme.brass : const Color(0x331A2330),
                width: highlight ? 5 : 1,
              ),
              top: const BorderSide(color: Color(0x331A2330)),
              right: const BorderSide(color: Color(0x331A2330)),
              bottom: const BorderSide(color: Color(0x331A2330)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C6570),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatefulWidget {
  const _StaffCard({
    required this.user,
    required this.busy,
    required this.pending,
    this.onApproveAdmin,
    this.onApproveTech,
    this.onReject,
    this.onMakeAdmin,
    this.onMakeTech,
    this.onToggleActive,
    this.onSaveCargo,
    this.onSaveCalibration,
    this.onSavePermissions,
    this.onAnalyzeHours,
    this.onDocuments,
  });

  final RemoteAccount user;
  final bool busy;
  final bool pending;
  final VoidCallback? onApproveAdmin;
  final VoidCallback? onApproveTech;
  final VoidCallback? onReject;
  final VoidCallback? onMakeAdmin;
  final VoidCallback? onMakeTech;
  final VoidCallback? onToggleActive;
  final ValueChanged<String>? onSaveCargo;
  final ValueChanged<CalibrationAccess>? onSaveCalibration;
  final ValueChanged<String>? onSavePermissions;
  final VoidCallback? onAnalyzeHours;
  final VoidCallback? onDocuments;

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  late final TextEditingController _cargo;
  var _editing = false;
  late var _isGeneralAccess = widget.user.isGeneralAccess;
  late var _selectedPerms = Set<String>.from(widget.user.permissionList);
  var _hasDigitalCert = false;

  RemoteAccount get user => widget.user;

  @override
  void initState() {
    super.initState();
    _cargo = TextEditingController(text: user.cargo);
    _editing = widget.pending;
    loadStaffDigitalCertificates().then((_) {
      if (!mounted) return;
      setState(() {
        _hasDigitalCert = staffEmailHasDigitalCertificate(user.email);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _StaffCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.cargo != user.cargo && _cargo.text != user.cargo) {
      _cargo.text = user.cargo;
    }
    if (oldWidget.user.permissions != user.permissions) {
      _isGeneralAccess = user.isGeneralAccess;
      _selectedPerms = Set<String>.from(user.permissionList);
    }
  }

  @override
  void dispose() {
    _cargo.dispose();
    super.dispose();
  }

  Color get _avatarColor {
    if (user.status == 'pendente') return GsTheme.brass;
    if (user.status == 'recusado' || !user.active) {
      return const Color(0xFF8A9099);
    }
    return GsTheme.navy;
  }

  ButtonStyle get _compactFill => FilledButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );

  ButtonStyle get _compactOutline => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );

  @override
  Widget build(BuildContext context) {
    final status = staffStatusLabel(user);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: user.status == 'pendente'
            ? const Color(0xFFFFF8E8)
            : Colors.white,
        border: Border(
          left: BorderSide(
            color: user.status == 'pendente'
                ? GsTheme.brass
                : const Color(0x331A2330),
            width: user.status == 'pendente' ? 5 : 1,
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
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColor,
                foregroundColor: Colors.white,
                child: Text(
                  staffInitials(user),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffRecordName(user),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GsTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.cargo.trim().isEmpty
                          ? staffSectorLabel(user)
                          : user.cargo.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: status, status: user),
            ],
          ),
          const SizedBox(height: 14),
          _RecordRow(label: 'Login', value: user.login),
          _RecordRow(label: 'E-mail', value: user.email),
          _RecordRow(label: 'Telefone', value: user.phone),
          _RecordRow(label: 'Setor', value: staffSectorLabel(user)),
          _RecordRow(label: 'Cargo', value: user.cargo),
          _RecordRow(
            label: 'Calibração',
            value: calibrationAccessLabel(
              resolvedCalibrationAccess(
                stored: user.calibrationAccess,
                email: user.email,
                login: user.login,
              ),
            ),
          ),
          _RecordRow(label: 'Permissões', value: user.permissionsSummary),
          if (user.funcao.trim().isNotEmpty)
            _RecordRow(label: 'Função', value: user.funcao),
          _RecordRow(label: 'Situação', value: status),
          const SizedBox(height: 8),
          if (widget.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else ...[
            if (widget.onAnalyzeHours != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: widget.onAnalyzeHours,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  style: _compactFill.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(GsTheme.navy),
                  ),
                  label: const Text('Analisar horas'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.onDocuments != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: widget.onDocuments,
                  icon: const Icon(Icons.attach_file_outlined, size: 18),
                  style: _compactOutline,
                  label: const Text('Documentos e assinatura'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.pending) ...[
              FilledButton(
                onPressed: widget.onApproveTech,
                style: FilledButton.styleFrom(
                  backgroundColor: GsTheme.brass,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Aprovar como técnico'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onApproveAdmin,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Aprovar como administrativo...'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onReject,
                child: const Text('Recusar'),
              ),
            ] else if (user.status == 'aprovado') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _editing = !_editing),
                  child: Text(
                    _editing ? 'Fechar edição' : 'Editar cargo e acesso',
                  ),
                ),
              ),
              if (_editing) ...[
                TechnicianCargoField(
                  controller: _cargo,
                  label: 'Cargo no RDO',
                  helperText:
                      'Técnico ou Assistente Técnico em Instrumentação Industrial.',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: widget.onSaveCargo == null
                        ? null
                        : () => widget.onSaveCargo!(_cargo.text.trim()),
                    style: _compactOutline,
                    child: const Text('Salvar cargo'),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tem certificado digital ICP-Brasil',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GsTheme.navy,
                    ),
                  ),
                  subtitle: const Text(
                    'Ligado: certificado assinado deixa espaço para a digital. '
                    'Desligado: usa assinatura eletrônica até chegar o certificado.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                  ),
                  value: _hasDigitalCert,
                  onChanged: widget.busy
                      ? null
                      : (value) async {
                          await setStaffDigitalCertificate(user.email, value);
                          if (!mounted) return;
                          setState(() => _hasDigitalCert = value);
                        },
                ),
                const SizedBox(height: 12),
                if (calibrationAccessLocked(
                  email: user.email,
                  login: user.login,
                ))
                  const Text(
                    'Esta conta sempre pode emitir certificado.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                  )
                else
                  DropdownButtonFormField<CalibrationAccess>(
                    key: const Key('staff-calibracao-acesso'),
                    initialValue: user.calibrationAccess,
                    decoration: const InputDecoration(
                      labelText: 'Calibração',
                      isDense: true,
                    ),
                    items: [
                      for (final access in CalibrationAccess.values)
                        DropdownMenuItem(
                          value: access,
                          child: Text(calibrationAccessLabel(access)),
                        ),
                    ],
                    onChanged: widget.onSaveCalibration == null
                        ? null
                        : (value) {
                            if (value != null) {
                              widget.onSaveCalibration!(value);
                            }
                          },
                  ),
                if (widget.onSavePermissions != null) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Permissões no App:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Acesso Geral'),
                        selected: _isGeneralAccess,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _isGeneralAccess = true;
                              _selectedPerms =
                                  Set<String>.from(staffModuleLabels.keys);
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Personalizado (Item a Item)'),
                        selected: !_isGeneralAccess,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _isGeneralAccess = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (!_isGeneralAccess) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Selecione os módulos liberados para este usuário:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in staffModuleLabels.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: _selectedPerms.contains(entry.key),
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _selectedPerms.add(entry.key);
                                } else {
                                  _selectedPerms.remove(entry.key);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () {
                        final permsString = _isGeneralAccess
                            ? 'geral'
                            : _selectedPerms.join(',');
                        widget.onSavePermissions!(permsString);
                      },
                      style: _compactOutline,
                      child: const Text('Salvar permissões'),
                    ),
                  ),
                ],
                if (widget.onMakeTech != null ||
                    widget.onMakeAdmin != null ||
                    widget.onToggleActive != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onMakeTech != null)
                        OutlinedButton(
                          onPressed: widget.onMakeTech,
                          style: _compactOutline,
                          child: const Text('Setor: técnico'),
                        ),
                      if (widget.onMakeAdmin != null)
                        OutlinedButton(
                          onPressed: widget.onMakeAdmin,
                          style: _compactOutline,
                          child: const Text('Setor: administrativo'),
                        ),
                      if (widget.onToggleActive != null)
                        TextButton(
                          onPressed: widget.onToggleActive,
                          child: Text(
                            user.active ? 'Desligar acesso' : 'Ligar acesso',
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'O setor deste acesso é fixo. O cargo do RDO pode ser editado acima.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                  ),
                ],
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5C6570),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value.trim(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.3,
                color: GsTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final RemoteAccount status;

  @override
  Widget build(BuildContext context) {
    final pending = status.status == 'pendente';
    final off = status.status == 'recusado' || !status.active;
    final background = pending
        ? GsTheme.brass
        : off
        ? const Color(0xFFE8E4DC)
        : GsTheme.navy;
    final color = pending || !off ? GsTheme.navy : const Color(0xFF5C6570);
    final fg = pending
        ? GsTheme.navy
        : off
        ? color
        : GsTheme.paper;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: background,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _AdminApprovalSheet extends StatefulWidget {
  const _AdminApprovalSheet({required this.user});

  final RemoteAccount user;

  @override
  State<_AdminApprovalSheet> createState() => _AdminApprovalSheetState();
}

class _AdminApprovalSheetState extends State<_AdminApprovalSheet> {
  var _isGeneral = true;
  final _selected = Set<String>.from(staffModuleLabels.keys);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aprovar ${staffRecordName(widget.user)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GsTheme.navy,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Defina o nível de acesso administrativo no app:',
              style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Acesso Geral (Tudo)'),
                  selected: _isGeneral,
                  onSelected: (sel) {
                    if (sel) setState(() => _isGeneral = true);
                  },
                ),
                ChoiceChip(
                  label: const Text('Personalizar Itens'),
                  selected: !_isGeneral,
                  onSelected: (sel) {
                    if (sel) setState(() => _isGeneral = false);
                  },
                ),
              ],
            ),
            if (!_isGeneral) ...[
              const SizedBox(height: 12),
              const Text(
                'Módulos liberados:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in staffModuleLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _selected.contains(entry.key),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selected.add(entry.key);
                          } else {
                            _selected.remove(entry.key);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final result = _isGeneral ? 'geral' : _selected.join(',');
                Navigator.of(context).pop(result);
              },
              style: FilledButton.styleFrom(
                backgroundColor: GsTheme.navy,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Confirmar Aprovação'),
            ),
          ],
        ),
      ),
    );
  }
}
