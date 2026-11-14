import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:gs_mobile/core/theme.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  var _role = 'tecnico';
  var _busy = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    if (_login.text.trim().isEmpty ||
        _password.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Preencha usuário, senha, telefone e e-mail.';
      });
      return;
    }
    final reserved = reservedSignupError(
      email: _email.text,
      login: _login.text,
    );
    if (reserved != null) {
      setState(() {
        _busy = false;
        _error = reserved;
      });
      return;
    }
    final result = await AccountApi.instance.signup(
      name: _name.text.trim().isEmpty ? _login.text.trim() : _name.text.trim(),
      login: _login.text,
      password: _password.text,
      phone: _phone.text,
      email: _email.text,
      role: _role,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _ok =
            result.message ??
            'Pedido enviado. Aguarde a liberação do acesso.';
      } else {
        _error = result.error ?? 'Não foi possível criar a conta.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Text(
            'Preencha seus dados. O acesso libera depois da confirmação do escritório.',
            style: TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('signup-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('signup-login'),
            controller: _login,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Usuário (login)'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('signup-password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('signup-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('signup-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              helperText:
                  'E-mail da pessoa que vai usar o app. Não use o do Cleber nem o da GS Soluções.',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Setor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Administrativo gera OS. Técnico vê a agenda e lança o RDO.',
            style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: _role,
            onChanged: (value) => setState(() => _role = value ?? 'tecnico'),
            child: Column(
              children: const [
                RadioListTile<String>(
                  key: Key('signup-role-admin'),
                  value: 'admin',
                  title: Text('Administrativo'),
                ),
                RadioListTile<String>(
                  key: Key('signup-role-tecnico'),
                  value: 'tecnico',
                  title: Text('Técnico'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF8B2E2E), fontSize: 16),
            ),
          ],
          if (_ok != null) ...[
            const SizedBox(height: 12),
            Text(
              _ok!,
              style: const TextStyle(color: GsTheme.navy, fontSize: 16),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('signup-submit'),
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: GsTheme.brass,
              foregroundColor: Colors.black,
            ),
            child: Text(_busy ? 'Enviando…' : 'Criar conta'),
          ),
          const SizedBox(height: 24),
          Text(
            'GS Campo $appVersionLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: Color(0xFF8A9098),
            ),
          ),
        ],
      ),
    );
  }
}
