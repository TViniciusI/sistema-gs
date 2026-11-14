import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/send_os.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:intl/intl.dart';

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
            onPressed: () {
              AuthSession.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: FieldStore.instance,
        builder: (context, _) {
          final user = AuthSession.instance.user;
          final items = user?.seesAllFieldOs == true
              ? [
                  for (final os in FieldStore.instance.officeItems)
                    if (os.status != OsStatus.rascunho) os,
                ]
              : FieldStore.instance.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Os certificados anexados em cada OS aparecem aqui, só neste acesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5C6570), height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final os = items[index];
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
                      'OS ${os.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: GsTheme.navy,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(os.createdAt),
                      style: const TextStyle(color: Color(0xFF5C6570)),
                    ),
                    const SizedBox(height: 8),
                    if (os.certificates.isEmpty &&
                        os.photos.isEmpty &&
                        !os.isSigned)
                      const Text(
                        'Nenhum certificado, foto ou assinatura ainda',
                        style: TextStyle(
                          color: Color(0xFF5C6570),
                          fontSize: 13,
                        ),
                      )
                    else ...[
                      for (final file in os.certificates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${file.name}',
                            style: const TextStyle(
                              color: Color(0xFF5C6570),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Text(
                        '${os.photos.length} foto(s) · ${os.isSigned ? 'Assinado${os.baseSignerLabel == null ? '' : ' por ${os.baseSignerLabel}'}' : 'Sem assinatura'}',
                        style: const TextStyle(
                          color: Color(0xFF5C6570),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      os.emailed
                          ? 'E-mail já enviado para os administrativos'
                          : 'Salvo neste acesso · ainda não enviado',
                      style: TextStyle(
                        fontSize: 12,
                        color: os.emailed ? GsTheme.brass : GsTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => OsHubPage(osId: os.id),
                              ),
                            );
                          },
                          child: const Text('Abrir'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => sendOsFromUi(context, os),
                          icon: const Icon(Icons.email_outlined, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: GsTheme.brass,
                            foregroundColor: Colors.black,
                          ),
                          label: const Text('Enviar e-mail'),
                        ),
                      ],
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
