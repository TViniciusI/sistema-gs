import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/staff_docs_store.dart';
import 'package:gs_mobile/demo/auth.dart';

void main() {
  test('e-mail só sai depois da nuvem', () {
    expect(
      staffDocShouldSendMail(
        cloudSynced: false,
        requiresSignature: true,
        notifyStaff: true,
      ),
      isFalse,
    );
    expect(
      staffDocShouldSendMail(
        cloudSynced: true,
        requiresSignature: true,
        notifyStaff: true,
      ),
      isTrue,
    );
    expect(
      staffDocShouldSendMail(
        cloudSynced: true,
        requiresSignature: true,
        notifyStaff: false,
      ),
      isFalse,
    );
    expect(
      staffDocShouldSendMail(
        cloudSynced: true,
        requiresSignature: false,
        notifyStaff: true,
      ),
      isFalse,
    );
    expect(
      staffDocShouldSendMail(
        cloudSynced: true,
        requiresSignature: true,
        notifyStaff: true,
        mailSent: true,
      ),
      isFalse,
    );
  });

  test('técnico com permissão tecnico vê Meus documentos', () {
    final user = AppUser(
      email: 'tec@gs.com',
      login: 'tec',
      name: 'Técnico',
      role: 'tecnico',
      isDeveloper: false,
      isClient: false,
      isTechnician: true,
      permissions: 'tecnico',
    );
    expect(user.canSeeDocs, isTrue);
    expect(user.canAccess('documentos'), isTrue);
  });

  test('needsMailRetry após falha de nuvem com assinatura pedida', () {
    final doc = StaffDocument(
      id: '1',
      staffEmail: 'tec@gs.com',
      name: 'holerite.pdf',
      kind: OsFileKind.certificate,
      createdAt: DateTime(2026, 11, 11),
      requiresSignature: true,
      cloudSynced: false,
      mailSent: false,
      remoteError: 'DriveApp',
      mailError: 'Arquivo não entrou na nuvem',
    );
    expect(doc.needsCloudRetry, isTrue);
    expect(doc.needsMailRetry, isTrue);
    expect(doc.hasSyncIssue, isTrue);
  });
}
