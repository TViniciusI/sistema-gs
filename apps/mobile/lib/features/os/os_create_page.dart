import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/app_date_picker.dart';
import 'package:gs_mobile/core/search_pick_sheet.dart';
import 'package:gs_mobile/core/technician_cargo_field.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/clients/catalog_review_page.dart';
import 'package:gs_mobile/features/os/calibration_slots_group.dart';
import 'package:gs_mobile/features/os/os_calibration_slot_edit_sheet.dart';

class OsCreatePage extends StatefulWidget {
  const OsCreatePage({super.key, this.existing});

  final SavedOs? existing;

  @override
  State<OsCreatePage> createState() => _OsCreatePageState();
}

class _OsCreatePageState extends State<OsCreatePage> {
  late final TextEditingController _number;
  late final TextEditingController _client;
  late final TextEditingController _site;
  late final TextEditingController _cnpj;
  late final TextEditingController _system;
  late final TextEditingController _service;
  late final TextEditingController _techCargo;
  late final TextEditingController _baseName;
  late final TextEditingController _baseCargo;
  late final TextEditingController _baseEmail;
  late final TextEditingController _basePhone;
  final _selectedTechEmails = LinkedHashSet<String>();
  final _techFuncoes = <String, String>{};
  final _techCargos = <String, String>{};
  var _baseContacts = <ClientBaseContact>[];
  String? _selectedClientId;
  OsServiceKind? _serviceKind;
  var _busy = false;
  late DateTime _startsAt;
  var _hasCalibration = false;
  late List<OsCalibrationSlot> _calibrationSlots;

  bool get _alreadySent =>
      widget.existing != null && widget.existing!.status != OsStatus.rascunho;

  @override
  void initState() {
    super.initState();
    StaffStore.instance.refresh();
    CalibrationStore.instance.load();
    final existing = widget.existing;
    final header = existing?.rdo ?? const RdoData();
    _number = TextEditingController(text: existing?.number ?? '');
    final today = DateTime.now();
    _startsAt =
        existing?.startDay ?? DateTime(today.year, today.month, today.day);
    _client = TextEditingController(text: header.client);
    _site = TextEditingController(text: header.site);
    _cnpj = TextEditingController(text: header.cnpj);
    _system = TextEditingController(text: header.systemType);
    _service = TextEditingController(text: header.service);
    _techCargo = TextEditingController(
      text: _defaultTechnicianCargo(header.technicianCargo),
    );
    _baseName = TextEditingController(text: header.baseName);
    _baseCargo = TextEditingController(text: header.baseCargo);
    _baseEmail = TextEditingController(text: header.baseEmail);
    _basePhone = TextEditingController(text: header.basePhone);
    _baseContacts = [...header.resolvedBaseContacts];
    if (_baseContacts.isEmpty && header.baseName.trim().isNotEmpty) {
      _baseContacts = [
        ClientBaseContact(
          name: header.baseName,
          cargo: header.baseCargo,
          email: header.baseEmail,
          phone: header.basePhone,
        ),
      ];
    }
    _calibrationSlots = dedupeCalibrationSlotsByCertificateNumber([
      ...(existing?.calibrationSlots ?? const []),
    ]);
    _hasCalibration = _calibrationSlots.isNotEmpty;
    _serviceKind = inferOsServiceKind(header.service);
    if (existing != null) {
      final matched = ClientStore.instance.findMatch(
        cnpj: header.cnpj,
        name: header.client,
      );
      _selectedClientId = matched?.id;
    }
    if (existing != null) {
      for (final email in existing.assigneeEmails) {
        final value = email.trim().toLowerCase();
        if (value.isNotEmpty) _selectedTechEmails.add(value);
      }
      _techFuncoes.addAll(header.technicianFuncoes);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _client.dispose();
    _site.dispose();
    _cnpj.dispose();
    _system.dispose();
    _service.dispose();
    _techCargo.dispose();
    _baseName.dispose();
    _baseCargo.dispose();
    _baseEmail.dispose();
    _basePhone.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  List<AppUser> get _selectedTechnicians {
    final selected = <AppUser>[];
    for (final key in _selectedTechEmails) {
      for (final user in fieldTechnicians) {
        if (!_matchesSelectionKey(user, key)) continue;
        if (selected.any((item) => sameFieldTechnician(item, user))) continue;
        selected.add(user);
        break;
      }
    }
    return selected;
  }

  bool _matchesSelectionKey(AppUser user, String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    final keys = technicianIdentityKeys(user);
    if (keys.contains(value)) return true;
    return value.contains('@') && keys.contains(value.split('@').first);
  }

  bool _isSelectedTechnician(AppUser user) {
    final keys = technicianIdentityKeys(user);
    for (final selected in _selectedTechEmails) {
      final value = selected.trim().toLowerCase();
      if (value.isEmpty) continue;
      if (keys.contains(value)) return true;
      if (value.contains('@') && keys.contains(value.split('@').first)) {
        return true;
      }
    }
    return false;
  }

  String _funcaoId(AppUser user) {
    final key = personFirstKey(user.name);
    if (key.isNotEmpty) return key;
    return user.login.trim().toLowerCase();
  }

  String _funcaoFor(AppUser user) {
    final stored = _techFuncoes[_funcaoId(user)]?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    if (_selectedTechnicians.isNotEmpty &&
        sameFieldTechnician(user, _selectedTechnicians.first)) {
      return 'Responsável técnico';
    }
    return 'Suporte Técnico';
  }

  void _setFuncao(AppUser user, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() => _techFuncoes[_funcaoId(user)] = trimmed);
  }

  String _cargoFor(AppUser user) {
    final edited = _techCargos[_funcaoId(user)]?.trim() ?? '';
    if (edited.isNotEmpty) return edited;
    if (user.cargo.trim().isNotEmpty) return user.cargo.trim();
    final stored =
        widget.existing?.rdo.technicianCargos[personFirstKey(user.name)]
            ?.trim() ??
        '';
    if (stored.isNotEmpty) return stored;
    return _defaultTechnicianCargo(_techCargo.text);
  }

  void _setCargo(AppUser user, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() => _techCargos[_funcaoId(user)] = trimmed);
  }

