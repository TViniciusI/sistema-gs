import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';

/// Escolhe quais certificados entram no livro PDF.
/// Retorna a lista marcada, ou `null` se cancelar.
Future<List<CalibrationJob>?> showCertificateBookPickDialog(
  BuildContext context, {
  required List<CalibrationJob> jobs,
  String title = 'Quais certificados no livro?',
}) {
  if (jobs.isEmpty) {
    return Future.value(const <CalibrationJob>[]);
  }
  return showDialog<List<CalibrationJob>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _CertificateBookPickDialog(
      jobs: jobs,
      title: title,
    ),
  );
}

class _CertificateBookPickDialog extends StatefulWidget {
  const _CertificateBookPickDialog({
    required this.jobs,
    required this.title,
  });

  final List<CalibrationJob> jobs;
  final String title;

  @override
  State<_CertificateBookPickDialog> createState() =>
      _CertificateBookPickDialogState();
}

class _CertificateBookPickDialogState extends State<_CertificateBookPickDialog> {
  late final Set<String> _selected;
  late final List<MapEntry<CalibrationKind, List<CalibrationJob>>> _groups;

  @override
  void initState() {
    super.initState();
    _selected = {for (final job in widget.jobs) job.id};
    final byKind = <CalibrationKind, List<CalibrationJob>>{};
    for (final job in widget.jobs) {
      byKind.putIfAbsent(job.kind, () => []).add(job);
    }
    // Mesma ordem do livro (volumétrica → … → telemetria).
    const order = [
      CalibrationKind.volumetric,
      CalibrationKind.volumetricInverted,
      CalibrationKind.temperature,
      CalibrationKind.temperatureMesh,
      CalibrationKind.density,
      CalibrationKind.pressure,
      CalibrationKind.conductivity,
      CalibrationKind.telemetry,
    ];
    _groups = [
      for (final kind in order)
        if (byKind.containsKey(kind)) MapEntry(kind, byKind.remove(kind)!),
      ...byKind.entries,
    ];
  }

  bool get _allSelected => _selected.length == widget.jobs.length;

  bool get _noneSelected => _selected.isEmpty;

  bool _kindAllSelected(List<CalibrationJob> items) =>
      items.every((j) => _selected.contains(j.id));

  bool _kindNoneSelected(List<CalibrationJob> items) =>
      items.every((j) => !_selected.contains(j.id));

  void _toggleKind(List<CalibrationJob> items, bool select) {
    setState(() {
      for (final job in items) {
        if (select) {
          _selected.add(job.id);
        } else {
          _selected.remove(job.id);
        }
      }
    });
  }

  String _jobLine(CalibrationJob job) {
    final tag = job.equipmentTag.trim();
    final serial = job.serialNumber.trim();
    return [
      job.number.trim().isEmpty ? 'Sem número' : job.number.trim(),
      if (tag.isNotEmpty) 'TAG $tag',
      if (serial.isNotEmpty) 'N/S $serial',
      job.statusLabel,
    ].join(' · ');
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
              'Desmarque o que não quiser agora (ex.: telemetria). '
              'Só os marcados entram no PDF.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _allSelected
                      ? null
                      : () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(widget.jobs.map((j) => j.id));
                        }),
                  child: const Text('Marcar todos'),
                ),
                TextButton(
                  onPressed: _noneSelected
                      ? null
                      : () => setState(() => _selected.clear()),
                  child: const Text('Desmarcar todos'),
                ),
                const Spacer(),
                Text(
                  '${_selected.length}/${widget.jobs.length}',
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
                  for (final group in _groups) ...[
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _kindAllSelected(group.value)
                          ? true
                          : (_kindNoneSelected(group.value) ? false : null),
                      tristate: true,
                      activeColor: GsTheme.navy,
                      title: Text(
                        '${calibrationKindLabel(group.key)} '
                        '(${group.value.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                        ),
                      ),
                      onChanged: (value) {
                        // null/false → desmarca; true → marca
                        _toggleKind(group.value, value == true);
                      },
                    ),
                    for (final job in group.value)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(job.id),
                          activeColor: GsTheme.navy,
                          title: Text(
                            _jobLine(job),
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(job.id);
                              } else {
                                _selected.remove(job.id);
                              }
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 6),
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
                    for (final job in widget.jobs)
                      if (_selected.contains(job.id)) job,
                  ];
                  Navigator.pop(context, picked);
                },
          style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
          child: Text(
            _selected.isEmpty
                ? 'Gerar'
                : 'Gerar livro (${_selected.length})',
          ),
        ),
      ],
    );
  }
}
