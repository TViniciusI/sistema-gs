import 'package:flutter/material.dart';
import 'package:gs_mobile/data/calibration_qr_link.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/office_store.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_page.dart';
import 'package:gs_mobile/features/control/control_page.dart';
import 'package:gs_mobile/features/home/work_area_page.dart';
import 'package:gs_mobile/features/settings/settings_page.dart';
import 'package:gs_mobile/features/tabelas/tabelas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _index = 0;
  var _qrLinkHandled = false;

  @override
  void initState() {
    super.initState();
    final user = AuthSession.instance.user;
    final email = user?.email;
    OfficeStore.instance.load();
    // Login já fez snapshot; não re-sincronizar tudo ao montar as abas.
    if (email == null) return;
    FieldStore.instance.applyViewerAccess(seeAll: user?.seesAllFieldOs == true);
    if (CloudSyncGate.isFresh || CloudSyncGate.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openQrIfAny());
      return;
    }
    FieldStore.instance.load(
      email,
      seeAll: user?.seesAllFieldOs == true,
      login: user?.login ?? '',
      aliases: user?.aliases ?? const [],
    );
    ClientStore.instance.load();
    CalibrationStore.instance.load();
    CalibrationCatalog.instance.load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openQrIfAny());
  }

  Future<void> _openQrIfAny() async {
    if (_qrLinkHandled || !mounted) return;
    _qrLinkHandled = true;
    await consumeCalibrationQrDeepLink(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final pages = <Widget>[const WorkAreaPage()];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Início',
      ),
    ];
    if (user?.canSeeCalibration == true) {
      pages.add(const CalibrationPage());
      destinations.add(
        const NavigationDestination(
          key: Key('tab-calibracao'),
          icon: Icon(Icons.precision_manufacturing_outlined),
          selectedIcon: Icon(Icons.precision_manufacturing),
          label: 'Calibração',
        ),
      );
    }
    if (user?.canSeeTables == true) {
      pages.add(const TabelasPage());
      destinations.add(
        const NavigationDestination(
          key: Key('tab-tabelas'),
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: 'Tabelas',
        ),
      );
    }
    pages.add(const SettingsPage());
    destinations.add(
      const NavigationDestination(
        key: Key('tab-config'),
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Configurações',
      ),
    );
    if (user?.isDevAccount == true) {
      pages.add(const ControlPage());
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield),
          label: 'Controle',
        ),
      );
    }

    if (destinations.length == 1) {
      return pages.first;
    }

    final index = _index.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
