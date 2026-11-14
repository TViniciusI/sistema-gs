import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/access_gate.dart';
import 'package:gs_mobile/core/config.dart';
import 'package:gs_mobile/core/theme.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controle do app')),
      body: ListenableBuilder(
        listenable: AccessGate.instance,
        builder: (context, _) {
          final gate = AccessGate.instance;
          final blocked = gate.cleberBlocked;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Acesso do cliente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pedidos de conta nova e o setor de cada um ficam em Funcionários, no início.',
                style: TextStyle(height: 1.45, color: Color(0xB31A2330)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0x331A2330)),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Bloquear acesso do Cleber',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: GsTheme.navy,
                    ),
                  ),
                  subtitle: Text(
                    blocked
                        ? 'O e-mail administrativo está sem acesso.'
                        : 'O e-mail administrativo pode entrar.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: blocked,
                  activeThumbColor: GsTheme.brass,
                  onChanged: (value) => gate.setCleberBlocked(value),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppConfig.loginGateUrl.isEmpty
                    ? 'A planilha ainda não está ligada neste build. O bloqueio vale neste aparelho. Quando você publicar o Google Script, o Cleber fica sem acesso em qualquer celular.'
                    : gate.remoteLinked
                    ? 'Planilha ligada. O bloqueio vale em qualquer aparelho.'
                    : (gate.lastError ??
                          'Planilha configurada, mas não respondeu agora.'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xB31A2330),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
