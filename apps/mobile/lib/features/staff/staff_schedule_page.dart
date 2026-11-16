import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/data/work_schedule.dart';
import 'package:intl/intl.dart';

/// Admin define carga horária por período, com regra nos 7 dias da semana.
class StaffSchedulePage extends StatefulWidget {
  const StaffSchedulePage({super.key, required this.email});

  final String email;

  @override
  State<StaffSchedulePage> createState() => _StaffSchedulePageState();
}

class _StaffSchedulePageState extends State<StaffSchedulePage> {
  var _busy = false;

  RemoteAccount? get _user {
    final needle = widget.email.trim().toLowerCase();
    for (final user in StaffStore.instance.directory) {
      if (user.email.trim().toLowerCase() == needle ||
          user.login.trim().toLowerCase() == needle) {
        return user;
      }
    }
    return null;
  }

  String get _title {
    final user = _user;
    if (user == null) return 'Carga horária';
    final name = user.name.trim().isEmpty ? user.login : user.name.trim();
    return 'Carga horária · $name';
  }

  Future<void> _save(List<WorkSchedulePeriod> next) async {
    final user = _user;
    if (user == null) return;
    setState(() => _busy = true);
    await StaffStore.instance.patchSchedules(user.email, next);
    final result = await AccountApi.instance.setSchedules(
      email: user.email,
      schedules: next,
    );
    if (result.ok) {
      await StaffStore.instance.applyResult(result);
    }
    if (!mounted) return;
    final unsupported = isUnsupportedSheetAction(result.error);
    if (!result.ok && (result.error ?? '').isNotEmpty && !unsupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(result.error!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            unsupported
                ? 'Carga salva neste aparelho. Cole o login_gate.gs novo na planilha para gravar na equipe.'
                : 'Carga horária atualizada.',
          ),
        ),
      );
    }
    setState(() => _busy = false);
  }

  Future<void> _addOrEdit({WorkSchedulePeriod? existing}) async {
    final user = _user;
    if (user == null) return;
    final draft = await showDialog<WorkSchedulePeriod>(
      context: context,
      builder: (_) => _SchedulePeriodDialog(initial: existing),
    );
    if (draft == null) return;
    final next = [
      for (final item in user.schedules)
        if (existing == null || item.id != existing.id) item,
      draft,
    ]..sort((a, b) => a.start.compareTo(b.start));
    await _save(next);
  }

  Future<void> _remove(WorkSchedulePeriod period) async {
    final user = _user;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover período?'),
        content: Text(
          period.end == null
              ? 'Remove a carga de ${DateFormat('dd/MM/yyyy').format(period.start)} em diante.'
              : 'Remove a carga de ${DateFormat('dd/MM/yyyy').format(period.start)} '
                    'a ${DateFormat('dd/MM/yyyy').format(period.end!)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _save([
      for (final item in user.schedules)
        if (item.id != period.id) item,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StaffStore.instance,
      builder: (context, _) {
        final user = _user;
        final fmt = DateFormat('dd/MM/yyyy');
        final periods = user?.schedules ?? const <WorkSchedulePeriod>[];
        return Scaffold(
          appBar: AppBar(title: Text(_title)),
          floatingActionButton: user == null || _busy
              ? null
              : FloatingActionButton.extended(
                  key: const Key('schedule-add'),
                  onPressed: () => _addOrEdit(),
                  backgroundColor: GsTheme.brass,
                  foregroundColor: GsTheme.navy,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo período'),
                ),
          body: user == null
              ? const Center(child: Text('Funcionário não encontrado.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    const Text(
                      'Cadastre a escala com os 7 dias da semana: horas normais e % de extra '
                      'em cada dia (segunda a domingo). Domingo também segue a carga — pode '
                      'trabalhar sem contar tudo como extra. 0h no dia = folga (tudo que '
                      'trabalhar vira extra). Sem período, vale a regra padrão (8h / 4h sábado / '
                      'domingo e feriado 100% extra).',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_busy) const LinearProgressIndicator(),
                    if (periods.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'Nenhum período ainda. Toque em Novo período.',
                          style: TextStyle(color: Color(0xFF5C6570)),
                        ),
                      )
                    else
                      for (final period in periods)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            isThreeLine: true,
                            title: Text(
                              period.label.trim().isEmpty
                                  ? 'Escala'
                                  : period.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: GsTheme.navy,
                              ),
                            ),
                            subtitle: Text(
                              [
                                period.end == null
                                    ? 'De ${fmt.format(period.start)} em diante'
                                    : 'De ${fmt.format(period.start)} até ${fmt.format(period.end!)}',
                                period.weekdaysSummary,
                              ].join('\n'),
                              style: const TextStyle(height: 1.35),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: _busy
                                      ? null
                                      : () => _addOrEdit(existing: period),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Remover',
                                  onPressed: _busy
                                      ? null
                                      : () => _remove(period),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
        );
      },
    );
  }
}

