import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/models.dart';

class CalibrationSlotIndexed {
  const CalibrationSlotIndexed({required this.index, required this.slot});

  final int index;
  final OsCalibrationSlot slot;
}

class CalibrationSlotGroup {
  const CalibrationSlotGroup({
    required this.kind,
    required this.items,
    required this.isCadastroPending,
  });

  final CalibrationKind kind;
  final List<CalibrationSlotIndexed> items;
  final bool Function(OsCalibrationSlot slot) isCadastroPending;

  List<OsCalibrationSlot> get slots => [for (final item in items) item.slot];

  List<CalibrationSlotIndexed> get withCadastro => [
    for (final item in items)
      if (!isCadastroPending(item.slot)) item,
  ];

  List<CalibrationSlotIndexed> get cadastroPendente => [
    for (final item in items)
      if (isCadastroPending(item.slot)) item,
  ];
}

List<CalibrationSlotGroup> groupCalibrationSlotsByKind(
  List<OsCalibrationSlot> slots, {
  bool Function(OsCalibrationSlot slot)? isCadastroPending,
}) {
  if (slots.isEmpty) return const [];
  final pending = isCadastroPending ?? (slot) => slot.needsCadastro;
  final kindOrder = [for (final kind in CalibrationKind.values) kind.name];
  final map = <String, List<CalibrationSlotIndexed>>{};
  for (var i = 0; i < slots.length; i++) {
    map
        .putIfAbsent(slots[i].kind, () => [])
        .add(CalibrationSlotIndexed(index: i, slot: slots[i]));
  }
  final seen = <String>{};
  final groups = <CalibrationSlotGroup>[];
  for (final kindName in kindOrder) {
    final items = map[kindName];
    if (items == null || items.isEmpty) continue;
    seen.add(kindName);
    groups.add(
      CalibrationSlotGroup(
        kind: calibrationKindFrom(kindName),
        items: items,
        isCadastroPending: pending,
      ),
    );
  }
  for (final entry in map.entries) {
    if (seen.contains(entry.key)) continue;
    groups.add(
      CalibrationSlotGroup(
        kind: calibrationKindFrom(entry.key),
        items: entry.value,
        isCadastroPending: pending,
      ),
    );
  }
  return groups;
}

String calibrationSlotNumberRange(List<OsCalibrationSlot> slots) {
  if (slots.isEmpty) return '';
  if (slots.length == 1) return slots.first.certificateNumber;
  return '${slots.first.certificateNumber} … ${slots.last.certificateNumber}';
}

String calibrationSlotGroupStats(
  List<OsCalibrationSlot> slots, {
  bool Function(OsCalibrationSlot slot)? isCadastroPending,
}) {
  if (slots.isEmpty) return '';
  final pending = isCadastroPending ?? (slot) => slot.needsCadastro;
  final withCadastro = slots.where((s) => !pending(s)).length;
  final pendingCadastro = slots.where(pending).length;
  final pendingNs = slots.where((s) => s.serialNumber.trim().isEmpty).length;
  final divergent = slots.where((s) => s.isDivergent).length;
  final confirmed = slots.where((s) => s.isDataConfirmed).length;
  return [
    calibrationSlotNumberRange(slots),
    '${slots.length} certificado(s)',
    if (withCadastro > 0) '$withCadastro com cadastro',
    if (pendingCadastro > 0) '$pendingCadastro sem cadastro (ou sobressalente)',
    if (pendingNs > 0 && pendingCadastro == 0) '$pendingNs N/S pendente',
    if (confirmed > 0) '$confirmed conferido(s)',
    if (divergent > 0) '$divergent divergente(s)',
  ].join(' · ');
}

class CalibrationSlotsGroupedList extends StatelessWidget {
  const CalibrationSlotsGroupedList({
    super.key,
    required this.slots,
    required this.itemBuilder,
    this.groupActionsBuilder,
    this.initiallyExpanded = false,
    this.selectedSlotIds = const {},
    this.onToggleSlotSelected,
    this.onSetSlotsSelected,
    this.onDeleteSelected,
    this.selectionEnabled = false,
    this.isCadastroPending,
  });

  final List<OsCalibrationSlot> slots;
  final Widget Function(int index, OsCalibrationSlot slot) itemBuilder;

  /// Ações no cabeçalho de cada tipo (ex.: imprimir / remover todos).
  final Widget Function(CalibrationSlotGroup group)? groupActionsBuilder;
  final bool initiallyExpanded;

