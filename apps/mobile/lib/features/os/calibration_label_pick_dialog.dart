import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/models.dart';

/// Item da lista de adesivos: slot + certificado ligado (se houver).
class CalibrationLabelPickItem {
  const CalibrationLabelPickItem({
    required this.slot,
    required this.job,
    required this.dateLabel,
    required this.ready,
    required this.hasCalibrationDate,
  });

  final OsCalibrationSlot slot;
  final CalibrationJob? job;
  final String dateLabel;
  final bool ready;

  /// Tem data explícita no certificado ou no adesivo (não só fallback da OS).
  final bool hasCalibrationDate;
}

/// Escolhe quais adesivos entram no PDF.
/// Retorna os itens marcados, ou `null` se cancelar.
Future<List<CalibrationLabelPickItem>?> showCalibrationLabelPickDialog(
  BuildContext context, {
  required List<CalibrationLabelPickItem> items,
  String title = 'Quais adesivos imprimir?',
}) {
  if (items.isEmpty) {
    return Future.value(const <CalibrationLabelPickItem>[]);
  }
  return showDialog<List<CalibrationLabelPickItem>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _CalibrationLabelPickDialog(
      items: items,
      title: title,
    ),
  );
}

class _CalibrationLabelPickDialog extends StatefulWidget {
  const _CalibrationLabelPickDialog({
    required this.items,
    required this.title,
  });

  final List<CalibrationLabelPickItem> items;
  final String title;

  @override
  State<_CalibrationLabelPickDialog> createState() =>
      _CalibrationLabelPickDialogState();
}

class _CalibrationLabelPickDialogState
    extends State<_CalibrationLabelPickDialog> {
  late final Set<String> _selected;
  late final List<CalibrationLabelPickItem> _withDate;
  late final List<CalibrationLabelPickItem> _withoutDate;
  late final List<CalibrationLabelPickItem> _notReady;

  List<CalibrationLabelPickItem> get _printable => [
    ..._withDate,
    ..._withoutDate,
  ];

  @override
  void initState() {
    super.initState();
    _withDate = [
      for (final item in widget.items)
        if (item.ready && item.hasCalibrationDate) item,
    ];
    _withoutDate = [
      for (final item in widget.items)
        if (item.ready && !item.hasCalibrationDate) item,
    ];
    _notReady = [
      for (final item in widget.items)
        if (!item.ready) item,
    ];
    // Padrão: marca os que já têm data de calibração (os calibrados).
    _selected = {for (final item in _withDate) item.slot.id};
    if (_selected.isEmpty) {
      _selected.addAll(_withoutDate.map((item) => item.slot.id));
    }
  }

  bool get _allPrintableSelected =>
      _printable.isNotEmpty &&
      _printable.every((item) => _selected.contains(item.slot.id));

  bool get _noneSelected => _selected.isEmpty;

  void _toggleGroup(List<CalibrationLabelPickItem> group, bool select) {
    setState(() {
      for (final item in group) {
        if (select) {
          _selected.add(item.slot.id);
        } else {
          _selected.remove(item.slot.id);
        }
      }
    });
  }

  bool? _groupValue(List<CalibrationLabelPickItem> group) {
    if (group.isEmpty) return false;
    final all = group.every((item) => _selected.contains(item.slot.id));
    final none = group.every((item) => !_selected.contains(item.slot.id));
    if (all) return true;
    if (none) return false;
    return null;
  }

  String _line(CalibrationLabelPickItem item) {
    final slot = item.slot;
    final job = item.job;
    final tag = (job?.equipmentTag ?? slot.equipmentTag).trim();
    final serial = (job?.serialNumber ?? slot.serialNumber).trim();
    final number = slot.certificateNumber.trim().isEmpty
        ? (job?.number.trim().isNotEmpty == true ? job!.number.trim() : 'Sem nº')
        : slot.certificateNumber.trim();
    return [
      number,
      if (tag.isNotEmpty) 'TAG $tag',
      if (serial.isNotEmpty) 'N/S $serial',
      if (item.dateLabel.isNotEmpty) 'Data ${item.dateLabel}',
    ].join(' · ');
  }

  Widget _groupHeader({
    required String title,
    required List<CalibrationLabelPickItem> group,
    required bool selectable,
  }) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selectable ? _groupValue(group) : false,
      tristate: selectable,
      activeColor: GsTheme.navy,
      title: Text(
        '$title (${group.length})',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
        ),
      ),
      onChanged: !selectable || group.isEmpty
          ? null
          : (value) => _toggleGroup(group, value == true),
    );
  }

  Widget _itemTile(CalibrationLabelPickItem item, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: enabled && _selected.contains(item.slot.id),
        activeColor: GsTheme.navy,
        title: Text(
          _line(item),
          style: TextStyle(
            fontSize: 13.5,
            color: enabled ? GsTheme.navy : const Color(0xFF8A9099),
          ),
        ),
        subtitle: !enabled
            ? Text(
                item.job == null
                    ? 'Sem calibração (sobressalente) — não imprime'
                    : 'Sem TAG/N/S — preencha antes do adesivo',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A3B3B)),
              )
            : null,
        onChanged: !enabled
            ? null
            : (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(item.slot.id);
                  } else {
                    _selected.remove(item.slot.id);
                  }
                });
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GsTheme.paper,
      title: Text(
        widget.title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Marque só os que quer imprimir agora. '
              'Os com data de calibração já vêm marcados.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _printable.isEmpty || _allPrintableSelected
                      ? null
                      : () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(_printable.map((item) => item.slot.id));
                        }),
                  child: const Text('Marcar imprimíveis'),
                ),
                TextButton(
                  onPressed: _noneSelected
                      ? null
                      : () => setState(() => _selected.clear()),
                  child: const Text('Desmarcar'),
                ),
                const Spacer(),
                Text(
                  '${_selected.length}/${_printable.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_withDate.isNotEmpty) ...[
                    _groupHeader(
                      title: 'Com data de calibração',
                      group: _withDate,
                      selectable: true,
                    ),
                    for (final item in _withDate) _itemTile(item, enabled: true),
                    const SizedBox(height: 6),
                  ],
                  if (_withoutDate.isNotEmpty) ...[
                    _groupHeader(
                      title: 'Sem data de calibração',
                      group: _withoutDate,
                      selectable: true,
                    ),
                    for (final item in _withoutDate)
                      _itemTile(item, enabled: true),
                    const SizedBox(height: 6),
                  ],
                  if (_notReady.isNotEmpty) ...[
                    _groupHeader(
                      title: 'Não dá para imprimir',
                      group: _notReady,
                      selectable: false,
                    ),
                    for (final item in _notReady)
                      _itemTile(item, enabled: false),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _noneSelected
              ? null
              : () {
                  final picked = [
                    for (final item in _printable)
                      if (_selected.contains(item.slot.id)) item,
                  ];
                  Navigator.pop(context, picked);
                },
          style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
          child: Text(
            _selected.isEmpty
                ? 'Imprimir'
                : 'Imprimir ${_selected.length} adesivo(s)',
          ),
        ),
      ],
    );
  }
}

/// Data explícita no certificado ou no adesivo (para separar na lista).
bool slotHasExplicitCalibrationDate(
  OsCalibrationSlot slot,
  CalibrationJob? job,
) {
  if (slot.labelDate.trim().isNotEmpty) return true;
  final raw = (job?.calibrationDate ?? '').trim();
  if (raw.isEmpty) return false;
  return parseCalibrationDateLabel(raw) != null || raw.contains('/');
}