class _SchedulePeriodDialog extends StatefulWidget {
  const _SchedulePeriodDialog({this.initial});

  final WorkSchedulePeriod? initial;

  @override
  State<_SchedulePeriodDialog> createState() => _SchedulePeriodDialogState();
}

class _SchedulePeriodDialogState extends State<_SchedulePeriodDialog> {
  late DateTime _start;
  DateTime? _end;
  late final TextEditingController _label;
  late final TextEditingController _fillHours;
  late final TextEditingController _fillPercent;
  late final List<TextEditingController> _hours;
  late final List<TextEditingController> _percents;
  String? _error;

  String _fmtNum(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _start = dateOnly(initial?.start ?? DateTime.now());
    _end = initial?.end == null ? null : dateOnly(initial!.end!);
    _label = TextEditingController(text: initial?.label ?? '');
    final rules = initial?.weekdays ??
        defaultWeekdayRules(hours: 8, overtimePercent: 50);
    _hours = [
      for (final rule in rules)
        TextEditingController(text: _fmtNum(rule.hours)),
    ];
    _percents = [
      for (final rule in rules)
        TextEditingController(text: _fmtNum(rule.overtimePercent)),
    ];
    _fillHours = TextEditingController(text: '8');
    _fillPercent = TextEditingController(text: '50');
  }

  @override
  void dispose() {
    _label.dispose();
    _fillHours.dispose();
    _fillPercent.dispose();
    for (final c in _hours) {
      c.dispose();
    }
    for (final c in _percents) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _start = dateOnly(picked);
      if (_end != null && _end!.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() => _end = dateOnly(picked));
  }

  void _applyToAll() {
    final hours = double.tryParse(_fillHours.text.trim().replaceAll(',', '.'));
    final percent =
        double.tryParse(_fillPercent.text.trim().replaceAll(',', '.'));
    if (hours == null || hours < 0 || hours > 24) {
      setState(() => _error = 'Horas para aplicar: use 0 a 24.');
      return;
    }
    if (percent == null || percent < 0 || percent > 200) {
      setState(() => _error = '% extra para aplicar: use 0 a 200.');
      return;
    }
    setState(() {
      _error = null;
      for (final c in _hours) {
        c.text = _fmtNum(hours);
      }
      for (final c in _percents) {
        c.text = _fmtNum(percent);
      }
    });
  }

  void _submit() {
    final days = <WorkDayRule>[];
    for (var i = 0; i < 7; i++) {
      final hours =
          double.tryParse(_hours[i].text.trim().replaceAll(',', '.'));
      final percent =
          double.tryParse(_percents[i].text.trim().replaceAll(',', '.'));
      if (hours == null || hours < 0 || hours > 24) {
        setState(
          () => _error =
              '${scheduleWeekdayLabels[i]}: informe as horas (0 a 24).',
        );
        return;
      }
      if (percent == null || percent < 0 || percent > 200) {
        setState(
          () => _error =
              '${scheduleWeekdayLabels[i]}: informe o % de extra (0 a 200).',
        );
        return;
      }
      days.add(WorkDayRule(hours: hours, overtimePercent: percent));
    }
    final positive = [for (final d in days) if (d.hours > 0) d.hours];
    final baseHours = positive.isEmpty
        ? 8.0
        : positive.reduce((a, b) => a + b) / positive.length;
    final basePercent = days.first.overtimePercent;
    Navigator.of(context).pop(
      WorkSchedulePeriod(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        start: _start,
        end: _end,
        weekdays: days,
        hoursPerDay: baseHours.isFinite ? baseHours : 8,
        overtimePercent: basePercent,
        label: _label.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nova carga horária' : 'Editar carga'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Nome da escala (opcional)',
                  hintText: 'Ex.: 6x1, plantão',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStart,
                      child: Text('Início ${fmt.format(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEnd,
                      child: Text(
                        _end == null
                            ? 'Fim (opcional)'
                            : 'Fim ${fmt.format(_end!)}',
                      ),
                    ),
                  ),
                ],
              ),
              if (_end != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _end = null),
                    child: const Text('Sem data final'),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Preencher todos os dias',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fillHours,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Horas',
                        hintText: '8',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fillPercent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '% extra',
                        hintText: '50',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _applyToAll,
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Dias da semana',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Horas = carga normal do dia. % = adicional sobre o que passar. '
                'Domingo com 8h/50% só gera extra depois das 8h.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 7; i++) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        scheduleWeekdayLabels[i],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: GsTheme.navy,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _hours[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Horas',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _percents[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '% extra',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB00020)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('schedule-save-period'),
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
