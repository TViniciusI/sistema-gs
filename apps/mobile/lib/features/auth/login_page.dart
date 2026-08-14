import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'felipe@gssolucoestec.com.br');
  final _password = TextEditingController(text: 'demonstracao');
  var _obscure = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = AuthSession.instance.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0x331A2330)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140C1F33),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 3,
                              color: GsTheme.brass,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Image.asset(
                            'assets/logo.png',
                            height: 86,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ACESSO AO APP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w600,
                              color: GsTheme.brass,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Entrar no campo GS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: GsTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Agenda, OS, registros do dia, fotos e anexo do certificado em Excel — mesmo sem sinal na planta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xB30C1F33),
                              height: 1.45,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _FieldLabel('Usuário'),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(),
                          ),
                          const SizedBox(height: 14),
                          const _FieldLabel('Senha'),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: _inputDecoration().copyWith(
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: GsTheme.navy,
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF8B2E2E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: GsTheme.brass,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: const Color(0x55C59E39),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              _busy ? 'Entrando…' : 'Entrar na demonstração',
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: Color(0x331A2330)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                color: GsTheme.navy,
                                child: const Text(
                                  'F',
                                  style: TextStyle(
                                    color: GsTheme.brass,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Felipe Souza\nTécnico · sessão demo',
                                  style: TextStyle(
                                    height: 1.35,
                                    fontSize: 13,
                                    color: GsTheme.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'DESENVOLVIDO POR VINICIUS MAGALHÃES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Color(0x660C1F33),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: Color(0x66F4F0E6),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0x331A2330)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0x331A2330)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: GsTheme.brass),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5C6570),
        ),
      ),
    );
  }
}
