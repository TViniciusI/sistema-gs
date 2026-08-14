import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/demo/inbox.dart';

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificados'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: AuthSession.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: OfficeInbox.instance,
        builder: (context, _) {
          final items = OfficeInbox.instance.certificates;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cert = items[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0x331A2330)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificado ${cert.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: GsTheme.navy,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cert.workOrderNumber} · ${cert.client}',
                      style: const TextStyle(color: Color(0xFF5C6570)),
                    ),
                    Text(
                      cert.fileName ?? cert.instrument,
                      style: const TextStyle(
                        color: Color(0xFF5C6570),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cert.sentToOffice
                          ? 'Anexado no escritório · ${cert.issuedAt}'
                          : 'No aparelho · aguardando sincronizar',
                      style: TextStyle(
                        fontSize: 12,
                        color: cert.sentToOffice ? GsTheme.brass : GsTheme.navy,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
