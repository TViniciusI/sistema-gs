import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gs_mobile/auth/access_gate.dart';
import 'package:gs_mobile/core/keyboard_page_scroll.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/auth/login_page.dart';
import 'package:gs_mobile/features/home/home_page.dart';
import 'package:gs_mobile/web/app_reload.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/app_reload_web.dart';
import 'package:gs_mobile/web/app_update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccessGate.instance.load();
  await AuthSession.instance.restore();
  if (AuthSession.instance.user?.isClient == true &&
      AccessGate.instance.cleberBlocked) {
    await AuthSession.instance.signOut();
  }
  runApp(const GsApp());
}

class GsApp extends StatefulWidget {
  const GsApp({super.key});

  @override
  State<GsApp> createState() => _GsAppState();
}

class _GsAppState extends State<GsApp> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();
  Timer? _syncTimer;
  var _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Aba/app aberto por dias não pode ficar com certificados de ontem.
    _syncTimer = Timer.periodic(const Duration(minutes: 4), (_) {
      if (_visible) {
        AuthSession.instance.backgroundSync();
        AppUpdate.instance.check();
      }
    });
    AppUpdate.instance.check();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      AccessGate.instance.refresh();
      AuthSession.instance.backgroundSync();
      AppUpdate.instance.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'GS Campo',
      debugShowCheckedModeBanner: false,
      theme: GsTheme.data,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const GsScrollBehavior(),
      builder: (context, child) {
        final shell = _WebShell(child: _UpdateBanner(child: child));
        if (!keyboardPageScrollEnabled) return shell;
        return KeyboardPageScroll(child: shell);
      },
      home: ListenableBuilder(
        listenable: Listenable.merge([
          AuthSession.instance,
          AccessGate.instance,
        ]),
        builder: (context, _) {
          final user = AuthSession.instance.user;
          if (user != null &&
              user.isClient &&
              AccessGate.instance.cleberBlocked) {
            return const LoginPage();
          }
          if (AuthSession.instance.isSignedIn) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class GsScrollBehavior extends MaterialScrollBehavior {
  const GsScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    return ListenableBuilder(
      listenable: AppUpdate.instance,
      builder: (context, _) {
        final update = AppUpdate.instance;
        if (!update.available) return content;
        return Column(
          children: [
            Material(
              key: const Key('app-update-banner'),
              color: GsTheme.brass,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_alt, color: Colors.black),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nova versão ${update.newVersion} disponível. '
                          'Atualize para ver os dados certos.',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton(
                        key: const Key('app-update-agora'),
                        onPressed: AppReload.hardReload,
                        style: FilledButton.styleFrom(
                          // O tema estica o botão na largura toda; na faixa
                          // isso esmagava o texto numa coluna de letras.
                          minimumSize: const Size(0, 40),
                          backgroundColor: GsTheme.navy,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Atualizar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WebShell extends StatelessWidget {
  const _WebShell({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    if (!kIsWeb) return content;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) return content;
        return ColoredBox(
          color: const Color(0xFF08141F),
          child: Center(
            child: SizedBox(
              width: 720,
              height: constraints.maxHeight,
              child: ColoredBox(color: GsTheme.paper, child: content),
            ),
          ),
        );
      },
    );
  }
}
