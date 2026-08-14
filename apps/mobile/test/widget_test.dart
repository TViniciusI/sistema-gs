import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/main.dart';

void main() {
  setUp(AuthSession.instance.signOut);

  testWidgets('abre a demonstração do técnico', (tester) async {
    await tester.pumpWidget(const GsApp());
    expect(find.text('Entrar na demonstração'), findsOneWidget);
    expect(find.text('ACESSO AO APP'), findsOneWidget);

    await tester.tap(find.text('Entrar na demonstração'));
    await tester.pumpAndSettle();

    expect(find.text('Minha agenda'), findsOneWidget);
    expect(find.text('GS 036/26'), findsOneWidget);
  });
}
