import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail.dart';

void main() {
  test('destino Cliente usa o e-mail da base', () {
    expect(
      destinationEmailsFor(
        audience: MailAudience.client,
        clientEmail: 'base@cliente.com',
      ),
      'base@cliente.com',
    );
    expect(
      destinationEmailsFor(
        audience: MailAudience.both,
        clientEmail: 'base@cliente.com',
      ),
      contains('base@cliente.com'),
    );
  });

  test('detecta cliente nos destinatários do envio', () {
    final os = SavedOs(
      id: 'os1',
      number: '048/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 1, 1),
      files: const [],
      rdo: const RdoData(
        client: 'Cliente X',
        baseEmail: 'base@cliente.com',
      ),
    );
    expect(mailRecipientsIncludeClient(os, ['base@cliente.com']), isTrue);
    expect(
      mailRecipientsIncludeClient(os, [
        'administrativo@gssolucoestec.com.br',
      ]),
      isFalse,
    );
  });
}
