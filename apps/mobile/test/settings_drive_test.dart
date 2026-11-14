import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AccountApi.useRemote = false;
    await AuthSession.instance.signOut();
    AuthSession.instance.resetForTests();
  });

  testWidgets('configurações mostra a pasta do Google Drive para o Cleber', (
    tester,
  ) async {
    await AuthSession.instance.signIn('cleber', password: '1234');
    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-login')), findsOneWidget);
    expect(find.textContaining('Cleber Guimarães'), findsWidgets);
    expect(find.byKey(const Key('settings-drive')), findsOneWidget);
    expect(find.byKey(const Key('settings-drive-retry')), findsOneWidget);
    expect(find.textContaining('OneDrive'), findsNothing);
    expect(find.textContaining('Microsoft'), findsNothing);
    expect(AuthSession.instance.user?.canSeeOfficeDrive, isTrue);
  });

  testWidgets('técnico não vê a pasta do Google Drive nas configurações', (
    tester,
  ) async {
    await AuthSession.instance.signIn('Felipe');
    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-login')), findsOneWidget);
    expect(find.byKey(const Key('settings-drive')), findsNothing);
    expect(find.textContaining('OneDrive'), findsNothing);
    expect(AuthSession.instance.user?.canSeeOfficeDrive, isFalse);
  });

  testWidgets('salvar na pasta sem planilha avisa e não pede login', (
    tester,
  ) async {
    await AuthSession.instance.signIn('Felipe');
    bool? ready;
    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async => ready = await ensureDriveReady(context),
                child: const Text('salvar pasta'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('salvar pasta'));
    await tester.pumpAndSettle();
    expect(ready, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Microsoft'), findsNothing);
  });

  test('login cleber_guimaraes é tratado como Cleber', () {
    expect(isCleberIdentity(email: '', login: 'cleber_guimaraes'), isTrue);
    expect(
      isCleberIdentity(
        email: 'cleber@gssolucoestec.com.br',
        login: 'cleber_guimaraes',
      ),
      isTrue,
    );
  });

  test('sem acesso à pasta explica a conta dona do Drive', () {
    final text = friendlySheetError(
      'Sem acesso à pasta de arquivos no Google Drive (abc). Detalhe: x',
    );
    expect(text, contains('conta dona da pasta'));
  });

  test('rótulo do Drive usa o e-mail do escritório, não o Gmail pessoal', () {
    expect(
      officeDriveAccountLabel('viniciusmagalhaes2y@gmail.com'),
      'administrativo@gssolucoestec.com.br',
    );
    expect(
      officeDriveAccountLabel('administrativo@gssolucoestec.com.br'),
      'administrativo@gssolucoestec.com.br',
    );
    expect(
      officeDriveAccountLabel(''),
      'administrativo@gssolucoestec.com.br',
    );
  });

  test('limite do Drive aponta para republicar como administrativo@', () {
    final text = friendlySheetError('Limite excedido: Drive.');
    expect(text, contains('administrativo@gssolucoestec.com.br'));
    expect(text, contains('Apps Script'));
    expect(
      friendlySheetError(
        'Limite excedido: Drive (armazenamento cheio). Esvazie a lixeira '
        'e libere espaço na conta administrativo@gssolucoestec.com.br.',
      ),
      contains('sem espaço'),
    );
  });

  test('script no Gmail pessoal marca dono errado mesmo sem flag do GAS', () {
    expect(
      driveOwnerIsWrong(
        flag: false,
        account: 'viniciusmagalhaes2y@gmail.com',
      ),
      isTrue,
    );
    expect(
      driveOwnerWarningText(account: 'viniciusmagalhaes2y@gmail.com'),
      contains('viniciusmagalhaes2y@gmail.com'),
    );
    expect(
      driveOwnerIsWrong(
        flag: false,
        account: 'administrativo@gssolucoestec.com.br',
      ),
      isFalse,
    );
  });
}
