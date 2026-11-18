import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
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

  test('isMailAddress rejeita handle @login sem domínio', () {
    expect(isMailAddress('@willcardim'), isFalse);
    expect(isMailAddress('willcardim'), isFalse);
    expect(isMailAddress('willcardim@'), isFalse);
    expect(isMailAddress('cleber@gssolucoestec.com.br'), isTrue);
    expect(isMailAddress('felps.santos933@gmail.com'), isTrue);
  });

  test('parseRecipientEmails ignora @willcardim e mantém e-mails válidos', () {
    expect(
      parseRecipientEmails(
        '@willcardim, cleber@gssolucoestec.com.br, felps.santos933@gmail.com',
      ),
      [
        'cleber@gssolucoestec.com.br',
        'felps.santos933@gmail.com',
      ],
    );
  });

  test('técnicos da OS não incluem handle @login', () {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'willian@gssolucoestec.com.br',
        login: 'willcardim',
        name: 'Willian Cardim',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    ];
    final os = SavedOs(
      id: 'os-tech',
      number: '048/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 1, 1),
      files: const [],
      technicianEmails: const [
        '@willcardim',
        'cleber@gssolucoestec.com.br',
        'felps.santos933@gmail.com',
      ],
    );
    final emails = technicianEmailsForOs(os);
    expect(emails, isNot(contains('@willcardim')));
    expect(emails, contains('willian@gssolucoestec.com.br'));
    expect(emails, contains('cleber@gssolucoestec.com.br'));
    expect(emails, contains('felps.santos933@gmail.com'));
    StaffStore.instance.users = [];
  });
}
