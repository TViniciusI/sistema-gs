import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/access_gate.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/auth/signup_page.dart';
import 'package:gs_mobile/web/app_reload.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/app_reload_web.dart';
import 'package:gs_mobile/web/pwa_install_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    await AccessGate.instance.refresh();
    final matched = matchUser(_login.text);
    if (matched != null &&
        matched.isClient &&
        AccessGate.instance.cleberBlocked) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Acesso indisponível agora. Fale com o escritório.';
      });
      return;
    }

    final error = await AuthSession.instance.signIn(
      _login.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.navy,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 1.1,
            colors: [GsTheme.navyLight, GsTheme.navy, GsTheme.navyDeep],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const _BrandHero(),
                      const SizedBox(height: 26),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _LoginCard(
                          login: _login,
                          password: _password,
                          busy: _busy,
                          showPassword: _showPassword,
                          error: _error,
                          onTogglePassword: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                          onSubmit: _submit,
                          onSignup: _busy ? null : _openSignup,
                        ),
                      ),
                      const PwaInstallBanner(),
                      const Spacer(flex: 3),
                      Text(
                        'GS Soluções · $appVersionLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          color: Color(0x66F4F0E6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Desenvolvido por Vinicius Magalhães',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0x44F4F0E6)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/brand/gs_logo_gold.png',
            height: 118,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 16),
          const Text(
            'GS CAMPO',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              color: GsTheme.paper,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            shape: const StadiumBorder(
              side: BorderSide(color: Color(0x73C59E39)),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => AppReload.hardReload(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'versão $appVersionLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: GsTheme.brassLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: 'Recarregar app (limpa cache e atualiza)',
                      child: Icon(
                        Icons.refresh,
                        size: 15,
                        color: GsTheme.brassLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.login,
    required this.password,
    required this.busy,
    required this.showPassword,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSignup,
  });

  final TextEditingController login;
  final TextEditingController password;
  final bool busy;
  final bool showPassword;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback? onSignup;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(gradient: GsTheme.goldGradient),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Entre para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use o usuário e a senha da GS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: GsTheme.muted),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('login-user'),
                  controller: login,
                  style: const TextStyle(fontSize: 17),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Usuário',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login-password'),
                  controller: password,
                  obscureText: !showPassword,
                  style: const TextStyle(fontSize: 17),
                  textInputAction: TextInputAction.go,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: showPassword ? 'Ocultar senha' : 'Mostrar senha',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8B2E2E),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('login-submit'),
                  onPressed: busy ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: GsTheme.navy,
                  ),
                  child: busy
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: GsTheme.navy,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Entrando…'),
                          ],
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('open-signup'),
                  onPressed: onSignup,
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