  Future<void> _editCargo(AppUser user) async {
    final controller = TextEditingController(text: _cargoFor(user));
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cargo de ${user.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cada técnico tem o próprio cargo no RDO, conforme o nível no quadro da empresa.',
                style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 16),
              TechnicianCargoField(
                controller: controller,
                label: 'Cargo',
                helperText:
                    'Técnico ou Assistente Técnico em Instrumentação Industrial.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: GsTheme.brass,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Salvar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (chosen == null || chosen.trim().isEmpty || !mounted) return;
    _setCargo(user, chosen);
  }

  Future<void> _editCustomFuncao(AppUser user) async {
    final controller = TextEditingController(text: _funcaoFor(user));
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Função de ${user.name} no RDO',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aparece na coluna Função da equipe técnica.',
                style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Função'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: GsTheme.brass,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Salvar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (chosen == null || chosen.trim().isEmpty || !mounted) return;
    _setFuncao(user, chosen);
  }

  void _toggleTechnician(AppUser user) {
    final email = user.email.trim().toLowerCase();
    final login = user.login.trim().toLowerCase();
    final key = email.isNotEmpty ? email : login;
    setState(() {
      if (_isSelectedTechnician(user)) {
        final keys = technicianIdentityKeys(user);
        _selectedTechEmails.removeWhere((item) {
          final value = item.trim().toLowerCase();
          return keys.contains(value) ||
              (value.contains('@') && keys.contains(value.split('@').first));
        });
        _techFuncoes.remove(_funcaoId(user));
        _techCargos.remove(_funcaoId(user));
      } else if (key.isNotEmpty) {
        final wasEmpty = _selectedTechEmails.isEmpty;
        _selectedTechEmails.add(key);
        _techFuncoes[_funcaoId(user)] = wasEmpty
            ? 'Responsável técnico'
            : 'Suporte Técnico';
      }
    });
  }

  void _applyClient(SavedClient client) {
    setState(() {
      final switched = _selectedClientId != client.id;
      _selectedClientId = client.id;
      _client.text = client.name;
      _cnpj.text = client.cnpj;
      if (switched) {
        _system.clear();
        _site.clear();
      }
      _baseContacts = [...client.resolvedBaseContacts];
      if (_baseContacts.isNotEmpty) {
        _baseName.text = _baseContacts.first.name;
        _baseCargo.text = _baseContacts.first.cargo;
        _baseEmail.text = _baseContacts.first.email;
        _basePhone.text = _baseContacts.first.phone;
      } else if (client.baseName.isNotEmpty) {
        _baseName.text = client.baseName;
        _baseCargo.text = client.baseCargo;
        _baseEmail.text = client.baseEmail;
        _basePhone.text = client.basePhone;
        _baseContacts = [
          ClientBaseContact(
            name: client.baseName,
            cargo: client.baseCargo,
            email: client.baseEmail,
            phone: client.basePhone,
          ),
        ];
      }
    });
  }

  void _setServiceKind(OsServiceKind kind) {
    setState(() {
      _serviceKind = kind;
      final preset = osServiceKindPresetLabel(kind);
      if (preset.isNotEmpty) {
        _service.text = preset;
      }
    });
  }

  List<String> get _reservedCertNumbers => [
    for (final slot in _calibrationSlots) slot.certificateNumber,
  ];

  void _setHasCalibration(bool value) {
    setState(() {
      _hasCalibration = value;
      if (!value) _calibrationSlots = [];
    });
  }

  Future<void> _addCalibrationSlots(
    CalibrationKind kind,
    int count, {
    ClientEquipment? equipment,
  }) async {
    if (count < 1) return;
    await CalibrationStore.instance.load();
    final base = DateTime.now().microsecondsSinceEpoch;
    final reserved = [..._reservedCertNumbers];
    final added = <OsCalibrationSlot>[];
    final client = _selectedClientId != null
        ? ClientStore.instance.byId(_selectedClientId!)
        : null;
    final usedIds = {
      for (final slot in _calibrationSlots)
        if (slot.equipmentId.isNotEmpty)
          calibrationUseKey(slot.kind, slot.equipmentId, slot.product),
    };
    var pool = equipment != null
        ? [equipment]
        : clientEquipmentForCalibration(
            equipment: client?.equipment ?? const [],
            kind: kind,
            usedIds: usedIds,
            installLocation: _site.text.trim(),
            systemType: _system.text.trim(),
            perProduct: true,
          );
    for (var i = 0; i < count; i++) {
      final number = CalibrationStore.instance.nextNumber(
        kind,
        reserved: reserved,
      );
      reserved.add(number);
      final id = '${base}_$i';
      ClientEquipment? picked;
      if (equipment != null && i == 0) {
        picked = equipment;
      } else if (equipment == null && i < pool.length) {
        picked = pool[i];
        usedIds.add(calibrationUseKey(kind.name, picked.id, picked.product));
      }
      added.add(
        picked == null
            ? OsCalibrationSlot(
                id: id,
                kind: kind.name,
                certificateNumber: number,
              )
            : OsCalibrationSlot.fromEquipment(
                id: id,
                kind: kind.name,
                certificateNumber: number,
                equipment: picked,
              ),
      );
    }
    setState(() {
      _hasCalibration = true;
      _calibrationSlots = dedupeCalibrationSlotsByCertificateNumber([
        ..._calibrationSlots,
        ...added,
      ]);
    });
  }

  Map<String, int> get _calibrationKindCounts {
    final counts = <String, int>{};
    for (final slot in _calibrationSlots) {
      counts.update(slot.kind, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<int?> _pickCalibrationQuantity(CalibrationKind kind) async {
    final controller = TextEditingController(text: '1');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(calibrationKindLabel(kind)),
        content: TextField(
          key: Key('os-cal-qty-${kind.name}'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantos certificados?',
            helperText: 'Cada um ganha número sequencial (GS-VOL-2026-0001…).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim()) ?? 0;
              if (parsed < 1 || parsed > 99) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Incluir'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _askQuantityThenAdd(CalibrationKind kind) async {
    final qty = await _pickCalibrationQuantity(kind);
    if (qty == null || !mounted) return;
    await _addCalibrationSlots(kind, qty);
  }

  Future<void> _pickKindThenAdd({ClientEquipment? equipment}) async {
    final kind = await showModalBottomSheet<CalibrationKind>(
      context: context,
      backgroundColor: GsTheme.paper,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Tipo de calibração',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
            ),
            for (final kind in CalibrationKind.values)
              ListTile(
                title: Text(calibrationKindLabel(kind)),
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    if (equipment != null) {
      final perProduct =
          kind == CalibrationKind.volumetric ||
              kind == CalibrationKind.volumetricInverted
          ? expandClientEquipmentPerProduct([equipment])
          : [equipment];
      for (final item in perProduct) {
        await _addCalibrationSlots(kind, 1, equipment: item);
      }
    } else {
      await _askQuantityThenAdd(kind);
    }
  }

  Future<void> _addSlotFromCadastro() async {
    final clientId = _selectedClientId;
    if (clientId == null) {
      _toast('Selecione o cliente antes.');
      return;
    }
    final client = ClientStore.instance.byId(clientId);
    if (client == null || client.equipment.isEmpty) {
      _toast('Este cliente ainda não tem equipamento cadastrado.');
      return;
    }
    final equipment = await showSearchPickSheet<ClientEquipment>(
      context: context,
      title: 'Equipamento para certificado',
      items: client.equipment,
      selected: null,
      labelOf: (item) => item.title,
      subtitleOf: (item) => [
        if (item.serialNumber.trim().isNotEmpty) 'N/S ${item.serialNumber}',
        if (item.systemType.trim().isNotEmpty) item.systemType,
        if (item.installLocation.trim().isNotEmpty) item.installLocation,
      ].join(' · '),
      searchOf: (item) =>
          '${item.tag} ${item.serialNumber} ${item.systemType} ${item.equipmentType}',
      emptyMessage: 'Nenhum equipamento com esse texto.',
    );
    if (equipment == null || !mounted) return;
    await _pickKindThenAdd(equipment: equipment);
  }

  Future<void> _editSlot(int index) async {
    final slot = _calibrationSlots[index];
    final updated = await showOsCalibrationSlotEditSheet(
      context: context,
      slot: slot,
      allowEdit: true,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _calibrationSlots = [
        for (var i = 0; i < _calibrationSlots.length; i++)
          if (i == index) updated else _calibrationSlots[i],
      ];
    });
  }

  void _removeSlotsOfKind(String kind) {
    setState(() {
      _calibrationSlots = [
        for (final slot in _calibrationSlots)
          if (slot.kind != kind) slot,
      ];
      if (_calibrationSlots.isEmpty) _hasCalibration = false;
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _calibrationSlots = [
        for (var i = 0; i < _calibrationSlots.length; i++)
          if (i != index) _calibrationSlots[i],
      ];
      if (_calibrationSlots.isEmpty) _hasCalibration = false;
    });
  }

  RdoData _header() {
    final primary = ClientBaseContact(
      name: _baseName.text.trim(),
      cargo: _baseCargo.text.trim(),
      email: _baseEmail.text.trim(),
      phone: _basePhone.text.trim(),
    );
    final contacts = resolveBaseContacts(
      contacts: [
        if (primary.hasName) primary,
        for (final item in _baseContacts)
          if (item.hasName &&
              item.name.trim().toLowerCase() !=
                  primary.name.trim().toLowerCase())
            item,
      ],
      baseName: primary.name,
      baseCargo: primary.cargo,
      baseEmail: primary.email,
      basePhone: primary.phone,
    );
    return RdoData(
      client: _client.text.trim(),
      site: _site.text.trim(),
      cnpj: _cnpj.text.trim(),
      systemType: _system.text.trim(),
      service: _service.text.trim(),
      technicianCargo: _defaultTechnicianCargo(_techCargo.text),
      baseName: contacts.isEmpty ? '' : contacts.first.name,
      baseCargo: contacts.isEmpty ? '' : contacts.first.cargo,
      baseEmail: contacts.isEmpty ? '' : contacts.first.email,
      basePhone: contacts.isEmpty ? '' : contacts.first.phone,
      baseContacts: contacts,
      technicianFuncoes: {
        for (final user in _selectedTechnicians)
          _funcaoId(user): _funcaoFor(user),
      },
      technicianCargos: {
        for (final user in _selectedTechnicians)
          personFirstKey(user.name): _cargoFor(user),
      },
    );
  }

  Future<void> _save({required bool dispatch}) async {
    if (_busy) return;
    final number = _number.text.trim();
    if (number.isEmpty) {
      _toast('Informe o número da OS.');
      return;
    }
    if (_cnpj.text.trim().isEmpty) {
      _toast('Informe o CNPJ do cliente.');
      return;
    }
    if (_client.text.trim().isEmpty) {
      _toast('Informe o contratante.');
      return;
    }
    if (_service.text.trim().isEmpty) {
      _toast('Escolha o tipo de serviço ou descreva em Serviço contratado.');
      return;
    }
    if (_selectedTechnicians.isEmpty) {
      _toast('Escolha pelo menos um técnico para este serviço.');
      return;
    }
    setState(() => _busy = true);
    try {
      var saved = await FieldStore.instance.saveOs(
        number: number,
        files:
            widget.existing?.files
                .map(
                  (file) => DraftFile(
                    name: file.name,
                    kind: file.kind,
                    path: file.path,
                    bytes: FieldStore.instance.bytesFor(file),
                    label: file.label,
                  ),
                )
                .toList() ??
            const [],
        existingId: widget.existing?.id,
        signerName: _baseName.text,
        rdo: _header(),
        technicianEmail: _selectedTechnicians.first.email,
        technicianName: uniquePersonNames(
          [
            for (final user in _selectedTechnicians)
              if (user.name.trim().isNotEmpty) user.name.trim(),
          ].join(', '),
        ),
        technicianEmails: [
          for (final user in _selectedTechnicians) ...assigneeKeysFor(user),
        ],
        status: widget.existing?.status ?? OsStatus.rascunho,
        rdos: widget.existing?.rdos,
        startsAt: _startsAt,
        calibrationSlots: _hasCalibration
            ? dedupeCalibrationSlotsByCertificateNumber(_calibrationSlots)
            : const [],
      );
      if (dispatch) {
        saved = await FieldStore.instance.dispatchToTechnician(saved.id);
      }
      if (_hasCalibration) {
        final canWriteCadastro = canReviewCatalogSubmissions(
          AuthSession.instance.user,
        );
        if (canWriteCadastro) {
          await applyOsSlotsToClientCatalog(
            os: saved,
            slots: _calibrationSlots,
            onlyNew: true,
          );
        }
      }
      for (final user in _selectedTechnicians) {
        await persistTechnicianCargo(user.name, _cargoFor(user));
      }
      if (!mounted) return;
      _toast(
        dispatch
            ? 'OS $number na agenda de ${_selectedTechnicians.map((user) => user.name).join(', ')}.'
            : 'OS $number salva.',
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Não foi possível salvar. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nova OS' : 'Editar OS'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          ClientStore.instance,
          StaffStore.instance,
        ]),
        builder: (context, _) {
          final clients = ClientStore.instance.items;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              const Text(
                'O técnico não redigita isso. Estes dados já saem no RDO quando ele lançar o dia.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('os-number'),
                controller: _number,
                enabled: widget.existing == null,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Número da OS'),
              ),
              const SizedBox(height: 16),
              InkWell(
                key: const Key('os-starts-at'),
                onTap: () async {
                  final picked = await pickAppDate(
                    context,
                    initialDate: _startsAt,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked == null) return;
                  setState(() => _startsAt = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Início do serviço',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    formatOsDay(_startsAt),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (clients.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('Cliente cadastrado'),
                const SizedBox(height: 8),
                const Text(
                  'Toque para preencher CNPJ, contratante e responsável da base.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 10),
                for (final client in clients) ...[
                  Material(
                    color: Colors.white,
                    child: InkWell(
                      key: Key('pick-client-${client.id}'),
                      onTap: () => _applyClient(client),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedClientId == client.id
                                ? GsTheme.brass
                                : const Color(0x331A2330),
                            width: _selectedClientId == client.id ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: GsTheme.navy,
                              ),
                            ),
                            if (client.cnpj.isNotEmpty)
                              Text(
                                'CNPJ ${client.cnpj}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5C6570),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 24),
              const _SectionTitle('Tipo de serviço'),
              const SizedBox(height: 6),
              const Text(
                'A OS não fica presa a um equipamento. Equipamento e certificado entram só na parte de calibração, se for o caso.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in OsServiceKind.values)
                    ChoiceChip(
                      key: Key('os-service-${kind.name}'),
                      label: Text(osServiceKindChipLabel(kind)),
                      selected: _serviceKind == kind,
                      onSelected: (_) => _setServiceKind(kind),
                    ),
                ],
              ),
              if (_serviceKind == OsServiceKind.outro) ...[
                const SizedBox(height: 8),
                const Text(
                  'Descreva o serviço em “Serviço contratado”, nos dados do RDO abaixo.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
                ),
              ],
              const SizedBox(height: 24),
              const _SectionTitle('Cliente'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('os-cnpj'),
                controller: _cnpj,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CNPJ'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('os-client'),
                controller: _client,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Contratante'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _site,
                decoration: const InputDecoration(
                  labelText: 'Local do serviço',
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Dados do RDO'),
              const SizedBox(height: 8),
              const Text(
                'Entram no relatório do dia. O técnico só completa horário, descrição e assinatura.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('os-service'),
                controller: _service,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Serviço contratado',
                  helperText: _serviceKind == OsServiceKind.outro
                      ? 'Texto livre — use quando nenhuma opção acima servir.'
                      : 'Ajuste se precisar; veio do tipo de serviço escolhido.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('os-system'),
                controller: _system,
                decoration: const InputDecoration(
                  labelText: 'Tipo de sistema',
                  helperText: 'Carga, descarga ou o sistema deste serviço.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('base-name'),
                controller: _baseName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Responsável da base · nome',
                  helperText:
                      'Se o cliente tem mais de um, os outros vêm do cadastro e você escolhe no RDO.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('base-cargo'),
                controller: _baseCargo,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Responsável da base · cargo',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('base-email'),
                controller: _baseEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Responsável da base · e-mail',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('base-phone'),
                controller: _basePhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Responsável da base · telefone',
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Delegar técnicos'),
              const SizedBox(height: 8),
              const Text(
                'Pode marcar mais de um. Na hora de delegar, defina a função de cada um no RDO. Quem assina como responsável técnico dá para escolher na hora de salvar o relatório do dia.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 10),
              for (final user in fieldTechnicians) ...[
                Material(
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isSelectedTechnician(user)
                            ? GsTheme.brass
                            : const Color(0x331A2330),
                        width: _isSelectedTechnician(user) ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          key: Key('tech-${user.login}'),
                          onTap: () => _toggleTechnician(user),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                Icon(
                                  _isSelectedTechnician(user)
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: GsTheme.navy,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: GsTheme.navy,
                                        ),
                                      ),
                                      Text(
                                        user.login.isEmpty
                                            ? user.role
                                            : '${user.login} · ${user.role}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF5C6570),
                                        ),
                                      ),
                                      if (_cargoFor(user).isNotEmpty)
                                        Text(
                                          _cargoFor(user),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF5C6570),
                                          ),
                                        ),
                                      if (_selectedTechnicians.isNotEmpty &&
                                          sameFieldTechnician(
                                            user,
                                            _selectedTechnicians.first,
                                          ))
                                        const Text(
                                          '1º marcado · padrão de responsável técnico',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: GsTheme.brass,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isSelectedTechnician(user))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Função no RDO',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5C6570),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Responsável técnico'),
                                      selected:
                                          _funcaoFor(user) ==
                                          'Responsável técnico',
                                      onSelected: (_) => _setFuncao(
                                        user,
                                        'Responsável técnico',
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Suporte Técnico'),
                                      selected:
                                          _funcaoFor(user) == 'Suporte Técnico',
                                      onSelected: (_) =>
                                          _setFuncao(user, 'Suporte Técnico'),
                                    ),
                                    ActionChip(
                                      label: Text(
                                        _funcaoFor(user) !=
                                                    'Responsável técnico' &&
                                                _funcaoFor(user) !=
                                                    'Suporte Técnico'
                                            ? _funcaoFor(user)
                                            : 'Outra',
                                      ),
                                      onPressed: () => _editCustomFuncao(user),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Cargo no RDO',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5C6570),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ActionChip(
                                  label: Text(_cargoFor(user)),
                                  onPressed: () => _editCargo(user),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 2),
              TextField(
                controller: _techCargo,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText:
                      'Cargo padrão (só se o técnico ainda não tiver o seu)',
                  helperText:
                      'O cargo de cada pessoa é editado no card acima. Este campo só entra se o cadastro estiver vazio.',
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Calibração nesta OS'),
              const SizedBox(height: 8),
              const Text(
                'Marque se vai haver calibração. Toque no tipo e informe quantos '
                'certificados; o app gera os números e puxa equipamentos do cadastro '
                '(preset, produto, densidade…). Se pedir mais do que tem cadastrado, '
                'o restante fica em branco para o técnico preencher em campo.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                key: const Key('os-has-calibration'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Esta OS terá calibração'),
                value: _hasCalibration,
                onChanged: _setHasCalibration,
              ),
              if (_hasCalibration) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in CalibrationKind.values)
                      ActionChip(
                        key: Key('os-add-cal-${kind.name}'),
                        label: Text('+ ${calibrationKindLabel(kind)}'),
                        onPressed: () => _askQuantityThenAdd(kind),
                      ),
                    OutlinedButton.icon(
                      key: const Key('os-add-cal-equipment'),
                      onPressed: _addSlotFromCadastro,
                      icon: const Icon(Icons.precision_manufacturing_outlined),
                      label: const Text('Do cadastro (com N/S)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_calibrationSlots.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _calibrationKindCounts.entries)
                        Chip(
                          label: Text(
                            '${calibrationKindLabel(calibrationKindFrom(entry.key))}: ${entry.value}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_calibrationSlots.isEmpty)
                  const Text(
                    'Inclua pelo menos um tipo (ou equipamento do cadastro).',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  )
                else
                  CalibrationSlotsGroupedList(
                    slots: _calibrationSlots,
                    itemBuilder: (index, slot) => ListTile(
                      key: Key('os-cal-slot-${slot.id}'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      onTap: () => _editSlot(index),
                      title: Text(
                        slot.certificateNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0x553A4A5C),
                        ),
                      ),
                      subtitle: Text(
                        osCalibrationSlotDetailLine(slot),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Conferir / preencher dados',
                            onPressed: () => _editSlot(index),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Remover',
                            onPressed: () => _removeSlot(index),
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
                      ),
                    ),
                    groupActionsBuilder: (group) => IconButton(
                      key: Key('os-create-cal-remove-group-${group.kind.name}'),
                      tooltip:
                          'Remover todos de ${calibrationKindLabel(group.kind)}',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Remover ${calibrationKindLabel(group.kind)}?',
                            ),
                            content: Text(
                              'Apaga ${group.items.length} certificado(s) deste tipo na OS.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remover'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          _removeSlotsOfKind(group.kind.name);
                        }
                      },
                      icon: const Icon(Icons.delete_sweep_outlined),
                      color: const Color(0xFF8A3B3B),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              if (_alreadySent)
                FilledButton(
                  onPressed: _busy ? null : () => _save(dispatch: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_busy ? 'Aguarde…' : 'Salvar alterações'),
                )
              else ...[
                FilledButton(
                  key: const Key('os-dispatch'),
                  onPressed: _busy ? null : () => _save(dispatch: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    _busy
                        ? 'Aguarde…'
                        : _selectedTechnicians.length > 1
                        ? 'Salvar e enviar à agenda dos técnicos'
                        : 'Salvar e enviar à agenda do técnico',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => _save(dispatch: false),
                  child: const Text('Só salvar rascunho'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GsTheme.navy,
      ),
    );
  }
}

enum OsServiceKind {
  manutencao,
  calibracao,
  configuracao,
  visitaTecnica,
  outro,
}

String osServiceKindChipLabel(OsServiceKind kind) {
  switch (kind) {
    case OsServiceKind.manutencao:
      return 'Manutenção';
    case OsServiceKind.calibracao:
      return 'Calibração';
    case OsServiceKind.configuracao:
      return 'Configuração';
    case OsServiceKind.visitaTecnica:
      return 'Visita técnica';
    case OsServiceKind.outro:
      return 'Outro / descrever';
  }
}

String osServiceKindPresetLabel(OsServiceKind kind) {
  switch (kind) {
    case OsServiceKind.manutencao:
      return 'Manutenção';
    case OsServiceKind.calibracao:
      return 'Calibração';
    case OsServiceKind.configuracao:
      return 'Configuração';
    case OsServiceKind.visitaTecnica:
      return 'Visita técnica';
    case OsServiceKind.outro:
      return '';
  }
}

OsServiceKind? inferOsServiceKind(String service) {
  final value = service.trim().toLowerCase();
  if (value.isEmpty) return null;
  if (value == 'manutenção' || value == 'manutencao') {
    return OsServiceKind.manutencao;
  }
  if (value == 'calibração' ||
      value == 'calibracao' ||
      value.startsWith('calibra')) {
    return OsServiceKind.calibracao;
  }
  if (value == 'configuração' || value == 'configuracao') {
    return OsServiceKind.configuracao;
  }
  if (value.contains('visita')) {
    return OsServiceKind.visitaTecnica;
  }
  return OsServiceKind.outro;
}

String _defaultTechnicianCargo(String raw) => normalizeTechnicianCargo(raw);
