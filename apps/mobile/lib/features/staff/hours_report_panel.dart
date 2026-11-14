import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/hours_report_pdf.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:intl/intl.dart';

class HoursReportPanel extends StatefulWidget {
  const HoursReportPanel({super.key, this.selectedEmail});

  final String? selectedEmail;

  @override
  State<HoursReportPanel> createState() => HoursReportPanelState();
}

class HoursReportPanelState extends State<HoursReportPanel> {
  RemoteAccount? _technician;
  late DateTime _from;
  late DateTime _to;
  HoursReport? _report;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final period = payrollPeriodFor(now);
    _from = period.from;
    _to = period.to;
    StaffStore.instance.addListener(_onStores);
    FieldStore.instance.addListener(_onStores);
    _applySelectedEmail(widget.selectedEmail, notify: false);
  }

  @override
  void dispose() {
    StaffStore.instance.removeListener(_onStores);
    FieldStore.instance.removeListener(_onStores);
    super.dispose();
  }

  void _onStores() {
    if (!mounted) return;
    final emails = {for (final user in _technicians) user.email};
    if (_technician == null || !emails.contains(_technician!.email)) {
      _applySelectedEmail(widget.selectedEmail);
    } else {
      _rebuild();
    }
  }

  @override
  void didUpdateWidget(covariant HoursReportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedEmail != widget.selectedEmail) {
      _applySelectedEmail(widget.selectedEmail);
    }
  }

  List<RemoteAccount> get _technicians {
    final list = [
      for (final user in StaffStore.instance.employees)
        if (user.active) user,
    ];
    list.sort(
      (a, b) => (a.name.isEmpty ? a.login : a.name).toLowerCase().compareTo(
        (b.name.isEmpty ? b.login : b.name).toLowerCase(),
      ),
    );
    return list;
  }

  void _applySelectedEmail(String? email, {bool notify = true}) {
    final techs = _technicians;
    final needle = (email ?? '').trim().toLowerCase();
    RemoteAccount? match;
    if (needle.isNotEmpty) {
      for (final user in techs) {
        if (user.email.trim().toLowerCase() == needle ||
            user.login.trim().toLowerCase() == needle) {
          match = user;
          break;
        }
      }
    }
    if (match == null && _technician != null) {
      for (final user in techs) {
        if (user.email == _technician!.email) {
          match = user;
          break;
        }
      }
    }
    match ??= techs.isEmpty ? null : techs.first;
    _technician = match;
    _report = _compute();
    if (notify && mounted) setState(() {});
  }

  HoursReport? _compute() {
    final user = _technician;
    if (user == null) return null;
    final account = appUserFromRemote(user);
    final name = account.name.trim().isEmpty ? account.login : account.name.trim();
    return buildHoursReport(
      technicianName: name,
      viewerIds: assigneeKeysFor(account),
      orders: FieldStore.instance.officeItems,
      from: _from,
      to: _to,
    );
  }

  void _rebuild() {
    _report = _compute();
    if (mounted) setState(() {});
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = dateOnly(picked);
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = dateOnly(picked);
        if (_to.isBefore(_from)) _from = _to;
      }
    });
    _rebuild();
  }

  Future<void> _download({required bool pdf}) async {
    final report = _report;
    if (report == null) return;
    setState(() => _busy = true);
    try {
      final stem = hoursReportFileStem(report);
      if (pdf) {
        await downloadRdoFile(
          fileName: '$stem.pdf',
          bytes: await buildHoursReportPdf(report),
        );
      } else {
        await downloadRdoFile(
          fileName: '$stem.csv',
          bytes: utf8.encode(hoursReportCsv(report)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Não baixou o relatório. $error'),
        ),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final techs = _technicians;
    final fmt = DateFormat('dd/MM/yyyy');
    final report = _report;
    return Container(
      key: const Key('hours-report'),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: GsTheme.brass, width: 5),
          top: BorderSide(color: Color(0x331A2330)),
          right: BorderSide(color: Color(0x331A2330)),
          bottom: BorderSide(color: Color(0x331A2330)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Relatório de horas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'O período padrão é o fechamento da GS: dia 24 ao dia 23. Extra depois de 8h no dia (mais 1h de almoço). Sábado: 4h normais, depois extra. Domingo e feriado: só conta extra se houver horário preenchido. Das 22h às 05h: adicional noturno.',
            style: TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 12),
          if (techs.isEmpty)
            const Text(
              'Não há técnico aprovado para analisar.',
              style: TextStyle(color: Color(0xFF5C6570)),
            )
          else ...[
            KeyedSubtree(
              key: ValueKey(_technician?.email ?? ''),
              child: DropdownButtonFormField<String>(
                key: const Key('hours-tech'),
                isExpanded: true,
                initialValue: techs.any((user) => user.email == _technician?.email)
                    ? _technician!.email
                    : null,
                decoration: const InputDecoration(labelText: 'Técnico'),
                items: [
                  for (final user in techs)
                    DropdownMenuItem(
                      value: user.email,
                      child: Text(user.name.isEmpty ? user.login : user.name),
                    ),
                ],
                onChanged: (value) => _applySelectedEmail(value),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('hours-from'),
                    onPressed: () => _pickDate(start: true),
                    child: Text('De ${fmt.format(_from)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('hours-to'),
                    onPressed: () => _pickDate(start: false),
                    child: Text('Até ${fmt.format(_to)}'),
                  ),
                ),
              ],
            ),
            if (report != null) ...[
              const SizedBox(height: 14),
              Text(
                'Total ${formatWorkedHours(report.totalWorkedMinutes)}  ·  extras ${formatWorkedHours(report.totalExtraMinutes)}  ·  noturno ${formatWorkedHours(report.totalNightMinutes)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              for (final day in report.days.take(14))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${fmt.format(day.date)} · ${day.weekdayLabel} · ${day.holidayLabel} · ${day.place} · ${formatWorkedHours(day.workedMinutes)} · extra ${formatWorkedHours(day.extraMinutes)} · noturno ${formatWorkedHours(day.nightMinutes)}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                ),
              if (report.days.length > 14)
                Text(
                  '+${report.days.length - 14} dia(s) no PDF e na planilha.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('hours-download-pdf'),
                onPressed: _busy ? null : () => _download(pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                label: Text(_busy ? 'Preparando…' : 'Baixar relatório em PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('hours-download-csv'),
                onPressed: _busy ? null : () => _download(pdf: false),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Baixar planilha (Excel/CSV)'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
