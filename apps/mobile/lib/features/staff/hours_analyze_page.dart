import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/features/staff/hours_report_panel.dart';

/// Tela dedicada de horas (abre ao tocar em Analisar horas).
class HoursAnalyzePage extends StatefulWidget {
  const HoursAnalyzePage({super.key, required this.email});

  final String email;

  @override
  State<HoursAnalyzePage> createState() => _HoursAnalyzePageState();
}

class _HoursAnalyzePageState extends State<HoursAnalyzePage> {
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await Future.wait([
      FieldStore.instance.sync(),
      StaffStore.instance.refresh(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  RemoteAccount? get _match {
    final needle = widget.email.trim().toLowerCase();
    for (final user in StaffStore.instance.employees) {
      if (user.email.trim().toLowerCase() == needle) return user;
      if (user.login.trim().toLowerCase() == needle) return user;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    final title = match == null
        ? 'Horas'
        : 'Horas · ${(match.name.trim().isEmpty ? match.login : match.name)}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const Text(
                  'Entrada e saída do RDO, menos almoço. Extra depois de 8h no dia '
                  '(sábado depois de 4h; domingo e feriado o dia todo, só se houver horário). '
                  'Sem serviço, deixe o horário em branco — não conta hora nem extra. '
                  'O fechamento do mês vai do dia 24 ao dia 23. '
                  'O app usa minutos exatos (ex.: 3h 25min), sem arredondar para 3h 30min.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF5C6570),
                  ),
                ),
                const SizedBox(height: 14),
                HoursReportPanel(selectedEmail: widget.email),
              ],
            ),
    );
  }
}
