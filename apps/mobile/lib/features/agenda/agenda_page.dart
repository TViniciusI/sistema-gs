import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/catalog.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_detail_page.dart';

class AgendaPage extends StatelessWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha agenda'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: AuthSession.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0x1AC59E39),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${user?.name ?? 'Técnico'} · registros e anexos ficam no aparelho até sincronizar',
              style: const TextStyle(color: GsTheme.navy, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: demoWorkOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final os = demoWorkOrders[index];
                return Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OsDetailPage(os: os),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: os.status.contains('atendimento')
                                ? GsTheme.brass
                                : const Color(0x331A2330),
                            width: 3,
                          ),
                          top: const BorderSide(color: Color(0x331A2330)),
                          right: const BorderSide(color: Color(0x331A2330)),
                          bottom: const BorderSide(color: Color(0x331A2330)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  os.number,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: GsTheme.navy,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${os.client}\n${os.site} · ${os.date}',
                                  style: const TextStyle(
                                    color: Color(0xFF5C6570),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(label: os.status),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final warn = label.contains('atendimento') || label.contains('Atribu');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: warn ? const Color(0x26C59E39) : const Color(0x140C1F33),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: warn ? GsTheme.brass : GsTheme.navy,
        ),
      ),
    );
  }
}
