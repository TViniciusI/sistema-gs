import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/data/br_holidays.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_math.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail.dart';
import 'package:gs_mobile/data/office_store.dart';
import 'package:gs_mobile/data/prefs_json.dart';
import 'package:gs_mobile/data/send_os.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/tabelas20.dart';
import 'package:gs_mobile/data/tabelas_alcool.dart';
import 'package:gs_mobile/data/tabelas_pdf.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_create_page.dart';
import 'package:gs_mobile/features/os/rdo_form_page.dart';
import 'package:gs_mobile/features/clients/client_edit_page.dart';
import 'package:gs_mobile/features/calibration/calibration_job_page.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _login(
  WidgetTester tester,
  String user, {
  String password = '',
}) async {
  await tester.enterText(find.byKey(const Key('login-user')), user);
  if (password.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('login-password')), password);
  }
  await tester.scrollUntilVisible(
    find.byKey(const Key('login-submit')),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

Future<void> _openHomeCard(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  final scrollable = find.descendant(
    of: find.byKey(const Key('home-list')),
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
  final viewHeight = tester.getSize(find.byType(MaterialApp)).height;
  var box = tester.getRect(finder);
  if (box.bottom > viewHeight - 96) {
    await tester.drag(
      scrollable,
      Offset(0, -(box.bottom - (viewHeight - 120))),
    );
    await tester.pumpAndSettle();
    box = tester.getRect(finder);
  }
  await tester.tapAt(Offset(box.center.dx, box.top + 28));
  await tester.pumpAndSettle();
}

Future<void> _pageBack(WidgetTester tester) async {
  final pt = find.byTooltip('Voltar');
  final en = find.byTooltip('Back');
  final button = pt.evaluate().isNotEmpty ? pt : en;
  expect(button, findsOneWidget);
  await tester.tap(button);
}

Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sair'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AccountApi.useRemote = false;
    StaffStore.instance.users = [];
    await AuthSession.instance.signOut();
    AuthSession.instance.resetForTests();
    CalibrationStore.instance.resetForTest();
    CalibrationCatalog.instance.resetForTest();
    ClientStore.instance.resetForTest();
  });

  testWidgets('depois do login há as telas de gerar OS e da área do técnico', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);

    await _login(tester, 'Cleber', password: '1234');

    expect(find.text('Agenda da semana'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-gerar-os')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Funcionários'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Gerar OS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Área do técnico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Área do técnico'), findsOneWidget);
    expect(find.byKey(const Key('tab-calibracao')), findsOneWidget);
    expect(find.text('Calibração'), findsOneWidget);
    expect(find.byKey(const Key('tab-tabelas')), findsOneWidget);
    expect(find.text('Tabelas'), findsOneWidget);
    expect(find.byKey(const Key('tab-config')), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
  });

  testWidgets('aba calibração abre volumétrica com critérios do cliente', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');

    await tester.tap(find.byKey(const Key('tab-calibracao')));
    await tester.pumpAndSettle();
    expect(find.text('Nova calibração'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calibracao-nova-volumetrica')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calibracao-limite-repetibilidade')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('conferência fica dispensada'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('conferência fica dispensada'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('calibracao-gerar-certificado')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('calibracao-gerar-certificado')),
      findsOneWidget,
    );
  });

  testWidgets(
    'volumétrica invertida mostra cálculo objeto dividido pelo padrão',
    (tester) async {
      await tester.pumpWidget(const GsApp());
      await tester.pumpAndSettle();
      await _login(tester, 'Cleber', password: '1234');

      await tester.tap(find.byKey(const Key('tab-calibracao')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('calibracao-nova-volumetrica-invertida')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Volumétrica invertida'), findsWidgets);
      await tester.scrollUntilVisible(
        find.textContaining('Cálculo invertido: fator Fc = objeto ÷ padrão'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Cálculo invertido: fator Fc = objeto ÷ padrão'),
        findsOneWidget,
      );
      expect(find.text('Objeto (L)'), findsWidgets);
      expect(find.text('Padrão (L)'), findsWidgets);
    },
  );

  testWidgets('telemetria abre formulário de tanque com nível e temperatura', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');

    await tester.tap(find.byKey(const Key('tab-calibracao')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calibracao-nova-telemetria')));
    await tester.pumpAndSettle();
    expect(find.text('Telemetria'), findsWidgets);
    expect(
      find.textContaining('Medidor de Nível tipo Servo Operado'),
      findsWidgets,
    );
    await tester.scrollUntilVisible(
      find.text('Device ID'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Device ID'), findsOneWidget);
    expect(find.text('Concentradora / displacer'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dados encontrados'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dados encontrados'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Temperatura'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Nível'), findsWidgets);
    expect(find.textContaining('Temperatura'), findsWidgets);
  });

  testWidgets(
    'ensaio Coriolis mostra fator do medidor com coeficientes do modelo',
    (tester) async {
      await tester.pumpWidget(const GsApp());
      await tester.pumpAndSettle();
      await _login(tester, 'Cleber', password: '1234');

      await tester.tap(find.byKey(const Key('tab-calibracao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calibracao-nova-volumetrica')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fator do Medidor'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('calibracao-principio')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('calibracao-principio')),
        'Coriolis',
      );
      await tester.pumpAndSettle();

      final flowCal = find.byKey(const Key('calibracao-coriolis-Flow Cal.'));
      await tester.ensureVisible(flowCal);
      await tester.pumpAndSettle();
      expect(find.textContaining('Fator do Medidor'), findsOneWidget);
      await tester.tap(flowCal);
      await tester.pumpAndSettle();
      expect(find.text('Encontrado'), findsOneWidget);
      expect(find.byKey(const Key('calibracao-coriolis-D1')), findsOneWidget);
      expect(find.byKey(const Key('calibracao-coriolis-FC')), findsOneWidget);
    },
  );

  testWidgets('lista de calibração deixa excluir um ensaio de teste', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');

    await tester.tap(find.byKey(const Key('tab-calibracao')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calibracao-nova-volumetrica')));
    await tester.pumpAndSettle();
    await _pageBack(tester);
    await tester.pumpAndSettle();

    expect(CalibrationStore.instance.items, hasLength(1));
    expect(find.textContaining('1 calibração'), findsOneWidget);
    final jobId = CalibrationStore.instance.items.single.id;
    await tester.tap(find.byKey(const Key('calibracao-abrir-salvas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('calibracao-excluir-$jobId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calibracao-excluir-confirmar')));
    await tester.pumpAndSettle();
    expect(CalibrationStore.instance.items, isEmpty);
    expect(find.textContaining('Nenhuma calibração ainda'), findsOneWidget);
  });

  testWidgets('lista de calibração filtra rascunho e concluídas', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');

    await tester.tap(find.byKey(const Key('tab-calibracao')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calibracao-filtro-todas')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calibracao-nova-volumetrica')));
    await tester.pumpAndSettle();
    await _pageBack(tester);
    await tester.pumpAndSettle();

    expect(CalibrationStore.instance.items, hasLength(1));
    expect(find.textContaining('1 calibração'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calibracao-filtro-concluidas')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma neste filtro.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calibracao-filtro-todas')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 calibração'), findsOneWidget);
  });

  testWidgets('cadastro de padrão vencido aparece no sino da calibração', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');

    await tester.tap(find.byKey(const Key('tab-calibracao')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('calibracao-atalho-padroes')),
    );
    await tester.tap(find.byKey(const Key('calibracao-atalho-padroes')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('padrao-novo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('padrao-nome')), 'GS-001');
    await tester.enterText(
      find.byKey(const Key('padrao-validade')),
      '01/01/2020',
    );
    await tester.ensureVisible(find.byKey(const Key('padrao-salvar')));
    await tester.tap(find.byKey(const Key('padrao-salvar')));
    await tester.pumpAndSettle();
    expect(find.text('Vencido'), findsWidgets);

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calibracao-alertas')));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.textContaining('vencido'), findsWidgets);
  });

  testWidgets('app começa zerado, sem OS de demonstração', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-gerar-os'));
    expect(find.textContaining('Nenhuma OS ainda'), findsOneWidget);
    expect(find.text('OS 036/26'), findsNothing);

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await _openHomeCard(tester, const Key('open-clientes'));
    expect(
      find.textContaining('Nenhum cliente na empresa ainda'),
      findsOneWidget,
    );
  });

  testWidgets('criar conta pede login, senha, telefone, e-mail e setor', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-signup')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signup-login')), findsOneWidget);
    expect(find.byKey(const Key('signup-password')), findsOneWidget);
    expect(find.byKey(const Key('signup-phone')), findsOneWidget);
    expect(find.byKey(const Key('signup-email')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('signup-role-admin')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Administrativo'), findsOneWidget);
    expect(find.text('Técnico'), findsOneWidget);
  });

  testWidgets('técnico só vê a agenda, sem gerar OS', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Felipe');

    expect(find.text('Gerar OS'), findsNothing);
    expect(find.text('Clientes'), findsNothing);
    expect(find.text('Funcionários'), findsNothing);
    expect(find.text('Agenda da semana'), findsOneWidget);
    expect(find.text('Área do técnico'), findsOneWidget);
    expect(find.byKey(const Key('tab-calibracao')), findsNothing);
    expect(find.byKey(const Key('tab-tabelas')), findsOneWidget);
    expect(find.byKey(const Key('tab-config')), findsOneWidget);
  });

  testWidgets('técnico abre Tabelas 20 °C e vê o cálculo a 20 °C', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Felipe');
    await tester.tap(find.byKey(const Key('tab-tabelas')));
    await tester.pumpAndSettle();

    expect(find.text('Conversão de derivados de petróleo'), findsOneWidget);
    expect(find.text('Correção a 20 °C — álcool'), findsOneWidget);
    expect(find.text('Conversão de volume'), findsNothing);
    await tester.ensureVisible(find.text('Correção a 20 °C — álcool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correção a 20 °C — álcool'));
    await tester.pumpAndSettle();
    expect(find.text('Misturas etanol-água'), findsOneWidget);
    expect(find.text('Nome do produto'), findsOneWidget);
    expect(find.text('Número do sistema'), findsOneWidget);
    expect(find.text('Densidade da amostra (kg/m³)'), findsOneWidget);
    expect(find.text('Temperatura da amostra (°C)'), findsOneWidget);

    await tester.ensureVisible(
      find.text('Conversão de derivados de petróleo', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Conversão de derivados de petróleo', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Amostra'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Volume a 20 do objeto (L20)', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Volume a 20 do objeto (L20)'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Densidade a 20 °C', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fator de correção (CTL)'), findsOneWidget);
    expect(find.text('Salvar em PDF'), findsOneWidget);
  });

  testWidgets('gerar OS pede CNPJ, dados do RDO e o técnico', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-gerar-os'));
    await tester.tap(find.text('Nova OS'));
    await tester.pumpAndSettle();

    expect(find.byType(OsCreatePage), findsOneWidget);
    expect(find.text('Início do serviço'), findsOneWidget);
    expect(find.byKey(const Key('os-starts-at')), findsOneWidget);
    expect(find.text('CNPJ'), findsOneWidget);
    expect(find.text('Contratante'), findsOneWidget);
    expect(find.text('Dados do RDO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-felps1255')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delegar técnicos'), findsOneWidget);
    expect(find.text('Felipe Souza'), findsOneWidget);
    expect(find.text('Passo 1 de 3 · Dia'), findsNothing);
  });

  testWidgets('delegar OS coloca o serviço na agenda do técnico', (
    tester,
  ) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-gerar-os'));
    await tester.tap(find.text('Nova OS'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('os-number')), '001/26');
    await tester.enterText(
      find.byKey(const Key('os-cnpj')),
      '12.345.678/0001-99',
    );
    await tester.enterText(find.byKey(const Key('os-client')), 'Cliente Teste');

    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-felps1255')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('tech-felps1255')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('os-dispatch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('os-dispatch')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('OS 001/26'), findsWidgets);
    expect(find.textContaining('Felipe Souza'), findsWidgets);

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await _logout(tester);

    await _login(tester, 'Felipe');
    await _openHomeCard(tester, const Key('open-tecnico'));

    expect(find.text('Nova OS'), findsNothing);
    expect(find.text('OS 001/26'), findsWidgets);
    expect(find.text('Preencher RDO de hoje'), findsOneWidget);

    await tester.tap(find.text('Preencher RDO de hoje'));
    await tester.pumpAndSettle();

    expect(find.byType(RdoFormPage), findsOneWidget);
    expect(find.textContaining('DADOS DA OS'), findsOneWidget);
    expect(find.textContaining('Cliente Teste'), findsWidgets);
    expect(find.text('Contratante'), findsNothing);
    expect(find.byKey(const Key('os-cnpj')), findsNothing);
    expect(find.byKey(const Key('rdo-description')), findsOneWidget);
  });

  testWidgets('uma OS pode ir para a agenda de dois técnicos', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-gerar-os'));
    await tester.tap(find.text('Nova OS'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('os-number')), '003/26');
    await tester.enterText(
      find.byKey(const Key('os-cnpj')),
      '12.345.678/0001-99',
    );
    await tester.enterText(find.byKey(const Key('os-client')), 'Cliente Dois');

    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-felps1255')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('tech-felps1255')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-nascimento')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('tech-nascimento')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('os-dispatch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('os-dispatch')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.textContaining('Felipe Souza'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('Andre') == true ||
                widget.data?.contains('André') == true),
      ),
      findsWidgets,
    );

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await _logout(tester);

    await _login(tester, 'Andre');
    await _openHomeCard(tester, const Key('open-tecnico'));
    expect(find.text('OS 003/26'), findsWidgets);

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await _logout(tester);

    await _login(tester, 'Felipe');
    await _openHomeCard(tester, const Key('open-tecnico'));
    expect(find.text('OS 003/26'), findsWidgets);
  });

  testWidgets('gerar OS guarda o cliente para a próxima OS', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-gerar-os'));
    await tester.tap(find.text('Nova OS'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('os-number')), '002/26');
    await tester.enterText(
      find.byKey(const Key('os-cnpj')),
      '11.222.333/0001-44',
    );
    await tester.enterText(
      find.byKey(const Key('os-client')),
      'Terminal Norte',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-felps1255')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('tech-felps1255')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('os-dispatch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('os-dispatch')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _pageBack(tester);
    await tester.pumpAndSettle();
    await _openHomeCard(tester, const Key('open-clientes'));

    expect(find.text('Terminal Norte'), findsWidgets);
    expect(find.textContaining('11.222.333/0001-44'), findsWidgets);
  });

  testWidgets(
    'escolher cliente permite tipo de serviço sem amarrar equipamento',
    (tester) async {
      await ClientStore.instance.save(
        SavedClient(
          id: 'cli-ale',
          name: 'ALE COMBUSTÍVEL S.A',
          cnpj: '00.111.222/0001-33',
          systemType: 'Carga',
          service: 'Calibração',
          equipment: const [
            ClientEquipment(
              id: 'eq-carga',
              tag: 'FT-01',
              systemType: 'Carga',
              equipmentType: 'Medidor',
            ),
            ClientEquipment(
              id: 'eq-descarga',
              tag: 'FT-02',
              systemType: 'Descarga',
              equipmentType: 'Medidor',
            ),
          ],
          updatedAt: DateTime(2026, 8, 24),
        ),
        syncRemote: false,
      );

      await tester.pumpWidget(
        MaterialApp(theme: GsTheme.data, home: const OsCreatePage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pick-client-cli-ale')));
      await tester.pumpAndSettle();

      expect(find.text('Equipamentos cadastrados'), findsNothing);
      expect(find.text('Tipo de serviço'), findsOneWidget);

      final serviceChip = find.byKey(const Key('os-service-configuracao'));
      await tester.scrollUntilVisible(
        serviceChip,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(serviceChip);
      await tester.pumpAndSettle();

      final serviceField = find.byKey(const Key('os-service'));
      await tester.scrollUntilVisible(
        serviceField,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(serviceField).controller?.text,
        'Configuração',
      );
    },
  );

  test('cadastro recusa e-mail do Cleber mesmo com outro login', () {
    expect(
      reservedSignupError(
        email: 'Cleber@gssolucoestec.com.br',
        login: 'tecnico',
      ),
      contains('e-mail é do Cleber'),
    );
    expect(
      reservedSignupError(email: 'joao@empresa.com', login: 'tecnico'),
      isNull,
    );
    expect(
      reservedSignupError(email: 'joao@empresa.com', login: 'cleber'),
      contains('login cleber'),
    );
  });

  test('cleber é técnico e administrativo, separado da GS Soluções', () {
    expect(matchUser('cleber')?.canGenerateOs, isTrue);
    expect(matchUser('cleber')?.canWorkField, isTrue);
    expect(matchUser('cleber')?.canSeeTables, isTrue);
    expect(matchUser('cleber')?.canSeeCalibration, isTrue);
    expect(matchUser('vinicius')?.canSeeCalibration, isTrue);
    expect(matchUser('gssolucoes')?.canSeeCalibration, isTrue);
    expect(matchUser('felipe')?.canSeeCalibration, isFalse);
    expect(matchUser('felipe')?.canIssueCertificate, isFalse);
    expect(matchUser('cleber')?.canIssueCertificate, isTrue);
    expect(
      felipeUser
          .copyWith(calibrationAccess: CalibrationAccess.fill)
          .canSeeCalibration,
      isTrue,
    );
    expect(
      felipeUser
          .copyWith(calibrationAccess: CalibrationAccess.fill)
          .canIssueCertificate,
      isFalse,
    );
    expect(
      felipeUser
          .copyWith(calibrationAccess: CalibrationAccess.issue)
          .canIssueCertificate,
      isTrue,
    );
    expect(matchUser('cleber')?.seesAllFieldOs, isTrue);
    expect(matchUser('cleber')?.homeAgendaOnlyMine, isTrue);
    expect(matchUser('gssolucoes')?.homeAgendaOnlyMine, isFalse);
    expect(matchUser('felipe')?.homeAgendaOnlyMine, isTrue);
    expect(
      canonicalSessionUser(
        AppUser(
          email: 'cleber@gssolucoestec.com.br',
          login: 'cleber',
          name: 'Felipe Souza',
          role: 'Técnico',
          isDeveloper: false,
          isClient: false,
          isTechnician: true,
          sector: 'admin',
        ),
      ).name,
      'Cleber Guimarães',
    );
    expect(matchUser('cleber')?.isTechnician, isTrue);
    expect(matchUser('cleber')?.canManageStaff, isTrue);
    expect(matchUser('gssolucoes')?.canManageStaff, isTrue);
    expect(matchUser('vinicius')?.canManageStaff, isTrue);
    expect(matchUser('cleber')?.email, 'cleber@gssolucoestec.com.br');
    expect(matchUser('cleber')?.name, 'Cleber Guimarães');
    expect(matchUser('gssolucoes')?.name, 'GS Soluções');
    expect(matchUser('gssolucoes')?.login, 'gssolucoes');
    expect(matchUser('gs')?.email, 'administrativo@gssolucoestec.com.br');
    expect(matchUser('administrativo')?.name, 'GS Soluções');
    expect(
      isCompanyOwnerIdentity(
        email: 'cleber@gssolucoestec.com.br',
        login: 'cleber guimarães',
      ),
      isTrue,
    );
    expect(
      isPrincipalIdentity(
        email: 'administrativo@gssolucoestec.com.br',
        login: 'cleber',
      ),
      isTrue,
    );
    final remote = appUserFromRemote(
      const RemoteAccount(
        email: 'cleber@gssolucoestec.com.br',
        login: 'cleber guimarães',
        name: 'Cleber Guimarães',
        phone: '21995788574',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    );
    expect(remote.login, 'cleber');
    expect(remote.canGenerateOs, isTrue);
    expect(remote.canSeeTables, isTrue);
    expect(remote.canSeeCalibration, isTrue);
    expect(remote.isTechnician, isTrue);
    expect(remote.role, 'Técnico e administrativo');
    final dev = appUserFromRemote(
      const RemoteAccount(
        email: 'viniciusmagalhaes2y@gmail.com',
        login: 'vinicius',
        name: 'Vinicius Magalhães',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    );
    expect(dev.isDeveloper, isTrue);
    expect(dev.isDevAccount, isTrue);
    expect(dev.canSeeCalibration, isTrue);
    expect(
      AppUser.fromJson(const {
        'email': 'viniciusmagalhaes2y@gmail.com',
        'login': 'vinicius',
        'name': 'Vinicius',
        'role': 'Técnico',
        'isDeveloper': false,
        'isClient': false,
      }).isDevAccount,
      isTrue,
    );
    expect(
      RemoteAccount.fromJson(const {
        'email': 'felps1255@gssolucoestec.com.br',
        'login': 'felps1255',
        'name': 'Felipe Souza',
        'role': 'tecnico',
        'status': 'aprovado',
        'active': true,
        'funcao': 'Suporte Técnico',
      }).funcao,
      'Suporte Técnico',
    );
    final company = appUserFromRemote(
      const RemoteAccount(
        email: 'administrativo@gssolucoestec.com.br',
        login: 'cleber',
        name: 'Cleber Guimarães',
        phone: '',
        role: 'admin',
        status: 'aprovado',
        active: true,
      ),
    );
    expect(company.login, 'gssolucoes');
    expect(company.name, 'GS Soluções');
    expect(company.isTechnician, isFalse);
    expect(isUnsupportedSheetAction('Ação inválida'), isTrue);
  });

  test('correção a 20 °C de derivados segue o cálculo da GS', () {
    final result = convertDerivados(
      densityAmbient: 723,
      temperature: 25,
      volumeAmbient: 10000,
      temperatureCt: 25,
      volumeDanfe: 9940,
    );
    expect(result.density20, closeTo(727.096, 0.01));
    expect(result.ctl, closeTo(0.9943, 0.0001));
    expect(result.volume20, closeTo(9943, 2));
    expect(result.variance, closeTo(3, 2));
    expect(result.variancePercent, closeTo(0.0302, 0.01));
    expect(formatPt(result.ctl, 4), '0,9943');
  });

  test('correção S10 na planilha GS (824,20 kg/m³ · 32,18 °C)', () {
    final result = convertDerivados(
      densityAmbient: 824.20,
      temperature: 32.18,
      volumeAmbient: 55548,
      temperatureCt: 36.12,
      volumeDanfe: 54803.66,
    );
    expect(result.density20, closeTo(832.35, 0.05));
    expect(result.ctl, closeTo(0.9866, 0.0001));
    expect(result.volume20, closeTo(54803.66, 0.01));
    expect(result.variance, closeTo(0, 0.01));
  });

  test('validação derivados 872,84 · 36,12 °C bate planilha GS', () {
    final result = convertValidacao(
      volumeBaseAmbient: 55548,
      densityAmbient: 872.84,
      temperature: 36.12,
      volumeSistema: 49880,
    );
    expect(result.base.density20, closeTo(883.179, 0.01));
    expect(result.base.ctl, closeTo(0.9879, 0.0001));
    expect(result.base.volume20, closeTo(54875.87, 0.01));
    expect(result.varianceLit, closeTo(-4995.87, 0.1));
    expect(result.variancePct, closeTo(-9.104, 0.01));
  });

  test('correção a 20 °C de álcool usa tabela INPM NBR 5992', () {
    final result = convertAlcool(
      densityAmbient: 777.47,
      temperature: 32.67,
      volumeAmbient: 10000,
      temperatureCt: 32.67,
      volumeDanfe: 9940,
    );
    expect(result.inpm, closeTo(100, 0.05));
    expect(result.density20, closeTo(789.23, 0.05));
    expect(result.ctl, closeTo(0.9866, 0.0001));
    expect(result.volume20, closeTo(9866, 2));
  });

  test('parsePtNumber entende milhar brasileiro (50.000 → 50000)', () {
    expect(parsePtNumber('50.000'), 50000);
    expect(parsePtNumber('49.975'), 49975);
    expect(parsePtNumber('59.654'), 59654);
    expect(parsePtNumber('824,20'), 824.20);
    expect(parsePtNumber('20,5'), 20.5);
  });

  test(
    'correção álcool 809 · 50.000 L bate planilha (entrada com ponto milhar)',
    () {
      expect(parsePtNumber('50.000'), 50000);
      final result = convertAlcool(
        densityAmbient: parsePtNumber('809')!,
        temperature: parsePtNumber('20')!,
        volumeAmbient: parsePtNumber('50.000')!,
        temperatureCt: parsePtNumber('20,5')!,
        volumeDanfe: parsePtNumber('59.654')!,
      );
      expect(result.inpm, closeTo(93.27, 0.01));
      expect(result.density20, closeTo(809, 0.01));
      expect(result.ctl, closeTo(0.9995, 0.0001));
      expect(result.volume20, closeTo(49975, 1));
      expect(result.weight, closeTo(40429.775, 1));
      expect(result.variance, closeTo(-9679, 2));
    },
  );

  test('correção álcool 800 · 29,45 °C · DANFE 49.600 L — perda −95 L20', () {
    expect(parsePtNumber('49,600'), 49600);
    final result = convertAlcool(
      densityAmbient: 800,
      temperature: 29.45,
      volumeAmbient: 50000,
      temperatureCt: 29.45,
      volumeDanfe: 49600,
    );
    expect(result.inpm, closeTo(93.53, 0.01));
    expect(result.density20, closeTo(808.28, 0.01));
    expect(result.ctl, closeTo(0.9901, 0.0001));
    expect(result.volume20, closeTo(49505, 0));
    expect(result.variance, closeTo(-95, 0));
  });

  test('correção álcool 805 kg/m³ · 30 °C bate planilha NBR 5992', () {
    final result = convertAlcool(
      densityAmbient: 805,
      temperature: 30,
      volumeAmbient: 50000,
      temperatureCt: 32.7,
    );
    expect(result.inpm, closeTo(91.54, 0.01));
    expect(result.density20, closeTo(813.74, 0.01));
    expect(result.ctl, closeTo(0.9868, 0.0001));
    expect(result.volume20, closeTo(49340, 1));
  });

  test('conversão de volume mostra erro da comparação em %', () {
    final result = convertValidacao(
      volumeBaseAmbient: 55548,
      densityAmbient: 872.84,
      temperature: 36.12,
      volumeSistema: 49880,
    );
    expect(result.base.volume20, greaterThan(0));
    expect(
      result.varianceLit,
      closeTo(result.systemVol20 - result.base.volume20, 0.01),
    );
    expect(result.variancePct, isNot(0));
    expect(
      formatVarianceDisplay(
        variance: result.varianceLit,
        variancePercent: result.variancePct,
        showPercent: true,
        unit: 'L',
      ),
      contains('%'),
    );
    expect(
      formatVarianceDisplay(
        variance: result.varianceLit,
        variancePercent: result.variancePct,
        showPercent: false,
        unit: 'L',
      ),
      isNot(contains('%')),
    );
  });

  test('OS chega no técnico pelo login, não só pelo e-mail', () {
    final os = SavedOs(
      id: 'os-1',
      number: '044/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianEmails: const ['felipe@gssolucoestec.com.br', 'felipe'],
      status: OsStatus.comTecnico,
    );
    expect(os.isAssignedToAny({'felipe'}), isTrue);
    expect(os.isAssignedTo('Felipe@gssolucoestec.com.br'), isTrue);
    expect(os.isAssignedToAny({'andre'}), isFalse);
    expect(sameFieldTechnician(felipeUser, felipeUser), isTrue);
    expect(felipeUser.login, 'felps1255');
    expect(
      os.isAssignedToAny(
        assignmentIdsFor(
          email: felipeUser.email,
          login: felipeUser.login,
          aliases: felipeUser.aliases,
        ),
      ),
      isTrue,
    );
    expect(assigneeKeysFor(felipeUser), contains('felps1255'));
  });

  test('OS delegada só com nomes aparece para o técnico certo', () {
    final os = SavedOs(
      id: 'os-names',
      number: '044/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianName: 'Cleber Guimarães, Felipe Souza',
      status: OsStatus.emAndamento,
    );
    expect(os.canFillRdo, isTrue);
    expect(os.isAssignedToAny(assigneeKeysFor(cleberUser)), isTrue);
    expect(os.isAssignedToAny(assigneeKeysFor(felipeUser)), isTrue);
    expect(os.isAssignedToAny(assigneeKeysFor(andreUser)), isFalse);
  });

  test('técnico pode lançar RDO mesmo com serviço encerrado na OS', () {
    final os = SavedOs(
      id: 'os-reopen',
      number: '050/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianEmails: const ['felps1255'],
      status: OsStatus.servicoEncerrado,
      rdos: [
        SavedRdo(
          id: 'r1',
          date: DateTime(2026, 8, 17),
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'serviço',
          notes: '',
          files: const [],
          createdAt: DateTime(2026, 8, 17),
        ),
      ],
    );
    expect(os.canFillRdo, isTrue);
    expect(os.isClosed, isFalse);
  });

  test('OS encerrada pode voltar para em andamento ao reativar', () {
    final closed = SavedOs(
      id: 'os-closed',
      number: '044/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      status: OsStatus.encerrada,
      rdos: [
        SavedRdo(
          id: 'r1',
          date: DateTime(2026, 8, 18),
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'serviço',
          notes: '',
          files: const [],
          createdAt: DateTime(2026, 8, 18),
        ),
      ],
    );
    expect(closed.canFillRdo, isFalse);
    final reopened = closed.copyWith(status: OsStatus.emAndamento);
    expect(reopened.canFillRdo, isTrue);
  });

  test('sync de status: reativação na nuvem vence cache local encerrada', () {
    final t0 = DateTime(2026, 9, 1, 10);
    final t1 = DateTime(2026, 9, 1, 12);
    expect(
      preferOsStatus(
        local: OsStatus.encerrada,
        remote: OsStatus.emAndamento,
        localUpdatedAt: t0,
        remoteUpdatedAt: t1,
      ),
      OsStatus.emAndamento,
    );
    expect(
      preferOsStatus(
        local: OsStatus.encerrada,
        remote: OsStatus.emAndamento,
        localUpdatedAt: t0,
        remoteUpdatedAt: t0,
      ),
      OsStatus.emAndamento,
    );
  });

  test('planilha manda a lista de técnicos em texto corrido', () {
    final os = SavedOs.fromJson({
      'id': 'os-2',
      'number': '045/26',
      'ownerEmail': 'a@b.com',
      'createdAt': '2026-08-17T12:00:00.000',
      'technicianEmails': 'felipe@gssolucoestec.com.br,felipe,andre',
      'status': 'comTecnico',
    });
    expect(
      os.assigneeEmails,
      containsAll(['felipe@gssolucoestec.com.br', 'felipe', 'andre']),
    );
  });

  test('OS 044/26 da planilha continua no app mesmo com cache cheio', () async {
    final payload =
        jsonDecode(
              '{"id":1786906906918,"number":"044/26","status":"emAndamento","ownerEmail":"administrativo@gssolucoestec.com.br","createdAt":"2026-08-16T16:01:46.918","technicianEmail":"cleber@gssolucoestec.com.br","technicianName":"Cleber Guimarães, Felipe Souza, André Nascimento","technicianEmails":"cleber@gssolucoestec.com.br,felps1255,nascimento,andre","signerName":"Gustavo Melo","rdo":{"client":"DINAMICA TERMINAIS CANEDO S/A","cnpj":"33.047.181/0001-60"},"rdos":[{"id":1786987760390,"date":"2026-08-17T14:28:55.616","clockIn":"08:00","lunchStart":"12:00","lunchEnd":"13:00","clockOut":"17:00","description":"aferição","notes":"","signed":true,"createdAt":"2026-08-17T14:29:20.390","responsibleName":"Felipe Souza","files":[{"name":"RDO_OS_044-26_170826.pdf","kind":"rdo"}]}],"files":[{"name":"foto.jpg","kind":"photo"}]}',
            )
            as Map<String, dynamic>;
    final os = SavedOs.fromJson(payload);
    expect(os.id, '1786906906918');
    expect(os.number, '044/26');
    expect(os.status, OsStatus.emAndamento);
    expect(os.rdos, hasLength(1));
    expect(os.rdos.single.isSigned, isTrue);
    expect(os.startDay, DateTime(2026, 8, 16));
    expect(os.isAssignedToAny({'nascimento', 'andre'}), isTrue);
    expect(os.isAssignedToAny({'felps1255'}), isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      workOrdersPrefsKey,
      jsonEncode([
        {
          ...os.toJson(),
          'files': [
            {'name': 'foto.jpg', 'kind': 'photo', 'data': 'A' * 800000},
          ],
        },
      ]),
    );
    final raw = await readPrefsString(workOrdersPrefsKey);
    expect(raw, isNotNull);
    expect(raw!.contains('"data"'), isFalse);
    final restored = SavedOs.fromJson(
      Map<String, dynamic>.from((jsonDecode(raw) as List).first as Map),
    );
    expect(restored.number, '044/26');
    expect(restored.id, '1786906906918');
  });

  test('cadastro compartilhado lê locais e RDO assinado da planilha', () {
    final client = SavedClient.fromJson({
      'id': 'c1',
      'name': 'Base Norte',
      'cnpj': '00.000.000/0001-00',
      'sites': 'Galpão A|Pátio 2',
      'updatedAt': '2026-08-17T12:00:00.000',
    });
    expect(client.sites, ['Galpão A', 'Pátio 2']);
    final withAddress = SavedClient.fromJson({
      'id': 'c2',
      'name': 'Terminal Sul',
      'cnpj': '11.111.111/0001-11',
      'cep': '11010-000',
      'street': 'Av. da Praia',
      'number': '50',
      'complement': 'Galpão 1',
      'neighborhood': 'Centro',
      'city': 'Santos',
      'state': 'SP',
      'equipment': [
        {
          'systemType': 'Medição de vazão',
          'equipmentType': 'Medidor ultrassônico',
          'quantity': 2,
          'workingPrinciple': 'Tempo de trânsito',
          'dimensions': 'DN 100',
          'manufacturer': 'Fabricante X',
          'model': 'MX-100',
          'serialNumber': 'SN-001',
          'tag': 'FT-01',
          'installLocation': 'Linha de carregamento',
        },
      ],
      'updatedAt': '2026-08-17T12:00:00.000',
    });
    expect(withAddress.city, 'Santos');
    expect(withAddress.state, 'SP');
    expect(withAddress.equipment.single.tag, 'FT-01');
    expect(withAddress.equipment.single.quantity, 2);
    expect(withAddress.addressLine, contains('Av. da Praia'));
    final rdo = SavedRdo.fromJson({
      'id': 'r1',
      'date': '2026-08-17T08:00:00.000',
      'description': 'Calibração',
      'signed': true,
      'files': const [],
    });
    expect(rdo.isSigned, isTrue);
    expect(rdo.signature?.name, 'assinatura.png');
  });

  test('planilha padrão de calibração traz cliente e instrumento', () {
    final bytes = buildClientExcelTemplate(withExample: true);
    expect(bytes, isNotEmpty);
    final parsed = parseClientWorkbook(bytes);
    expect(parsed.clients, isNotEmpty);
    expect(parsed.instruments, isNotEmpty);
    expect(parsed.clients.first.city, isNotEmpty);
    expect(parsed.clients.first.service, isEmpty);
    expect(parsed.clients.first.sites, isEmpty);
    expect(parsed.instruments.first.equipment.tag, isNotEmpty);
    expect(parsed.instruments.first.equipment.systemType, isNotEmpty);
    expect(parsed.instruments, hasLength(3));
    expect(parsed.instruments.first.equipment.presetTag, 'P-01');
    final grouped = systemsFromEquipment([
      for (final row in parsed.instruments) row.equipment,
    ]);
    expect(grouped, hasLength(1));
    expect(grouped.single.isPreset, isTrue);
    expect(grouped.single.meters, hasLength(2));
    expect(grouped.single.pt100s, hasLength(1));
    expect(grouped.single.pt100s.single.meshTag, 'TT-01');
  });

  test('preset agrupa medidores e volta no JSON do cliente', () {
    final client = SavedClient(
      id: 'c-preset',
      name: 'AG Serviços',
      systems: const [
        ClientSystem(
          id: 'sys1',
          systemType: 'Carga',
          installLocation: 'Pátio',
          tag: 'SKID-01',
          kind: ClientAssemblyKind.preset,
          manufacturer: 'Emerson',
          model: 'CMF',
          serialNumber: 'PS-1',
          assemblyTag: 'P-01',
          meterCount: 2,
          instruments: [
            ClientInstrument(
              id: 'm1',
              role: ClientInstrumentRole.meter,
              tag: 'FT-01',
              serialNumber: 'SN-1',
            ),
            ClientInstrument(
              id: 'm2',
              role: ClientInstrumentRole.meter,
              tag: 'FT-02',
              serialNumber: 'SN-2',
            ),
          ],
        ),
      ],
      updatedAt: DateTime(2026, 8, 26),
    );
    expect(client.equipment.map((item) => item.tag), ['FT-01', 'FT-02']);
    expect(client.equipment.every((item) => item.presetTag == 'P-01'), isTrue);
    final restored = SavedClient.fromJson(client.toJson());
    expect(restored.resolvedSystems, hasLength(1));
    expect(restored.resolvedSystems.single.meters.map((item) => item.tag), [
      'FT-01',
      'FT-02',
    ]);
    final groups = groupClientSystems(restored.resolvedSystems);
    expect(groups, hasLength(1));
    expect(groups.single.title, 'SKID-01');
  });

  test(
    'cada PT100 do preset gera uma malha no JSON e na escolha da calibração',
    () {
      const system = ClientSystem(
        id: 'sys-malha',
        kind: ClientAssemblyKind.preset,
        assemblyTag: 'P-01',
        pt100Count: 2,
        instruments: [
          ClientInstrument(
            id: 't1',
            role: ClientInstrumentRole.pt100,
            tag: 'TE-01',
            meshTag: 'TT-01',
          ),
          ClientInstrument(
            id: 't2',
            role: ClientInstrumentRole.pt100,
            tag: 'TE-02',
            meshTag: 'TT-02',
          ),
        ],
      );
      expect(system.pt100s, hasLength(2));
      expect(system.pt100s.map((item) => item.meshTag), ['TT-01', 'TT-02']);
      final rows = flattenClientSystems([system], includeMeshes: true);
      expect(rows.map((item) => '${item.instrumentRole}:${item.tag}'), [
        'pt100:TE-01',
        'mesh:TT-01',
        'pt100:TE-02',
        'mesh:TT-02',
      ]);
      final restored = ClientSystem.fromJson(system.toJson());
      expect(restored.pt100s.map((item) => item.meshTag), ['TT-01', 'TT-02']);
    },
  );

  testWidgets('cadastro de sistema com preset abre um bloco por medidor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: GsTheme.data, home: const ClientEditPage()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('incluir-sistema')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('incluir-sistema')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('sistema-tipo')), 'Carga');
    await tester.enterText(find.byKey(const Key('sistema-local')), 'Pátio');
    await tester.enterText(find.byKey(const Key('sistema-tag')), 'SKID-01');
    final systemScroll = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('sistema-kind-preset')),
      200,
      scrollable: systemScroll,
    );
    await tester.tap(find.byKey(const Key('sistema-kind-preset')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('sistema-qtd-medidor')),
      200,
      scrollable: systemScroll,
    );
    await tester.enterText(find.byKey(const Key('sistema-qtd-medidor')), '2');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Medidor 2'),
      200,
      scrollable: systemScroll,
    );

    expect(find.text('Medidor 1', skipOffstage: false), findsOneWidget);
    expect(find.text('Medidor 2'), findsOneWidget);
    expect(
      find.byKey(const Key('sistema-inst-meter-1-tag'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sistema-inst-meter-2-tag'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('cadastro de PT100 abre a malha correspondente', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: GsTheme.data, home: const ClientEditPage()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('incluir-sistema')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('incluir-sistema')));
    await tester.pumpAndSettle();
    final systemScroll = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('sistema-kind-preset')),
      200,
      scrollable: systemScroll,
    );
    await tester.tap(find.byKey(const Key('sistema-kind-preset')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('sistema-qtd-pt100')),
      200,
      scrollable: systemScroll,
    );
    await tester.enterText(find.byKey(const Key('sistema-qtd-pt100')), '2');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Malha 2'),
      200,
      scrollable: systemScroll,
    );

    expect(find.text('PT100 1', skipOffstage: false), findsOneWidget);
    expect(find.text('PT100 2', skipOffstage: false), findsOneWidget);
    expect(find.text('Malha 1', skipOffstage: false), findsOneWidget);
    expect(find.text('Malha 2'), findsOneWidget);
    expect(
      find.byKey(
        const Key('sistema-inst-pt100-1-malha-tag'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('sistema-inst-pt100-2-malha-tag'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('certificado escolhe sistema, preset e qual medidor', (
    tester,
  ) async {
    await ClientStore.instance.save(
      SavedClient(
        id: 'cli-preset',
        name: 'AG Serviços',
        cnpj: '00.111.222/0001-33',
        systems: const [
          ClientSystem(
            id: 'sys1',
            systemType: 'Carga',
            installLocation: 'Pátio',
            tag: 'SKID-01',
            kind: ClientAssemblyKind.preset,
            manufacturer: 'Emerson',
            model: 'CMF',
            serialNumber: 'PS-1',
            assemblyTag: 'P-01',
            meterCount: 2,
            instruments: [
              ClientInstrument(
                id: 'm1',
                role: ClientInstrumentRole.meter,
                tag: 'FT-01',
              ),
              ClientInstrument(
                id: 'm2',
                role: ClientInstrumentRole.meter,
                tag: 'FT-02',
              ),
            ],
          ),
        ],
        updatedAt: DateTime(2026, 8, 26),
      ),
      syncRemote: false,
    );
    final job = await CalibrationStore.instance.save(
      newCalibrationJob(
        kind: CalibrationKind.temperature,
        technicianName: 'Cleber',
      ).copyWith(clientId: 'cli-preset', clientName: 'AG Serviços'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: CalibrationJobPage(jobId: job.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('calibracao-sistema-sys1')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('calibracao-sistema-sys1')));
    await tester.pumpAndSettle();
    expect(find.text('Preset P-01'), findsWidgets);
    await tester.tap(find.byKey(const Key('calibracao-preset-sys1')));
    await tester.pumpAndSettle();
    expect(find.text('Medidor · FT-01'), findsOneWidget);
    expect(find.text('Medidor · FT-02'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calibracao-instrumento-m2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('calibracao-instrumento-m2')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('calibracao-instrumento-m1')),
          )
          .selected,
      isFalse,
    );
  });

  test(
    'volumétrico calcula fator, erro, repetibilidade e só pede conferência se estourar',
    () {
      const limits = CalibrationLimits(
        maxRepeatabilityPct: 0.05,
        maxVolumetricErrorPct: 0.05,
      );
      expect(meterFactor(2000, 2000), 1);
      expect(sampleStdev([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2.138, 0.01));
      expect(volumetricErrorPercent(2000, 2010), closeTo(0.4975, 0.01));
      final okRuns = [
        const VolumeRun(id: '1', standardVolume: 2000, objectVolume: 2000.4),
        const VolumeRun(id: '2', standardVolume: 2000, objectVolume: 2000.5),
      ];
      final ok = evaluateRunSet(okRuns, limits);
      expect(ok.complete, isTrue);
      expect(ok.passed, isTrue);

      final badRuns = [
        const VolumeRun(id: '1', standardVolume: 2000, objectVolume: 2012),
        const VolumeRun(id: '2', standardVolume: 2000, objectVolume: 2014),
      ];
      final bad = evaluateRunSet(badRuns, limits);
      expect(bad.passed, isFalse);
      expect(bad.errorOk, isFalse);

      final pointOk = FlowPoint(id: 'p1', verification: okRuns);
      expect(pointOk.conferenceRequired(limits), isFalse);
      expect(pointOk.isApproved(limits), isTrue);

      final pointBad = FlowPoint(id: 'p2', verification: badRuns);
      expect(pointBad.conferenceRequired(limits), isTrue);
      expect(pointBad.isApproved(limits), isFalse);
      expect(pointBad.suggestedNewFactor(limits), isNotNull);
    },
  );

  test(
    'erro aceitável: qualquer corrida acima do limite reprova (não a média)',
    () {
      // Cleber / Vibra: limite 0,04%; corridas 0,05% e 0,01% → média 0,03%
      // mas a 1ª estourou → fora, abrir conferência.
      const limits = CalibrationLimits(
        maxRepeatabilityPct: 1,
        maxVolumetricErrorPct: 0.04,
      );
      // E ≈ (1 − padrão/objeto)×100
      // 0,05%: Mf=0,9995 → padrão/objeto = 0,9995 → objeto = padrão/0,9995
      final mixed = [
        VolumeRun(
          id: '1',
          standardVolume: 2000,
          objectVolume: 2000 / 0.9995,
        ),
        VolumeRun(
          id: '2',
          standardVolume: 2000,
          objectVolume: 2000 / 0.9999,
        ),
      ];
      final result = evaluateRunSet(mixed, limits);
      expect(result.meanError!.abs(), lessThan(0.04));
      expect(result.worstError!.abs(), greaterThan(0.04));
      expect(result.errorOk, isFalse);
      expect(result.passed, isFalse);
      expect(FlowPoint(id: 'p', verification: mixed).conferenceRequired(limits),
          isTrue);
    },
  );

  test(
    'alterar fator antigo recalcula Mf aplicado da conferência',
    () {
      const limits = CalibrationLimits(
        maxRepeatabilityPct: 1,
        maxVolumetricErrorPct: 0.05,
      );
      final runs = [
        const VolumeRun(id: '1', standardVolume: 2000, objectVolume: 2000),
        const VolumeRun(id: '2', standardVolume: 2000, objectVolume: 2000),
      ];
      final mean = evaluateRunSet(runs, limits).meanFactor!;
      final point = FlowPoint(
        id: 'p',
        oldMeterFactor: 0.99845,
        verification: runs,
        conferences: [
          ConferenceAttempt(
            id: 'c1',
            createdAt: DateTime(2026, 10, 17),
            meterFactorApplied: correctedMeterFactor(0.99845, mean),
            runs: runs,
          ),
        ],
      );
      final updated = point
          .copyWith(oldMeterFactor: 1.0)
          .recalculateAppliedFactors(limits);
      expect(
        updated.conferences.first.meterFactorApplied,
        closeTo(correctedMeterFactor(1.0, mean), 1e-9),
      );
      expect(
        updated.conferences.first.meterFactorApplied,
        isNot(closeTo(point.conferences.first.meterFactorApplied!, 1e-9)),
      );
    },
  );

  test(
    'última conferência completa OK vale mesmo com rascunho vazio depois',
    () {
      const limits = CalibrationLimits(
        maxRepeatabilityPct: 0.05,
        maxVolumetricErrorPct: 0.05,
      );
      final badVerify = [
        const VolumeRun(id: 'v1', standardVolume: 2000, objectVolume: 2012),
        const VolumeRun(id: 'v2', standardVolume: 2000, objectVolume: 2014),
      ];
      final okConf = ConferenceAttempt(
        id: 'c1',
        createdAt: DateTime(2026, 8, 19),
        runs: const [
          VolumeRun(id: 'c1a', standardVolume: 2000, objectVolume: 2000.2),
          VolumeRun(id: 'c1b', standardVolume: 2000, objectVolume: 2000.3),
        ],
      );
      final emptyConf = ConferenceAttempt(
        id: 'c2',
        createdAt: DateTime(2026, 8, 19, 1),
        runs: const [
          VolumeRun(id: 'c2a'),
          VolumeRun(id: 'c2b'),
        ],
      );
      final point = FlowPoint(
        id: 'p',
        flowRate: 1800,
        verification: badVerify,
        conferences: [okConf, emptyConf],
      );
      expect(point.lastCompleteConference?.id, 'c1');
      expect(point.isApproved(limits), isTrue);
      expect(point.lastConferenceResult(limits)?.passed, isTrue);
    },
  );

  test('fator deixado é o aplicado na conferência aprovada, nunca o antigo', () {
    const limits = CalibrationLimits(
      maxRepeatabilityPct: 0.05,
      maxVolumetricErrorPct: 0.05,
    );
    final badVerify = [
      const VolumeRun(id: 'v1', standardVolume: 2000, objectVolume: 2012),
      const VolumeRun(id: 'v2', standardVolume: 2000, objectVolume: 2014),
    ];
    final okConf = ConferenceAttempt(
      id: 'c1',
      createdAt: DateTime(2026, 10, 5),
      meterFactorApplied: 1.00302,
      runs: const [
        VolumeRun(id: 'c1a', standardVolume: 2000, objectVolume: 2000.7),
        VolumeRun(id: 'c1b', standardVolume: 2000, objectVolume: 2000.8),
      ],
    );
    final point = FlowPoint(
      id: 'p',
      flowRate: 5,
      oldMeterFactor: 0.9965,
      verification: badVerify,
      conferences: [okConf],
    );
    expect(point.isApproved(limits), isTrue);
    expect(point.leftMeterFactor(limits), 1.00302);
    // Nova conferência depois da aprovada parte do mesmo fator, sem recalcular.
    expect(point.suggestedNewFactor(limits), 1.00302);

    final job = newCalibrationJob(
      kind: CalibrationKind.volumetric,
      technicianName: 'Cleber',
    ).copyWith(points: [point]);
    expect(job.meterFactors(found: true), [0.9965]);
    expect(job.meterFactors(found: false), [1.00302]);

    // Conferência com uma corrida vazia sobrando não volta para o fator antigo.
    final partial = point.copyWith(
      conferences: [
        okConf.copyWith(
          runs: [
            ...okConf.runs,
            const VolumeRun(id: 'c1c'),
          ],
        ),
      ],
    );
    expect(partial.lastCompleteConference, isNull);
    expect(partial.leftMeterFactor(limits), 1.00302);
    expect(partial.withRunCount(2).conferences.single.runs.length, 2);
    expect(partial.withRunCount(2).isApproved(limits), isTrue);

    // Conferência reprovada: sugere aplicado × fator médio da conferência.
    final badConf = okConf.copyWith(
      runs: const [
        VolumeRun(id: 'c1a', standardVolume: 2000, objectVolume: 2010),
        VolumeRun(id: 'c1b', standardVolume: 2000, objectVolume: 2010),
      ],
    );
    final failed = point.copyWith(conferences: [badConf]);
    expect(failed.isApproved(limits), isFalse);
    expect(
      failed.suggestedNewFactor(limits),
      closeTo(1.00302 * 2000 / 2010, 0.00001),
    );
  });

  test('volumétrica invertida divide objeto pelo padrão', () {
    expect(meterFactor(2000, 1000), 2);
    expect(meterFactor(2000, 1000, inverted: true), 0.5);
    expect(
      volumetricErrorPercent(2000, 1000, inverted: true),
      closeTo(50, 0.001),
    );
    expect(
      calibrationKindFrom('volumetricInverted'),
      CalibrationKind.volumetricInverted,
    );
    expect(
      calibrationKindLabel(CalibrationKind.volumetricInverted),
      'Volumétrica invertida',
    );

    final job = newCalibrationJob(
      kind: CalibrationKind.volumetricInverted,
      technicianName: 'Cleber',
    );
    expect(job.isVolumetric, isTrue);
    expect(job.invertedVolumetric, isTrue);
    expect(
      CalibrationJob.fromJson(job.toJson()).kind,
      CalibrationKind.volumetricInverted,
    );

    const runs = [
      VolumeRun(id: '1', standardVolume: 2000, objectVolume: 1000),
      VolumeRun(id: '2', standardVolume: 2000, objectVolume: 1000),
    ];
    final direct = evaluateRunSet(runs, const CalibrationLimits());
    final inverted = evaluateRunSet(
      runs,
      const CalibrationLimits(),
      inverted: true,
    );
    expect(direct.meanFactor, closeTo(2, 0.0001));
    expect(inverted.meanFactor, closeTo(0.5, 0.0001));
    expect(inverted.meanError, closeTo(50, 0.001));
  });

  test('incerteza do padrão entra no certificado sem converter o valor', () {
    const named = CalibrationStandard(
      id: 's1',
      tag: 'GS-001',
      uncertainty: '0,002',
    );
    expect(named.uncertaintyLabel, '0,002%');
    expect(named.uncertaintyPercent, 0.002);

    const percent = CalibrationStandard(
      id: 's1b',
      tag: 'GS-001',
      uncertainty: '0,1600',
    );
    expect(percent.uncertaintyLabel, '0,1600%');
    expect(
      CalibrationStandard.fromJson(percent.toJson()).uncertainty,
      '0,1600',
    );

    const fromDesc = CalibrationStandard(
      id: 's2',
      description: 'Totalizador · ±0,05%',
    );
    expect(fromDesc.uncertaintyLabel, '0,05%');
  });

  test('U, k e Veff saem da planilha GS com as medições', () {
    expect(gsVolumetricFlowColumnTitle, 'Sistema padrão vazão média');
    expect(excelTInv(0.0455, 10000), closeTo(2.00, 0.03));
    expect(excelTInv(0.05, 10), closeTo(2.228, 0.04));
    expect(veffFromStandardK(2), 10000);

    final budget = volumetricUncertainty(
      relativeVolumeErrors: const [
        (2003.08 - 2002.88) / 2003.08,
        (2002.73 - 2001.73) / 2002.73,
      ],
      objectVolumes: const [2003.08, 2002.73],
      standardExpandedPercent: 0.08,
      standardK: 2.03,
      standardResolutionLiters: 0.001,
      instrumentResolutionLiters: 0.01,
      standardStabilityPercent: 0.025,
    );
    expect(budget, isNotNull);
    expect(budget!.expandedPercent, closeTo(0.0981, 0.001));
    expect(budget.coverageK, closeTo(2.11, 0.02));
    expect(budget.effectiveDof, closeTo(24.7, 0.1));
    expect(budget.uLabel.endsWith('%'), isTrue);

    final job =
        newCalibrationJob(
          kind: CalibrationKind.volumetric,
          technicianName: 'Cleber',
        ).copyWith(
          instrumentResolution: '0,01',
          standards: const [
            CalibrationStandard(
              id: 's1',
              tag: 'GS-001',
              uncertainty: '0,08',
              coverageK: '2,03',
              resolution: '0,001',
              stability: '0,025',
            ),
          ],
          points: [
            FlowPoint(
              id: 'p1',
              flowRate: 400,
              verification: const [
                VolumeRun(
                  id: 'a',
                  objectVolume: 2003.08,
                  standardVolume: 2002.88,
                ),
                VolumeRun(
                  id: 'b',
                  objectVolume: 2002.73,
                  standardVolume: 2001.73,
                ),
              ],
            ),
          ],
        );
    final computed = job.uncertaintyBudget(job.points.first, found: true);
    expect(computed, isNotNull);
    expect(computed!.expandedPercent, closeTo(0.0981, 0.001));
    expect(computed.coverageK, closeTo(2.11, 0.02));
    expect(job.resultULabel(job.points.first, found: true), isNotEmpty);
    expect(job.resultKLabel(job.points.first, found: true), isNotEmpty);
    expect(job.resultVeffLabel(job.points.first, found: true), isNotEmpty);

    final onlyA = volumetricUncertainty(
      relativeVolumeErrors: const [
        (2003.08 - 2002.88) / 2003.08,
        (2002.73 - 2001.73) / 2002.73,
      ],
      objectVolumes: const [2003.08, 2002.73],
    );
    expect(onlyA, isNotNull);
    expect(onlyA!.expandedPercent, greaterThan(0.03));
    expect(onlyA.kLabel, isNotEmpty);
    expect(onlyA.veffLabel, isNotEmpty);

    final onlyB = volumetricUncertainty(
      relativeVolumeErrors: const [],
      objectVolumes: const [2000, 2000],
      standardExpandedPercent: 0.08,
      standardK: 2,
    );
    expect(onlyB, isNotNull);
    expect(onlyB!.expandedPercent, closeTo(0.08, 0.01));
    expect(onlyB.kLabel, isNotEmpty);
    expect(onlyB.veffLabel, isNotEmpty);
  });

  test(
    'fator do medidor só entra no certificado se o medidor for Coriolis',
    () {
      final coeffs = [
        const CoriolisCoefficient(
          id: '1',
          label: 'Flow Cal.',
          found: '226,795',
        ),
        const CoriolisCoefficient(id: '2', label: 'K1'),
        const CoriolisCoefficient(
          id: '3',
          label: 'KD',
          found: '2,0062',
          left: '2,0100',
        ),
      ];
      final pd =
          newCalibrationJob(
            kind: CalibrationKind.volumetric,
            technicianName: 'Cleber',
          ).copyWith(
            workingPrinciple: 'Deslocamento positivo',
            coriolisCoefficients: coeffs,
          );
      expect(pd.isCoriolis, isFalse);
      expect(pd.coriolisFactorsOnCertificate(found: true), isEmpty);

      final coriolis = pd.copyWith(workingPrinciple: 'Coriolis');
      expect(coriolis.isCoriolis, isTrue);
      expect(
        coriolis
            .coriolisFactorsOnCertificate(found: true)
            .map((item) => item.label),
        ['Flow Cal.', 'KD'],
      );
      expect(
        coriolis
            .coriolisFactorsOnCertificate(found: false)
            .map((item) => item.valueFor(found: false)),
        ['226,795', '2,0100'],
      );

      expect(
        pd
            .copyWith(workingPrinciple: '', equipmentType: 'Medidor Coriolis')
            .isCoriolis,
        isTrue,
      );

      final roundtrip = CalibrationJob.fromJson(coriolis.toJson());
      expect(
        roundtrip.coriolisCoefficients.map((item) => item.found).toList(),
        ['226,795', '', '2,0062'],
      );
    },
  );

  test('escritório vê OS de toda a equipe; técnico só as dele', () {
    final office = appUserFromRemote(
      const RemoteAccount(
        email: 'admin2@gssolucoestec.com.br',
        login: 'escritorio',
        name: 'Escritório',
        phone: '',
        role: 'admin',
        status: 'aprovado',
        active: true,
      ),
    );
    expect(office.seesAllFieldOs, isTrue);
    expect(matchUser('felipe')?.seesAllFieldOs, isFalse);
    expect(matchUser('cleber')?.seesAllFieldOs, isTrue);
    expect(matchUser('gssolucoes')?.seesAllFieldOs, isTrue);

    // Adm com chips custom (sem gerar_os) ainda vê OS/certificados da empresa.
    final admCalib = appUserFromRemote(
      const RemoteAccount(
        email: 'secretaria@gssolucoestec.com.br',
        login: 'secretaria',
        name: 'Secretaria',
        phone: '',
        role: 'admin',
        status: 'aprovado',
        active: true,
        permissions: 'clientes,calibracao,emitir_cert',
      ),
    );
    expect(admCalib.isAdministrative, isTrue);
    expect(admCalib.seesAllFieldOs, isTrue);
    expect(admCalib.canSeeCalibration, isTrue);
  });

  test('delegar técnicos usa felps1255 e andre, sem duplicar', () {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'felipe@gssolucoestec.com.br',
        login: 'felipe',
        name: 'Felipe Souza',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
      const RemoteAccount(
        email: 'felipe.souza@gssolucoestec.com.br',
        login: 'felps1255',
        name: 'Felipe Souza',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
      const RemoteAccount(
        email: 'andre@gssolucoestec.com.br',
        login: 'andre',
        name: 'Andre Nascimento',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
      const RemoteAccount(
        email: 'andre.real@gssolucoestec.com.br',
        login: 'andre',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    ];
    final logins = [for (final user in fieldTechnicians) user.login];
    expect(logins.where((login) => login == 'felps1255').length, 1);
    expect(logins.contains('felipe'), isFalse);
    expect(
      fieldTechnicians
          .where((user) => personFirstKey(user.name) == 'felipe')
          .length,
      1,
    );
    expect(
      fieldTechnicians
          .where((user) => personFirstKey(user.name) == 'andre')
          .length,
      1,
    );
    expect(
      fieldTechnicians
          .firstWhere((user) => personFirstKey(user.name) == 'andre')
          .login,
      'nascimento',
    );
    expect(
      assigneeKeysFor(
        fieldTechnicians.firstWhere((user) => user.login == 'felps1255'),
      ),
      contains('felps1255'),
    );
    StaffStore.instance.users = [];
  });

  test(
    'Gerar OS usa o André ativo de Funcionários, não o cadastro desligado',
    () {
      StaffStore.instance.users = [
        const RemoteAccount(
          email: 'andre@gssolucoestec.com.br',
          login: 'andre',
          name: 'André',
          phone: '',
          role: 'tecnico',
          status: 'aprovado',
          active: false,
        ),
        const RemoteAccount(
          email: 'nascimento@gssolucoestec.com.br',
          login: 'nascimento',
          name: 'André',
          phone: '',
          role: 'tecnico',
          status: 'aprovado',
          active: true,
        ),
      ];
      final andres = [
        for (final user in fieldTechnicians)
          if (personFirstKey(user.name) == 'andre' ||
              user.login == 'nascimento')
            user,
      ];
      expect(andres, hasLength(1));
      expect(andres.single.login, 'nascimento');
      expect(andres.single.name, 'André');
      expect(sameFieldTechnician(andreUser, andres.single), isTrue);
      StaffStore.instance.users = [];
    },
  );

  test('planilha com login andre ainda aparece como nascimento na OS', () {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'andre.real@gssolucoestec.com.br',
        login: 'andre',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    ];
    final andre = fieldTechnicians.singleWhere(
      (user) => personFirstKey(user.name) == 'andre',
    );
    expect(andre.login, 'nascimento');
    expect(sameFieldTechnician(andre, andreUser), isTrue);
    StaffStore.instance.users = [];
  });

  testWidgets('editar OS mostra nascimento, não o login andre antigo', (
    tester,
  ) async {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'nascimento@gssolucoestec.com.br',
        login: 'nascimento',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
        cargo: 'Técnico em Instrumentação Industrial',
      ),
    ];
    final os = SavedOs(
      id: 'os-edit-andre',
      number: '100/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianName: 'André',
      technicianEmail: 'andre@gssolucoestec.com.br',
      technicianEmails: const ['andre', 'andre@gssolucoestec.com.br'],
      status: OsStatus.comTecnico,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: OsCreatePage(existing: os),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('tech-nascimento')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Editar OS'), findsOneWidget);
    expect(find.byKey(const Key('tech-nascimento')), findsOneWidget);
    expect(find.textContaining('nascimento ·'), findsOneWidget);
    expect(find.textContaining('andre ·'), findsNothing);
    expect(find.byKey(const Key('tech-andre')), findsNothing);
    StaffStore.instance.users = [];
  });

  test('técnico desligado não volta na OS pelo cadastro antigo do app', () {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'andre@gssolucoestec.com.br',
        login: 'andre',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: false,
      ),
    ];
    expect(
      fieldTechnicians.where((user) => personFirstKey(user.name) == 'andre'),
      isEmpty,
    );
    StaffStore.instance.users = [];
  });

  test('RDO lista a equipe na ordem e o primeiro é o responsável técnico', () {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'cleber@gssolucoestec.com.br',
        login: 'cleber',
        name: 'Cleber Guimarães',
        phone: '',
        role: 'ambos',
        status: 'aprovado',
        active: true,
      ),
      const RemoteAccount(
        email: 'felipe.souza@gssolucoestec.com.br',
        login: 'felps1255',
        name: 'Felipe Souza',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
      const RemoteAccount(
        email: 'andre.real@gssolucoestec.com.br',
        login: 'andre',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    ];
    final os = SavedOs(
      id: 'os-team',
      number: '5643/26',
      ownerEmail: 'cleber@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianName: 'Felipe Souza, Cleber Guimarães, André',
      technicianEmails: const [
        'felps1255',
        'cleber@gssolucoestec.com.br',
        'andre',
      ],
      status: OsStatus.comTecnico,
    );
    final names = teamNamesForOs(os, signedBy: 'Cleber Guimarães');
    expect(names.first, 'Felipe Souza');
    expect(names, contains('Cleber Guimarães'));
    expect(names, contains('André'));
    StaffStore.instance.users = [];
  });

  test('RDO guarda o responsável técnico escolhido na assinatura', () {
    final entry = SavedRdo(
      id: '1',
      date: DateTime(2026, 8, 17),
      clockIn: '08:00',
      lunchStart: '12:00',
      lunchEnd: '13:00',
      clockOut: '17:00',
      description: '',
      notes: '',
      files: const [],
      createdAt: DateTime(2026, 8, 17),
      responsibleName: 'Felipe Souza',
    );
    expect(SavedRdo.fromJson(entry.toJson()).responsibleName, 'Felipe Souza');
  });

  test('função do RDO fica gravada na OS, não no cadastro', () {
    final rdo = RdoData.fromJson({
      'technicianFuncoes': {
        'felipe': 'Responsável técnico',
        'cleber': 'Suporte Técnico',
      },
    });
    expect(rdo.technicianFuncoes['felipe'], 'Responsável técnico');
    expect(
      RdoData.fromJson(rdo.toJson()).technicianFuncoes['cleber'],
      'Suporte Técnico',
    );
    expect(
      RdoData.fromJson({
        'technicianFuncoes': '{"andre":"Suporte Técnico"}',
      }).technicianFuncoes['andre'],
      'Suporte Técnico',
    );
  });

  test('André e Andre Nascimento são o mesmo técnico', () {
    final remoteAndre = appUserFromRemote(
      const RemoteAccount(
        email: 'andre.nascimento@gssolucoestec.com.br',
        login: 'andré',
        name: 'André',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    );
    expect(sameFieldTechnician(andreUser, remoteAndre), isTrue);
  });

  test('nomes de técnico repetidos viram uma lista só', () {
    expect(
      uniquePersonNames(
        'Cleber Guimarães, Felipe Souza, Andre Nascimento, Felipe Souza, André',
      ),
      'Cleber Guimarães, Felipe Souza, Andre Nascimento',
    );
  });

  test('agenda semanal coloca o RDO no dia certo e calcula extra e DSR', () {
    expect(startOfWeek(DateTime(2026, 8, 19)), DateTime(2026, 8, 17));
    expect(parseClockMinutes('07:40'), 7 * 60 + 40);
    final rdo = SavedRdo(
      id: '1',
      date: DateTime(2026, 8, 18),
      clockIn: '07:40',
      lunchStart: '12:00',
      lunchEnd: '13:00',
      clockOut: '18:40',
      description: 'serviço',
      notes: '',
      files: const [],
      createdAt: DateTime(2026, 8, 18),
      responsibleName: 'Felipe',
    );
    expect(rdoWorkedMinutes(rdo), 10 * 60);
    expect(dailyOvertimeMinutes(10 * 60), 2 * 60);
    expect(formatWorkedHours(10 * 60), '10h');

    final felipeOs = SavedOs(
      id: 'os-felipe',
      number: '044/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianEmail: 'felipe@gssolucoestec.com.br',
      technicianName: 'Felipe Souza',
      technicianEmails: const ['felipe@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'DINÂMICA', site: 'TERMINAL BELÉM'),
      rdos: [rdo],
    );
    final andreOs = SavedOs(
      id: 'os-andre',
      number: '036/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 12),
      files: const [],
      technicianEmail: 'andre@gssolucoestec.com.br',
      technicianName: 'Andre Nascimento',
      technicianEmails: const ['andre@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'ALESAT/MG', site: 'ALESAT/MG'),
    );
    final tuesday = DateTime(2026, 8, 18);
    final weekStart = DateTime(2026, 8, 17);
    final jobs = agendaJobsOnDay(
      [felipeOs, andreOs],
      tuesday,
      weekStart: weekStart,
      now: DateTime(2026, 8, 19),
    );
    expect(jobs, hasLength(1));
    expect(jobs.first.os.number, '044/26');
    expect(jobs.first.place, 'TERMINAL BELÉM');

    final mine = agendaOrdersFor(
      orders: [felipeOs, andreOs],
      onlyMine: true,
      viewerIds: assignmentIdsFor(email: 'felipe@gssolucoestec.com.br'),
    );
    expect(mine.map((os) => os.number), ['044/26']);
    final team = agendaOrdersFor(
      orders: [felipeOs, andreOs],
      onlyMine: false,
      viewerIds: const {},
    );
    expect(team.map((os) => os.number), ['044/26', '036/26']);

    final hours = weekHoursByTechnician(
      orders: [felipeOs],
      weekStart: DateTime(2026, 8, 17),
    );
    expect(hours, hasLength(1));
    expect(hours.first.name, 'Felipe');
    expect(hours.first.workedMinutes, 10 * 60);
    expect(hours.first.extraMinutes, 2 * 60);
    expect(hours.first.dsrMinutes, 10 * 60);
  });

  test('horas da semana do técnico logado não usam o nome de outro', () {
    final day = DateTime(2026, 8, 18);
    SavedRdo rdo({required String who, String out = '17:00'}) {
      return SavedRdo(
        id: 'rdo-$who',
        date: day,
        clockIn: '08:00',
        lunchStart: '12:00',
        lunchEnd: '13:00',
        clockOut: out,
        description: '',
        notes: '',
        files: const [],
        createdAt: day,
        responsibleName: who,
      );
    }

    final shared = SavedOs(
      id: 'os-shared',
      number: '060/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianName: 'Felipe Souza, André',
      technicianEmails: const ['felps1255', 'nascimento', 'andre'],
      status: OsStatus.emAndamento,
      rdos: [rdo(who: 'Felipe Souza', out: '19:00')],
    );
    final andreIds = assignmentIdsFor(
      login: 'nascimento',
      email: 'nascimento@gssolucoestec.com.br',
      aliases: const ['andre', 'nascimento'],
    );
    final felipeIds = assignmentIdsFor(
      login: 'felps1255',
      email: 'felipe@gssolucoestec.com.br',
      aliases: const ['felipe'],
    );
    final andreHours = weekHoursByTechnician(
      orders: [shared],
      weekStart: DateTime(2026, 8, 17),
      viewerName: 'André',
      viewerIds: andreIds,
    );
    expect(andreHours, hasLength(1));
    expect(andreHours.single.name, 'André');
    expect(andreHours.single.workedMinutes, 10 * 60);
    expect(andreHours.single.extraMinutes, 2 * 60);

    final felipeHours = weekHoursByTechnician(
      orders: [shared],
      weekStart: DateTime(2026, 8, 17),
      viewerName: 'Felipe Souza',
      viewerIds: felipeIds,
    );
    expect(felipeHours, hasLength(1));
    expect(felipeHours.single.name, 'Felipe Souza');
    expect(felipeHours.single.workedMinutes, 10 * 60);

    final andreOwn = SavedOs(
      id: 'os-andre-own',
      number: '061/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      technicianName: 'Felipe Souza',
      technicianEmails: const ['nascimento', 'andre'],
      status: OsStatus.emAndamento,
      rdos: [rdo(who: 'André')],
    );
    final labeled = weekHoursByTechnician(
      orders: [andreOwn],
      weekStart: DateTime(2026, 8, 17),
      viewerName: 'André',
      viewerIds: andreIds,
    );
    expect(labeled, hasLength(1));
    expect(labeled.single.name, 'André');
    expect(labeled.single.workedMinutes, 8 * 60);
  });

  test('feriados nacionais de 2026 caem nos dias certos', () {
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(brazilHoliday(DateTime(2026, 2, 16)).name, 'Carnaval');
    expect(brazilHoliday(DateTime(2026, 2, 17)).name, 'Carnaval');
    expect(brazilHoliday(DateTime(2026, 4, 3)).name, 'Sexta-feira Santa');
    expect(brazilHoliday(DateTime(2026, 4, 21)).name, 'Tiradentes');
    expect(brazilHoliday(DateTime(2026, 8, 18)).isHoliday, isFalse);
  });

  test(
    'relatório de horas mostra cliente, casa, feriado e extras do técnico',
    () {
      SavedRdo rdoOn(
        DateTime date,
        String clockOut, {
        String who = 'Felipe Souza',
      }) {
        return SavedRdo(
          id: date.toIso8601String(),
          date: date,
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: clockOut,
          description: '',
          notes: '',
          files: const [],
          createdAt: date,
          responsibleName: who,
        );
      }

      final sunday = DateTime(2026, 8, 16);
      final tuesday = DateTime(2026, 8, 18);
      final wednesday = DateTime(2026, 8, 19);
      final tiradentes = DateTime(2026, 4, 21);
      final felipeIds = assignmentIdsFor(
        email: 'felipe@gssolucoestec.com.br',
        login: 'felipe',
        aliases: const ['Felipe Souza'],
      );
      final os = SavedOs(
        id: 'os-horas',
        number: '050/26',
        ownerEmail: 'administrativo@gssolucoestec.com.br',
        createdAt: DateTime(2026, 4, 21),
        files: const [],
        technicianEmail: 'felipe@gssolucoestec.com.br',
        technicianName: 'Felipe Souza',
        technicianEmails: const ['felipe@gssolucoestec.com.br'],
        status: OsStatus.emAndamento,
        rdo: const RdoData(client: 'DINÂMICA', site: 'TERMINAL BELÉM'),
        rdos: [
          rdoOn(tiradentes, '17:00'),
          rdoOn(sunday, '17:00'),
          rdoOn(tuesday, '19:00'),
        ],
      );
      final other = SavedOs(
        id: 'os-andre',
        number: '051/26',
        ownerEmail: 'administrativo@gssolucoestec.com.br',
        createdAt: tuesday,
        files: const [],
        technicianEmail: 'andre@gssolucoestec.com.br',
        technicianName: 'André',
        technicianEmails: const ['andre@gssolucoestec.com.br'],
        status: OsStatus.emAndamento,
        rdo: const RdoData(client: 'ALESAT/MG'),
        rdos: [rdoOn(tuesday, '19:00', who: 'André')],
      );

      final week = buildHoursReport(
        technicianName: 'Felipe Souza',
        viewerIds: felipeIds,
        orders: [os, other],
        from: sunday,
        to: wednesday,
      );
      expect(week.days, hasLength(4));
      expect(week.days[0].weekdayLabel, 'domingo');
      expect(week.days[0].place, 'DINÂMICA');
      expect(week.days[0].workedMinutes, 8 * 60);
      expect(week.days[0].extraMinutes, 8 * 60);
      expect(week.days[1].place, atHomeLabel);
      expect(week.days[1].workedMinutes, 0);
      expect(week.days[2].weekdayLabel, 'terça-feira');
      expect(week.days[2].place, 'DINÂMICA');
      expect(week.days[2].workedMinutes, 10 * 60);
      expect(week.days[2].extraMinutes, 2 * 60);
      expect(week.days[3].place, atHomeLabel);
      expect(week.totalWorkedMinutes, 18 * 60);
      expect(week.totalExtraMinutes, 10 * 60);

      final holiday = buildHoursReport(
        technicianName: 'Felipe Souza',
        viewerIds: felipeIds,
        orders: [os],
        from: tiradentes,
        to: tiradentes,
      );
      expect(holiday.days.single.holiday, isTrue);
      expect(holiday.days.single.holidayName, 'Tiradentes');
      expect(holiday.days.single.extraMinutes, 8 * 60);
      expect(holiday.days.single.place, 'DINÂMICA');

      final csv = hoursReportCsv(week);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv,
        contains(
          'Data;Dia da semana;Feriado;Cliente;Horas trabalhadas;Horas extras;Adicional noturno',
        ),
      );
      expect(csv, contains('Em casa'));
      expect(csv, contains('DINÂMICA'));
      expect(csv, contains('domingo'));
      expect(csv, contains('Total;;;;18h;10h;0h'));
      expect(hoursReportFileStem(week), 'Horas_Felipe_Souza_160826_190826');

      final andreIds = assignmentIdsFor(
        email: 'andre@gssolucoestec.com.br',
        login: 'nascimento',
        aliases: const ['André Nascimento', 'andre', 'nascimento'],
      );
      final andreWeek = buildHoursReport(
        technicianName: 'André Nascimento',
        viewerIds: andreIds,
        orders: [os, other],
        from: sunday,
        to: wednesday,
      );
      expect(andreWeek.days[2].workedMinutes, 10 * 60);
      expect(andreWeek.totalWorkedMinutes, 10 * 60);

      final andreOnly = SavedOs(
        id: 'os-andre-solo',
        number: '052/26',
        ownerEmail: 'administrativo@gssolucoestec.com.br',
        createdAt: tuesday,
        files: const [],
        technicianEmail: 'andre@gssolucoestec.com.br',
        technicianName: 'André Nascimento',
        technicianEmails: const ['andre@gssolucoestec.com.br'],
        status: OsStatus.emAndamento,
        rdo: const RdoData(client: 'CLIENTE SOLO'),
        rdos: [rdoOn(tuesday, '17:00', who: 'Felipe Souza')],
      );
      final andreSolo = buildHoursReport(
        technicianName: 'André Nascimento',
        viewerIds: andreIds,
        orders: [andreOnly],
        from: tuesday,
        to: tuesday,
      );
      expect(andreSolo.days.single.workedMinutes, 8 * 60);
    },
  );

  test('duas OS no mesmo dia não somam horário sobreposto', () {
    SavedRdo rdoOn({
      required DateTime date,
      required String clockOut,
      required String who,
    }) {
      return SavedRdo(
        id: '$who-$clockOut',
        date: date,
        clockIn: '08:00',
        lunchStart: '12:00',
        lunchEnd: '13:00',
        clockOut: clockOut,
        description: '',
        notes: '',
        files: const [],
        createdAt: date,
        responsibleName: who,
      );
    }

    final monday = DateTime(2026, 7, 27);
    expect(monday.weekday, DateTime.monday);
    final ale = SavedOs(
      id: 'os-ale',
      number: '080/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: monday,
      files: const [],
      technicianName: 'Cleber Guimarães, Felipe Souza',
      technicianEmails: const [
        'cleber@gssolucoestec.com.br',
        'felipe@gssolucoestec.com.br',
      ],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'ALE COMBUSTÍVEL S.A'),
      rdos: [rdoOn(date: monday, clockOut: '19:10', who: 'Felipe Souza')],
    );
    final ipiranga = SavedOs(
      id: 'os-ipi',
      number: '081/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: monday,
      files: const [],
      technicianName: 'Cleber Guimarães',
      technicianEmails: const ['cleber@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'Ipiranga Produtos de Petróleo S.A.'),
      rdos: [rdoOn(date: monday, clockOut: '17:00', who: 'Cleber Guimarães')],
    );
    final cleberIds = assignmentIdsFor(
      email: 'cleber@gssolucoestec.com.br',
      login: 'cleber',
      aliases: const ['Cleber Guimarães'],
    );
    final felipeIds = assignmentIdsFor(
      email: 'felipe@gssolucoestec.com.br',
      login: 'felipe',
      aliases: const ['Felipe Souza'],
    );

    final cleber = buildHoursReport(
      technicianName: 'Cleber Guimarães',
      viewerIds: cleberIds,
      orders: [ale, ipiranga],
      from: monday,
      to: monday,
    );
    expect(cleber.days.single.place, contains('ALE COMBUSTÍVEL S.A'));
    expect(cleber.days.single.place, contains('Ipiranga'));
    expect(cleber.days.single.workedMinutes, 10 * 60 + 10);
    expect(cleber.days.single.extraMinutes, 2 * 60 + 10);

    final felipe = buildHoursReport(
      technicianName: 'Felipe Souza',
      viewerIds: felipeIds,
      orders: [ale, ipiranga],
      from: monday,
      to: monday,
    );
    expect(felipe.days.single.place, 'ALE COMBUSTÍVEL S.A');
    expect(felipe.days.single.workedMinutes, 10 * 60 + 10);
    expect(felipe.days.single.extraMinutes, 2 * 60 + 10);

    final sequential = dayHoursFromRdos([
      SavedRdo(
        id: 'manha',
        date: monday,
        clockIn: '08:00',
        lunchStart: '',
        lunchEnd: '',
        clockOut: '12:00',
        description: '',
        notes: '',
        files: const [],
        createdAt: monday,
        responsibleName: 'Felipe Souza',
      ),
      SavedRdo(
        id: 'tarde',
        date: monday,
        clockIn: '13:00',
        lunchStart: '',
        lunchEnd: '',
        clockOut: '17:00',
        description: '',
        notes: '',
        files: const [],
        createdAt: monday,
        responsibleName: 'Felipe Souza',
      ),
    ]);
    expect(sequential.workedMinutes, 8 * 60);
  });

  test('fechamento da folha vai do dia 24 ao 23', () {
    final inCycle = payrollPeriodFor(DateTime(2026, 8, 10));
    expect(inCycle.from, DateTime(2026, 7, 24));
    expect(inCycle.to, DateTime(2026, 8, 23));

    final closeDay = payrollPeriodFor(DateTime(2026, 8, 23));
    expect(closeDay.from, DateTime(2026, 7, 24));
    expect(closeDay.to, DateTime(2026, 8, 23));

    final newCycle = payrollPeriodFor(DateTime(2026, 8, 24));
    expect(newCycle.from, DateTime(2026, 8, 24));
    expect(newCycle.to, DateTime(2026, 9, 23));

    final january = payrollPeriodFor(DateTime(2026, 1, 10));
    expect(january.from, DateTime(2025, 12, 24));
    expect(january.to, DateTime(2026, 1, 23));
  });

  test('domingo sem horário não conta hora extra', () {
    final sunday = DateTime(2026, 8, 16);
    expect(sunday.weekday, DateTime.sunday);
    final blank = SavedRdo(
      id: 'blank-sunday',
      date: sunday,
      clockIn: '',
      lunchStart: '',
      lunchEnd: '',
      clockOut: '',
      description: 'sem serviço',
      notes: '',
      files: const [],
      createdAt: sunday,
      responsibleName: 'Felipe Souza',
    );
    expect(rdoWorkedMinutes(blank), 0);
    expect(
      extraMinutesForDay(
        workedMinutes: rdoWorkedMinutes(blank),
        day: sunday,
        holiday: false,
      ),
      0,
    );

    final parsed = SavedRdo.fromJson({
      'id': 'json-blank',
      'date': sunday.toIso8601String(),
      'clockIn': '',
      'clockOut': '',
      'description': 'sem serviço',
      'responsibleName': 'Felipe Souza',
    });
    expect(parsed.clockIn, '');
    expect(parsed.clockOut, '');
    expect(rdoWorkedMinutes(parsed), 0);

    final ids = assignmentIdsFor(
      email: 'felipe@gssolucoestec.com.br',
      login: 'felipe',
      aliases: const ['Felipe Souza'],
    );
    final os = SavedOs(
      id: 'os-domingo',
      number: '070/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: sunday,
      files: const [],
      technicianEmail: 'felipe@gssolucoestec.com.br',
      technicianName: 'Felipe Souza',
      technicianEmails: const ['felipe@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdos: [blank],
    );
    final report = buildHoursReport(
      technicianName: 'Felipe Souza',
      viewerIds: ids,
      orders: [os],
      from: sunday,
      to: sunday,
    );
    expect(report.days.single.workedMinutes, 0);
    expect(report.days.single.extraMinutes, 0);
  });

  test(
    'horas extras seguem 8h mais almoço, sábado 4h e noturno 22h às 05h',
    () {
      SavedRdo rdo({
        required DateTime date,
        required String clockIn,
        required String clockOut,
        String lunchStart = '12:00',
        String lunchEnd = '13:00',
      }) {
        return SavedRdo(
          id: '$clockIn-$clockOut',
          date: date,
          clockIn: clockIn,
          lunchStart: lunchStart,
          lunchEnd: lunchEnd,
          clockOut: clockOut,
          description: '',
          notes: '',
          files: const [],
          createdAt: date,
          responsibleName: 'Felipe Souza',
        );
      }

      final tuesday = DateTime(2026, 8, 18);
      final saturday = DateTime(2026, 8, 15);
      expect(saturday.weekday, DateTime.saturday);

      final dayShift = rdo(date: tuesday, clockIn: '08:00', clockOut: '17:00');
      expect(rdoWorkedMinutes(dayShift), 8 * 60);
      expect(
        extraMinutesForDay(
          workedMinutes: rdoWorkedMinutes(dayShift),
          day: tuesday,
          holiday: false,
        ),
        0,
      );

      final noLunch = rdo(
        date: tuesday,
        clockIn: '08:00',
        clockOut: '17:00',
        lunchStart: '',
        lunchEnd: '',
      );
      expect(rdoWorkedMinutes(noLunch), 8 * 60);

      final overtime = rdo(date: tuesday, clockIn: '08:00', clockOut: '18:00');
      expect(rdoWorkedMinutes(overtime), 9 * 60);
      expect(
        extraMinutesForDay(
          workedMinutes: rdoWorkedMinutes(overtime),
          day: tuesday,
          holiday: false,
        ),
        60,
      );

      expect(
        extraMinutesForDay(
          workedMinutes: 4 * 60,
          day: saturday,
          holiday: false,
        ),
        0,
      );
      expect(
        extraMinutesForDay(
          workedMinutes: 6 * 60,
          day: saturday,
          holiday: false,
        ),
        2 * 60,
      );

      final night = rdo(
        date: tuesday,
        clockIn: '22:00',
        clockOut: '05:00',
        lunchStart: '00:00',
        lunchEnd: '01:00',
      );
      expect(rdoPresenceMinutes(night), 7 * 60);
      expect(rdoWorkedMinutes(night), 6 * 60);
      expect(rdoNightMinutes(night), 6 * 60);

      final evening = rdo(
        date: tuesday,
        clockIn: '20:00',
        clockOut: '23:00',
        lunchStart: '',
        lunchEnd: '',
      );
      expect(rdoWorkedMinutes(evening), 3 * 60);
      expect(rdoNightMinutes(evening), 60);
      expect(
        extraMinutesForDay(
          workedMinutes: rdoWorkedMinutes(evening),
          day: tuesday,
          holiday: false,
        ),
        0,
      );
    },
  );

  testWidgets('funcionários escolhe o técnico e baixa o relatório de horas', (
    tester,
  ) async {
    StaffStore.instance.users = [
      const RemoteAccount(
        email: 'felipe@gssolucoestec.com.br',
        login: 'felipe',
        name: 'Felipe Souza',
        phone: '',
        role: 'tecnico',
        status: 'aprovado',
        active: true,
      ),
    ];
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();
    await _login(tester, 'Cleber', password: '1234');
    await _openHomeCard(tester, const Key('open-staff'));
    expect(find.byKey(const Key('staff-search')), findsOneWidget);
    expect(find.text('Cadastro da equipe'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('E-mail'), findsWidgets);
    expect(find.text('felipe@gssolucoestec.com.br'), findsWidgets);
    final staffScroll = find.descendant(
      of: find.byKey(const Key('staff-list')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Analisar horas'),
      240,
      scrollable: staffScroll,
    );
    expect(find.text('Analisar horas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Relatório de horas'),
      240,
      scrollable: staffScroll,
    );
    expect(find.text('Relatório de horas'), findsOneWidget);
    expect(find.byKey(const Key('hours-tech')), findsOneWidget);
    expect(find.byKey(const Key('hours-from')), findsOneWidget);
    expect(find.byKey(const Key('hours-to')), findsOneWidget);
    expect(find.byKey(const Key('hours-download-pdf')), findsOneWidget);
    expect(find.byKey(const Key('hours-download-csv')), findsOneWidget);
  });

  test('OS gerada entra no calendário no dia em que foi enviada à agenda', () {
    final os = SavedOs(
      id: 'os-nova',
      number: '045/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 19),
      files: const [],
      technicianEmail: 'felipe@gssolucoestec.com.br',
      technicianName: 'Felipe Souza',
      technicianEmails: const ['felipe@gssolucoestec.com.br'],
      status: OsStatus.comTecnico,
      rdo: const RdoData(client: 'DINÂMICA', site: 'TERMINAL BELÉM'),
    );
    final weekStart = DateTime(2026, 8, 17);
    final now = DateTime(2026, 8, 19);
    expect(plannedAgendaDay(os, weekStart, now: now), DateTime(2026, 8, 19));
    final wednesday = agendaJobsOnDay(
      [os],
      DateTime(2026, 8, 19),
      weekStart: weekStart,
      now: now,
    );
    expect(wednesday, hasLength(1));
    expect(wednesday.first.os.number, '045/26');
    expect(wednesday.first.rdo, isNull);
    expect(
      agendaJobsOnDay(
        [os],
        DateTime(2026, 8, 18),
        weekStart: weekStart,
        now: now,
      ),
      isEmpty,
    );
    expect(
      agendaJobsOnDay(
        [os.copyWith(status: OsStatus.rascunho)],
        DateTime(2026, 8, 19),
        weekStart: weekStart,
        now: now,
      ),
      isEmpty,
    );
  });

  test(
    'RDO de hoje abre a OS ativa pela data de início, não a última gerada',
    () {
      SavedOs order({
        required String id,
        required String number,
        required DateTime created,
        required DateTime starts,
      }) {
        return SavedOs(
          id: id,
          number: number,
          ownerEmail: 'administrativo@gssolucoestec.com.br',
          createdAt: created,
          startsAt: starts,
          files: const [],
          technicianEmail: 'cleber@gssolucoestec.com.br',
          technicianName: 'Cleber Guimarães',
          technicianEmails: const ['cleber@gssolucoestec.com.br'],
          status: OsStatus.emAndamento,
          rdo: const RdoData(client: 'ALE COMBUSTÍVEL S.A'),
        );
      }

      final first = order(
        id: 'os-1',
        number: '034/26',
        created: DateTime(2026, 8, 18),
        starts: DateTime(2026, 8, 20),
      );
      final second = order(
        id: 'os-2',
        number: '035/26',
        created: DateTime(2026, 8, 21),
        starts: DateTime(2026, 8, 25),
      );
      final third = order(
        id: 'os-3',
        number: '036/26',
        created: DateTime(2026, 8, 22),
        starts: DateTime(2026, 9, 1),
      );
      final newestFirst = [third, second, first];

      expect(
        activeOsForRdoToday(newestFirst, now: DateTime(2026, 8, 23))?.number,
        '034/26',
      );
      expect(
        activeOsForRdoToday(newestFirst, now: DateTime(2026, 8, 26))?.number,
        '035/26',
      );
      expect(
        activeOsForRdoToday(newestFirst, now: DateTime(2026, 9, 1))?.number,
        '036/26',
      );
      expect(
        rdoTodayOsChoices(newestFirst, now: DateTime(2026, 8, 19)),
        newestFirst,
      );
      expect(
        activeOsForRdoToday([
          first.copyWith(startsAt: DateTime(2026, 8, 20)),
          second.copyWith(startsAt: DateTime(2026, 8, 20)),
        ], now: DateTime(2026, 8, 21)),
        isNull,
      );
      expect(
        plannedAgendaDay(
          third,
          DateTime(2026, 8, 17),
          now: DateTime(2026, 8, 23),
        ),
        isNull,
      );
      expect(
        plannedAgendaDay(
          first,
          DateTime(2026, 8, 17),
          now: DateTime(2026, 8, 23),
        ),
        DateTime(2026, 8, 20),
      );
    },
  );

  test('fotos extras do RDO usam Anexo 1, 2 e 3', () {
    expect(photoSlotStoredLabel('Instrumento', 0), 'Instrumento');
    expect(photoSlotStoredLabel('Instrumento', 1), 'Instrumento · Anexo 1');
    expect(photoSlotDisplayLabel('Instrumento', 2), 'Anexo 2');
    expect(photoBelongsToSlot('Instrumento · Anexo 3', 'Instrumento'), isTrue);
    expect(photoBelongsToSlot('Padrão', 'Instrumento'), isFalse);
    expect(photoSlotIndex('Instrumento · Anexo 1', 'Instrumento'), 1);
  });

  test('e-mail do escritório vai para administrativo e Amanda', () {
    expect(
      officeEmails,
      containsAll([
        'administrativo@gssolucoestec.com.br',
        'amanda@gssolucoestec.com.br',
      ]),
    );
    expect(officeEmailTo, contains('amanda@gssolucoestec.com.br'));
    expect(
      officeEmailSubject('036/26'),
      'RDO da Ordem de Serviço 036/26 — GS Soluções Técnicas',
    );
    expect(
      officeEmailSubject('036/26', attachmentsOnly: true),
      'Anexos da Ordem de Serviço 036/26 — GS Soluções Técnicas',
    );
    final gmail = gmailComposeUri(
      to: const ['cliente@base.com'],
      cc: officeEmails,
      subject: 'RDO da OS 036/26 — GS Soluções Técnicas',
      body: 'Segue o RDO.',
    );
    expect(gmail.host, 'mail.google.com');
    expect(gmail.queryParameters['to'], 'cliente@base.com');
    expect(
      gmail.queryParameters['cc'],
      contains('amanda@gssolucoestec.com.br'),
    );
    expect(gmail.queryParameters['su'], contains('036/26'));
    expect(gmail.queryParameters['body'], contains('Segue o RDO'));
    expect(prefersOfficeEmlDownload(), isFalse);
    expect(OfficeSendKind.needsServer, isNot(OfficeSendKind.eml));
    final mailto = officeMailtoUri(
      to: const ['cleber@gssolucoestec.com.br'],
      cc: officeEmails,
      subject: 'Anexos da Ordem de Serviço 044/26 — GS Soluções Técnicas',
      body: 'Prezados,\n\nEncaminho os anexos da Ordem de Serviço nº 044/26.',
    );
    expect(mailto.scheme, 'mailto');
    expect(mailto.path, 'cleber@gssolucoestec.com.br');
    expect(
      mailto.queryParameters['cc'],
      contains('amanda@gssolucoestec.com.br'),
    );
    expect(mailto.queryParameters['subject'], contains('044/26'));
    expect(mailto.queryParameters['body'], startsWith('Prezados,'));
    expect(mailto.queryParameters['body'], isNot(contains('Para: ')));
    expect(mailto.toString(), contains('Prezados%2C'));
    expect(mailto.toString(), isNot(contains('Encaminho+')));
    expect(mailto.toString(), isNot(contains('Prezados+')));
  });

  test('texto do e-mail não coloca o destinatário no corpo', () {
    final os = SavedOs(
      id: 'os-mail-to',
      number: '044/26',
      ownerEmail: 'cleber@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 19),
      files: const [],
      rdo: const RdoData(
        client: 'DINÂMICA TERMINAIS CANEDO S/A',
        baseName: 'Gustavo Melo',
        baseEmail: 'gustavo@dtcterminais.com.br',
      ),
    );
    final body = officeEmailBody(
      os: os,
      technicianName: 'Cleber Guimarães',
      attachmentsOnly: true,
    );
    expect(body, startsWith('Prezados,'));
    expect(body, isNot(contains('Para: ')));
    expect(body, contains('Documentos anexos:'));
  });

  test('envio do RDO não grava PDF no armazenamento local', () async {
    final pdf = List<int>.filled(20000, 7);
    final os = SavedOs(
      id: 'os-quota',
      number: '070/26',
      ownerEmail: 'a@b.com',
      createdAt: DateTime(2026, 8, 17),
      files: [
        SavedFile(
          name: 'rdo.pdf',
          path: 'mem/rdo.pdf',
          kind: OsFileKind.rdo,
          bytes: pdf,
        ),
      ],
      rdos: [
        SavedRdo(
          id: '1',
          date: DateTime(2026, 8, 18),
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: '',
          notes: '',
          files: [
            SavedFile(
              name: 'rdo.pdf',
              path: 'mem/rdo.pdf',
              kind: OsFileKind.rdo,
              bytes: pdf,
            ),
          ],
          createdAt: DateTime(2026, 8, 18),
          responsibleName: 'André',
        ),
      ],
      status: OsStatus.emAndamento,
    );
    await OfficeStore.instance.receive(os);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(officeRdosPrefsKey), isNull);
    expect(OfficeStore.instance.items.single.number, '070/26');
    OfficeStore.instance.items = [];
  });

  test('campo de e-mail segue administrativos, cliente ou os dois', () {
    expect(
      destinationEmailsFor(audience: MailAudience.office),
      contains('administrativo@gssolucoestec.com.br'),
    );
    expect(
      destinationEmailsFor(audience: MailAudience.office),
      contains('amanda@gssolucoestec.com.br'),
    );
    expect(
      destinationEmailsFor(
        audience: MailAudience.client,
        clientEmail: 'gustavo@dtcterminais.com.br',
      ),
      'gustavo@dtcterminais.com.br',
    );
    final both = destinationEmailsFor(
      audience: MailAudience.both,
      clientEmail: 'gustavo@dtcterminais.com.br',
    );
    expect(both, startsWith('gustavo@dtcterminais.com.br'));
    expect(both, contains('amanda@gssolucoestec.com.br'));
  });

  testWidgets('chips preenchem o campo com os e-mails cadastrados', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailAudiencePicker(
            value: MailAudience.office,
            registeredClientEmail: 'gustavo@dtcterminais.com.br',
            clientEmailController: controller,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Administrativos'));
    await tester.pump();
    expect(controller.text, contains('administrativo@gssolucoestec.com.br'));
    expect(controller.text, contains('amanda@gssolucoestec.com.br'));
    expect(controller.text, isNot(contains('gustavo@dtcterminais.com.br')));

    await tester.tap(find.text('Cliente'));
    await tester.pump();
    expect(controller.text, 'gustavo@dtcterminais.com.br');

    await tester.tap(find.text('Cliente e administrativos'));
    await tester.pump();
    expect(controller.text, startsWith('gustavo@dtcterminais.com.br'));
    expect(controller.text, contains('administrativo@gssolucoestec.com.br'));
  });

  test('mensagem do RDO usa texto formal com dias e documentos', () {
    final os = SavedOs(
      id: 'os-mail',
      number: '044/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: DateTime(2026, 8, 17),
      files: const [],
      rdo: const RdoData(
        client: 'DINÂMICA TERMINAIS CANEDO S/A',
        baseName: 'Gustavo Melo',
        baseEmail: 'gustavo@dtcterminais.com.br',
        basePhone: '+55 81 99973-6901',
      ),
      rdos: [
        SavedRdo(
          id: '1',
          date: DateTime(2026, 8, 17),
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'serviço',
          notes: '',
          files: const [],
          createdAt: DateTime(2026, 8, 17),
        ),
        SavedRdo(
          id: '2',
          date: DateTime(2026, 8, 18),
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'serviço',
          notes: '',
          files: const [],
          createdAt: DateTime(2026, 8, 18),
        ),
      ],
    );
    final body = officeEmailBody(
      os: os,
      technicianName: 'Vinicius Magalhães',
      withSignature: false,
    );
    expect(body, contains('Encaminho, para conhecimento e registro'));
    expect(body, contains('nos dias 17/08/2026 e 18/08/2026'));
    expect(
      body,
      contains('tendo como contratante a DINÂMICA TERMINAIS CANEDO S/A'),
    );
    expect(body, contains('gustavo@dtcterminais.com.br'));
    expect(body, contains('sem assinatura eletrônica neste envio'));
    expect(body, contains('ICP-Brasil'));
    expect(body, contains('RDO_OS_044-26_170826_sem_assinatura.pdf'));
    expect(body, contains('referente às atividades de 18/08/2026'));
    expect(body, contains(' - referente às atividades de 17/08/2026'));
    expect(body, isNot(contains('anexo interno da OS')));
    expect(
      officeEmailSubject('044/26'),
      'RDO da Ordem de Serviço 044/26 — GS Soluções Técnicas',
    );
  });

  test('resposta de status da planilha não conta como e-mail enviado', () {
    expect(isFakeMailStatus({'ok': true, 'cleberBlocked': false}), isTrue);
    expect(isFakeMailStatus({'ok': true, 'sent': true, 'files': 1}), isFalse);
  });

  test('mensagem .eml do navegador já leva destinatário e anexo', () {
    final bytes = buildOfficeEml(
      to: const ['gustavo@dtcterminais.com.br'],
      cc: officeEmails,
      subject: 'RDO da OS 044/26 — GS Soluções Técnicas',
      body: 'Segue o RDO da ordem de serviço 044/26.',
      files: [
        OfficeMailFile(name: 'RDO_OS_044-26_170826.pdf', bytes: [1, 2, 3, 4]),
      ],
    );
    final eml = String.fromCharCodes(bytes);
    expect(eml, contains('X-Unsent: 1'));
    expect(eml, contains('To: gustavo@dtcterminais.com.br'));
    expect(eml, contains('Cc: administrativo@gssolucoestec.com.br'));
    expect(eml, contains('filename="RDO_OS_044-26_170826.pdf"'));
    expect(eml, contains('AQIDBA=='));
    expect(
      officeEmlFileName('RDO da OS 044/26 — GS Soluções Técnicas'),
      'RDO da OS 044-26 - GS Soluções Técnicas.eml',
    );
  });

  test('assinatura eletrônica traz nome, cargo, data e GS Soluções', () {
    final lines = electronicSignatureLines(
      name: 'Cleber Guimarães',
      cargo: 'Técnico em Instrumentação Industrial',
      signedAt: DateTime(2026, 8, 18, 17, 37, 0),
    );
    expect(lines.first, 'Assinado eletronicamente por:');
    expect(lines, contains('Cleber Guimarães'));
    expect(lines, contains('Cargo: Técnico em Instrumentação Industrial'));
    expect(lines.join('\n'), contains('Data: 18/08/2026 17:37:00'));
    expect(lines, contains('$gsCompanyName CNPJ:'));
    expect(lines, contains(gsCompanyCnpj));
  });

  test('cargo do técnico fica gravado por pessoa na OS', () {
    final rdo = RdoData.fromJson({
      'technicianCargos': {
        'cleber': 'Técnico em Instrumentação Industrial',
        'felipe': 'Técnico de campo',
      },
    });
    expect(
      rdo.technicianCargos['cleber'],
      'Técnico em Instrumentação Industrial',
    );
    expect(
      RdoData.fromJson(rdo.toJson()).technicianCargos['felipe'],
      'Técnico de campo',
    );
  });

  test('RDO guarda assinatura do cliente', () {
    final entry = SavedRdo(
      id: '2',
      date: DateTime(2026, 8, 18),
      clockIn: '08:00',
      lunchStart: '12:00',
      lunchEnd: '13:00',
      clockOut: '17:00',
      description: '',
      notes: '',
      files: const [],
      createdAt: DateTime(2026, 8, 18),
      responsibleName: 'Cleber Guimarães',
      clientSignedName: 'Maurício',
      clientSignedAt: DateTime(2026, 8, 18, 18, 0),
    );
    final roundtrip = SavedRdo.fromJson(entry.toJson());
    expect(roundtrip.clientSignedName, 'Maurício');
    expect(roundtrip.clientSigned, isTrue);
    expect(roundtrip.bothSigned, isTrue);
  });

  testWidgets('gera RDO em PDF no modelo da capa GS', (tester) async {
    final bytes = await buildRdoPdf(
      osNumber: '036/26',
      technicianName: 'Cleber Guimarães, Felipe Souza, Andre Nascimento',
      rdo: const RdoData(
        client: 'DINAMICA TERMINAIS CANEDO S/A',
        site:
            'AV TROPICAL, S/N, QUADRAMODULO 6-B, DISTRITO INDUSTRIAL BRASIL CENTRAL, Senador Canedo_ Go',
        cnpj: '33.047.181/0001-60',
        service: 'Calibração',
        systemType: 'Descarregamento',
        clockIn: '08:00',
        lunchStart: '12:00',
        lunchEnd: '13:00',
        clockOut: '17:30',
        description:
            'Ao chegar à base, a equipe de operação alinhou um caminhão-tanque (CT) carregado com Etanol Hidratado na Plataforma 9.2, permitindo a realização da sua calibração. Em seguida, a operação posicionou um CT carregado com Diesel S10, possibilitando a sua calibração e a conclusão dos trabalhos na Plataforma 9.2. Após o almoço, efetuamos os ajustes dos densímetros das Plataformas 07, 08 e 09 e realizamos a remoção do master meter da Plataforma 9.2.',
        technicianCargo: 'Técnico em Instrumentação Industrial',
        baseName: 'Maurício',
        baseCargo: 'Supervisor',
        baseEmail: 'mauricio@base.com',
        basePhone: '',
      ),
      date: DateTime(2026, 8, 11),
      responsibleName: 'Cleber Guimarães',
      signedAt: DateTime(2026, 8, 11, 17, 30),
    );
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(rdoFileName('036/26'), 'RDO_OS_036-26.pdf');
    expect(
      rdoFileName('036/26', DateTime(2026, 8, 15)),
      'RDO_OS_036-26_150826.pdf',
    );
    expect(
      rdoUnsignedFileName('036/26', DateTime(2026, 8, 15)),
      'RDO_OS_036-26_150826_sem_assinatura.pdf',
    );
    final unsigned = await buildRdoPdf(
      osNumber: '036/26',
      technicianName: 'Cleber Guimarães',
      rdo: const RdoData(client: 'DINAMICA TERMINAIS CANEDO S/A'),
      date: DateTime(2026, 8, 15),
      responsibleName: 'Cleber Guimarães',
      withSignature: false,
    );
    expect(unsigned.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  testWidgets('PDF da descrição longa cabe no relatório', (tester) async {
    final long = List.filled(
      40,
      'Os responsáveis da base liberaram um CT com B100 para descarregar no skid 02. Depois foi realizada a aculturação do medidor e a calibração da gasolina.',
    ).join(' ');
    final bytes = await buildRdoPdf(
      osNumber: '044/26',
      technicianName: 'Felipe Souza',
      rdo: RdoData(
        client: 'DINAMICA TERMINAIS CANEDO S/A',
        description: long,
        notes: 'Devido ao horário, o master ficou para o dia seguinte.',
      ),
      date: DateTime(2026, 8, 18),
      responsibleName: 'Felipe Souza',
      withSignature: false,
    );
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(long.length, greaterThan(500));
  });

  testWidgets('gera PDF da tabela 20 °C com identificação da amostra', (
    tester,
  ) async {
    final result = convertDerivados(
      densityAmbient: 723,
      temperature: 25,
      volumeAmbient: 10000,
      temperatureCt: 25,
      volumeDanfe: 9940,
    );
    final bytes = await buildTabela20Pdf(
      Tabela20PdfData(
        kindLabel: 'Derivados de petróleo',
        standard: 'ASTM / tabela GS · 20 °C',
        date: DateTime(2026, 8, 17),
        productName: 'S10',
        systemNumber: 'CT-01',
        technicianName: 'Felipe Souza',
        densityAmbient: '723',
        temperatureSample: '25',
        volumeAmbient: '10000',
        temperatureCt: '25',
        volumeObjeto: '9940',
        result: result,
      ),
    );
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(
      tabela20FileName(
        kind: 'derivados',
        date: DateTime(2026, 8, 17),
        product: 'S10',
        system: 'CT/01',
      ),
      'Tabela20_derivados_S10_CT-01_170826.pdf',
    );
  });

  testWidgets('GS Soluções é o acesso principal da empresa', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'gssolucoes', password: '1234');

    expect(find.textContaining('GS Soluções'), findsWidgets);
    expect(find.text('Agenda da equipe'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-gerar-os')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Funcionários'), findsOneWidget);
    expect(find.text('Gerar OS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Área do técnico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Área do técnico'), findsOneWidget);
    expect(find.byKey(const Key('tab-calibracao')), findsOneWidget);
    expect(find.byKey(const Key('tab-config')), findsOneWidget);
  });

  testWidgets('configurações mostra conta e senha', (tester) async {
    await tester.pumpWidget(const GsApp());
    await tester.pumpAndSettle();

    await _login(tester, 'Cleber', password: '1234');
    await tester.tap(find.byKey(const Key('tab-config')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-login')), findsOneWidget);
    expect(find.byKey(const Key('settings-name')), findsOneWidget);
    expect(find.textContaining('Cleber Guimarães'), findsWidgets);
  });

  test(
    'salvar conta de novo depois de trocar o usuário aceita a mesma senha',
    () async {
      await AuthSession.instance.signIn('gssolucoes', password: '1234');
      expect(
        await AuthSession.instance.updateProfile(
          name: 'GS SOLUCOES',
          login: 'gsempresa',
          email: 'administrativo@gssolucoestec.com.br',
          phone: '21995788574',
          currentPassword: '1234',
        ),
        isNull,
      );
      expect(AuthSession.instance.user?.login, 'gsempresa');
      AuthSession.instance.user = gsUser.copyWith(name: 'GS SOLUCOES');
      expect(
        await AuthSession.instance.updateProfile(
          name: 'GS SOLUCOES',
          login: 'gssolucoes',
          email: 'administrativo@gssolucoestec.com.br',
          phone: '21995788574',
          currentPassword: '1234',
        ),
        isNull,
      );
    },
  );

  test('sem nuvem não troca senha só neste aparelho', () async {
    await AuthSession.instance.signIn('cleber', password: '1234');
    expect(
      await AuthSession.instance.changePassword(
        currentPassword: '1234',
        newPassword: '5678',
        confirmPassword: '5678',
      ),
      contains('Sem conexão com a nuvem'),
    );
    await AuthSession.instance.signOut();
    expect(
      await AuthSession.instance.signIn('cleber', password: '5678'),
      'Senha incorreta.',
    );
    expect(
      await AuthSession.instance.signIn('cleber', password: '1234'),
      isNull,
    );
  });

  testWidgets('certificado de calibração monta PDF no layout GS com gráfico', (
    tester,
  ) async {
    final job =
        newCalibrationJob(
          kind: CalibrationKind.volumetric,
          technicianName: 'Cleber Guimarães',
        ).copyWith(
          number: 'GS-VOL-2026-0046',
          clientName: 'Cliente Teste',
          clientCnpj: '00.000.000/0001-00',
          clientAddress: 'Belém/PA',
          site: 'Patio de tanques',
          equipmentTag: 'FT-01',
          equipmentType: 'Medidor volumétrico',
          manufacturer: 'GS',
          model: 'VM-100',
          serialNumber: 'SN-46',
          workingPrinciple: 'Coriolis',
          coriolisCoefficients: const [
            CoriolisCoefficient(
              id: 'cf1',
              label: 'Flow Cal.',
              found: '226,795',
            ),
            CoriolisCoefficient(id: 'cf2', label: 'KD', found: '2,0062'),
            CoriolisCoefficient(id: 'cf3', label: 'SK20', found: '23136'),
          ],
          procedure: 'Comparação direta com padrão volumétrico.',
          points: [
            FlowPoint(
              id: 'p1',
              flowRate: 20,
              oldMeterFactor: 1,
              verification: [
                VolumeRun(
                  id: 'a',
                  objectVolume: 20.02,
                  standardVolume: 20,
                  temperature: 20.1,
                ),
                VolumeRun(
                  id: 'b',
                  objectVolume: 20.01,
                  standardVolume: 20,
                  temperature: 20.2,
                ),
              ],
            ),
            FlowPoint(
              id: 'p2',
              flowRate: 40,
              oldMeterFactor: 1,
              verification: [
                VolumeRun(
                  id: 'c',
                  objectVolume: 40.06,
                  standardVolume: 40,
                  temperature: 20.3,
                ),
                VolumeRun(
                  id: 'd',
                  objectVolume: 40.04,
                  standardVolume: 40,
                  temperature: 20.2,
                ),
              ],
            ),
          ],
          measurementUncertainty: '0,08',
          coverageFactor: '2,03',
          meterKFactorFound: '13,000',
          meterKFactorLeft: '13,050',
          standards: [
            CalibrationStandard(
              id: 's1',
              tag: 'PR-01',
              description: 'Prova volumétrica',
              certificate: 'RBC-100',
              validity: '12/2026',
              uncertainty: '0,1600',
            ),
          ],
        );
    final bytes = await buildCalibrationCertificate(job);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(8000));
  });

  testWidgets('certificado de temperatura usa o mesmo layout GS', (
    tester,
  ) async {
    final job =
        newCalibrationJob(
          kind: CalibrationKind.temperature,
          technicianName: 'Cleber Guimarães',
        ).copyWith(
          number: 'GS-TEMP-2026-0001',
          clientName: 'TEMAPE',
          clientCnpj: '00.000.000/0001-00',
          clientAddress: 'Belém/PA',
          equipmentTag: 'TT-01',
          equipmentType: 'PT100',
          cycleCount: 2,
          genericPoints: [
            GenericPoint(
              id: 'g1',
              label: '20 °C',
              oldFactor: 1.0,
              newValue: 0.998,
              cycles: const [
                GenericCycle(standard: 20, instrument: 20.12),
                GenericCycle(standard: 20, instrument: 20.08),
              ],
            ),
          ],
        );
    final bytes = await buildCalibrationCertificate(job);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(8000));
  });

  testWidgets('ponto genérico escolhe ciclos e carrega fator antigo/novo', (
    tester,
  ) async {
    final job = await CalibrationStore.instance.save(
      newCalibrationJob(
        kind: CalibrationKind.temperature,
        technicianName: 'Cleber Guimarães',
      ),
    );
    expect(job.cycleCount, 3);
    expect(job.genericPoints.first.cycles, hasLength(3));

    await tester.pumpWidget(
      MaterialApp(
        theme: GsTheme.data,
        home: CalibrationJobPage(jobId: job.id),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Verificações por ponto'),
      280,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Unidade de medida (sai no certificado)'), findsOneWidget);
    expect(find.text('Fator antigo'), findsWidgets);
    expect(find.text('Valor novo'), findsWidgets);
    expect(find.textContaining('Padrão 3'), findsWidgets);
    expect(
      find.byKey(const Key('calibracao-unidade-medida-mm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calibracao-unidade-medida-°C')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calibracao-ciclos-5')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Padrão 5'), findsWidgets);

    await tester.tap(find.byKey(const Key('calibracao-ciclos-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Padrão 1'), findsWidgets);
    expect(find.textContaining('Padrão 2'), findsNothing);
  });

  test('próximo ponto genérico herda valor novo como fator antigo', () {
    final previous = GenericPoint(
      id: 'g1',
      newValue: 1.012,
      cycles: const [GenericCycle(standard: 1, instrument: 1)],
    );
    final next = GenericPoint(id: 'g2', oldFactor: previous.newValue);
    expect(next.oldFactor, 1.012);
    final json = GenericPoint.fromJson(previous.toJson());
    expect(json.newValue, 1.012);
  });

  test('unidade de medida segue o tipo e pode ser sobrescrita', () {
    final temp = newCalibrationJob(
      kind: CalibrationKind.temperature,
      technicianName: 'Cleber',
    );
    expect(temp.measurementUnit, '°C');
    expect(resolvedMeasurementUnit(temp), '°C');
    expect(resolvedMeasurementUnit(temp.copyWith(measurementUnit: 'mm')), 'mm');

    final density = newCalibrationJob(
      kind: CalibrationKind.density,
      technicianName: 'Cleber',
    );
    expect(density.measurementUnit, 'kg/m³');

    final conductivity = newCalibrationJob(
      kind: CalibrationKind.conductivity,
      technicianName: 'Cleber',
    );
    expect(calibrationKindLabel(CalibrationKind.conductivity), 'Condutividade');
    expect(conductivity.measurementUnit, 'µS/cm');
    expect(
      suggestedMeasurementUnits(CalibrationKind.conductivity),
      contains('mS/cm'),
    );
    expect(conductivity.standards.length, 3);
    expect(conductivity.standards.first.tag, 'Solução padrão 1');
    expect(conductivity.genericPoints.length, 3);

    final channels = defaultTelemetryChannels();
    expect(channels.first.unit, 'mm');
    expect(suggestedTelemetryUnits('level'), contains('m'));
    expect(suggestedTelemetryUnits('temperature'), contains('°C'));
  });

  test('fluido cadastra densidade/viscosidade em faixa e ref. 20 °C', () {
    final fluid = CatalogFluid(
      id: 'f1',
      name: 'ÁLCOOL',
      densityMin: '0,780 g/cm³',
      densityMax: '0,840 g/cm³',
      viscosityMin: '1,5 cSt',
      viscosityMax: '3,5 cSt',
    );
    expect(fluid.temperature, '20 °C');
    expect(fluid.densityRangeLabel, '0,780 g/cm³ – 0,840 g/cm³');
    expect(fluid.viscosityRangeLabel, '1,5 cSt – 3,5 cSt');

    final legacy = CatalogFluid.fromJson({
      'id': 'f2',
      'name': 'DIESEL',
      'density': '0,840',
      'viscosity': '3,5',
      'temperature': '',
    });
    expect(legacy.densityMin, '0,840');
    expect(legacy.temperature, '20 °C');

    final job =
        newCalibrationJob(
          kind: CalibrationKind.volumetric,
          technicianName: 'Cleber',
        ).copyWith(
          fluid: fluid.name,
          fluidDensityMin: fluid.densityMin,
          fluidDensityMax: fluid.densityMax,
          fluidViscosityMin: fluid.viscosityMin,
          fluidViscosityMax: fluid.viscosityMax,
          fluidReferenceTemp: fluidReferenceTemperatureDefault,
          productDensity: '0,812 g/cm³',
          productTemperature: '28,4 °C',
        );
    expect(job.productDensity, '0,812 g/cm³');
    expect(job.fluidReferenceTemp, '20 °C');
  });

  test('linearidade com uma vazão é dispensada e não reprova', () {
    final single =
        newCalibrationJob(
          kind: CalibrationKind.volumetric,
          technicianName: 'Cleber',
          flowCount: 1,
          runCount: 2,
        ).copyWith(
          points: [
            FlowPoint(
              id: 'p1',
              flowRate: 500,
              oldMeterFactor: 1,
              verification: [
                VolumeRun(id: 'a', objectVolume: 5000, standardVolume: 5001),
                VolumeRun(id: 'b', objectVolume: 5000, standardVolume: 5002),
              ],
            ),
          ],
        );
    expect(single.filledPoints, hasLength(1));
    expect(single.linearityApplicable, isFalse);
    expect(single.linearity, isNull);
    expect(single.linearityOk, isTrue);

    final two = single.copyWith(
      points: [
        ...single.points,
        FlowPoint(
          id: 'p2',
          flowRate: 250,
          oldMeterFactor: 1,
          verification: [
            VolumeRun(id: 'c', objectVolume: 2500, standardVolume: 2501),
            VolumeRun(id: 'd', objectVolume: 2500, standardVolume: 2502),
          ],
        ),
      ],
    );
    expect(two.linearityApplicable, isTrue);
    expect(two.linearity, isNotNull);
  });

  test('telemetria de tanque usa nível, temperatura e erro absoluto', () async {
    expect(
      const TelemetryTake(standard: 5196, instrument: 5195.8).error,
      closeTo(0.2, 0.0001),
    );
    expect(
      const TelemetryTake(standard: 24, instrument: 23.9).error,
      closeTo(0.1, 0.0001),
    );

    final job = newCalibrationJob(
      kind: CalibrationKind.telemetry,
      technicianName: 'Cleber Guimarães',
    );
    expect(job.isTelemetry, isTrue);
    expect(job.equipmentType, telemetryEquipmentTypeDefault);
    expect(job.procedure, contains('ABTL'));
    expect(job.telemetryChannels, hasLength(2));
    expect(job.telemetryChannels.first.key, 'level');
    expect(job.telemetryChannels.first.found, hasLength(3));
    expect(job.telemetryChannels.last.key, 'temperature');
    expect(job.standards, hasLength(2));

    final filled = job.copyWith(
      number: 'GS-TEL-2026-0001',
      clientName: 'ROYAL FIC',
      clientAddress: 'Paulínia/SP',
      equipmentTag: 'TQ-07',
      model: 'PROSERVO NMS80-36H4/0',
      concentrator: 'DISPLACER NC025C1311A',
      deviceId: 'P10003C1311A',
      tankType: 'Tanque tipo domo de teto fixo',
      fieldTechnicianName: 'Rafael Medeiros',
      telemetryChannels: [
        job.telemetryChannels.first.copyWith(
          found: const [
            TelemetryTake(standard: 1347, instrument: 1347.3),
            TelemetryTake(standard: 1347, instrument: 1347.3),
            TelemetryTake(standard: 1347, instrument: 1347),
          ],
          left: const [
            TelemetryTake(standard: 516, instrument: 515.9),
            TelemetryTake(standard: 516, instrument: 515.9),
            TelemetryTake(standard: 516, instrument: 515.9),
          ],
        ),
        job.telemetryChannels.last.copyWith(
          found: const [TelemetryTake(standard: 26, instrument: 26.1)],
          left: const [TelemetryTake(standard: 28, instrument: 27.8)],
        ),
      ],
      standards: const [
        CalibrationStandard(
          id: 'tape',
          description: 'Trena de Profundidade',
          manufacturer: 'STARRETT',
          model: '20.000mm',
          serialNumber: '23/0834',
          tag: '23/0834',
          certificate: '12643/25',
          executant: 'GABRIEL MOREIRA',
          calibrationDate: '08/08/2025',
        ),
        CalibrationStandard(
          id: 'thermo',
          description: 'Termômetro de Líquido em Vidro',
          manufacturer: 'RIVATERM',
          model: '0,05°C',
          serialNumber: '3373/2025',
          tag: '3373/2025',
          certificate: '12711/25',
          executant: 'JULIANO MESSIAS LAZARETTI',
          calibrationDate: '12/08/2025',
        ),
      ],
    );
    expect(
      filled.telemetryChannels.first.meanError(found: true),
      closeTo(0.2, 0.05),
    );
    expect(filled.filledTelemetryChannels, hasLength(2));
    expect(CalibrationJob.fromJson(filled.toJson()).deviceId, 'P10003C1311A');

    final bytes = await buildCalibrationCertificate(filled);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(8000));
  });
}