  /// Seleção para apagar só os marcados (escritório).
  final bool selectionEnabled;
  final bool Function(OsCalibrationSlot slot)? isCadastroPending;
  final Set<String> selectedSlotIds;
  final void Function(String slotId)? onToggleSlotSelected;
  final void Function(Iterable<String> slotIds, {required bool selected})?
  onSetSlotsSelected;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final groups = groupCalibrationSlotsByKind(
      slots,
      isCadastroPending: isCadastroPending,
    );
    return Column(
      children: [
        for (final group in groups)
          _CalibrationKindGroupCard(
            key: Key('os-cal-group-${group.kind.name}'),
            group: group,
            itemBuilder: itemBuilder,
            groupActionsBuilder: groupActionsBuilder,
            initiallyExpanded: initiallyExpanded || groups.length == 1,
            selectionEnabled: selectionEnabled,
            selectedSlotIds: selectedSlotIds,
            onToggleSlotSelected: onToggleSlotSelected,
            onSetSlotsSelected: onSetSlotsSelected,
            onDeleteSelected: onDeleteSelected,
          ),
      ],
    );
  }
}

class _CalibrationKindGroupCard extends StatefulWidget {
  const _CalibrationKindGroupCard({
    super.key,
    required this.group,
    required this.itemBuilder,
    this.groupActionsBuilder,
    this.initiallyExpanded = false,
    this.selectionEnabled = false,
    this.selectedSlotIds = const {},
    this.onToggleSlotSelected,
    this.onSetSlotsSelected,
    this.onDeleteSelected,
  });

  final CalibrationSlotGroup group;
  final Widget Function(int index, OsCalibrationSlot slot) itemBuilder;
  final Widget Function(CalibrationSlotGroup group)? groupActionsBuilder;
  final bool initiallyExpanded;
  final bool selectionEnabled;
  final Set<String> selectedSlotIds;
  final void Function(String slotId)? onToggleSlotSelected;
  final void Function(Iterable<String> slotIds, {required bool selected})?
  onSetSlotsSelected;
  final VoidCallback? onDeleteSelected;

  @override
  State<_CalibrationKindGroupCard> createState() =>
      _CalibrationKindGroupCardState();
}

class _CalibrationKindGroupCardState extends State<_CalibrationKindGroupCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<CalibrationSlotIndexed> get _visible {
    return _tabs.index == 0
        ? widget.group.withCadastro
        : widget.group.cadastroPendente;
  }

  int get _selectedInTab {
    var n = 0;
    for (final item in _visible) {
      if (widget.selectedSlotIds.contains(item.slot.id)) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final withCad = group.withCadastro.length;
    final pending = group.cadastroPendente.length;
    final visible = _visible;
    final selectedInTab = _selectedInTab;
    final allVisibleSelected =
        visible.isNotEmpty && selectedInTab == visible.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${calibrationKindLabel(group.kind)} · ${group.items.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: GsTheme.navy,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      calibrationSlotGroupStats(
                        group.slots,
                        isCadastroPending: group.isCadastroPending,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.groupActionsBuilder != null)
                widget.groupActionsBuilder!(group),
            ],
          ),
          children: [
            TabBar(
              controller: _tabs,
              labelColor: GsTheme.navy,
              unselectedLabelColor: const Color(0xFF5C6570),
              indicatorColor: GsTheme.brass,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  key: Key('os-cal-tab-cadastro-${group.kind.name}'),
                  text: 'Com cadastro ($withCad)',
                ),
                Tab(
                  key: Key('os-cal-tab-pendente-${group.kind.name}'),
                  text: 'Cadastro pendente ($pending)',
                ),
              ],
            ),
            if (widget.selectionEnabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: Key('os-cal-select-tab-${group.kind.name}'),
                    onPressed: visible.isEmpty
                        ? null
                        : () => widget.onSetSlotsSelected?.call(
                            visible.map((e) => e.slot.id),
                            selected: !allVisibleSelected,
                          ),
                    child: Text(
                      allVisibleSelected ? 'Desmarcar aba' : 'Marcar desta aba',
                    ),
                  ),
                  TextButton.icon(
                    key: Key('os-cal-delete-selected-${group.kind.name}'),
                    onPressed: selectedInTab == 0
                        ? null
                        : widget.onDeleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B3A3A),
                    ),
                    label: Text(
                      selectedInTab == 0
                          ? 'Apagar selecionados'
                          : 'Apagar selecionados ($selectedInTab)',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 4,
                ),
                child: Text(
                  _tabs.index == 0
                      ? 'Nenhum certificado com cadastro neste tipo.'
                      : 'Nenhum certificado com cadastro pendente neste tipo.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5C6570),
                  ),
                ),
              )
            else
              for (final item in visible)
                widget.selectionEnabled
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Checkbox(
                              key: Key('os-cal-check-${item.slot.id}'),
                              value: widget.selectedSlotIds.contains(
                                item.slot.id,
                              ),
                              onChanged: (_) => widget.onToggleSlotSelected
                                  ?.call(item.slot.id),
                            ),
                          ),
                          Expanded(
                            child: widget.itemBuilder(item.index, item.slot),
                          ),
                        ],
                      )
                    : widget.itemBuilder(item.index, item.slot),
          ],
        ),
      ),
    );
  }
}
