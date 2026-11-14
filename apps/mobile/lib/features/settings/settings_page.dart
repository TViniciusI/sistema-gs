import 'package:flutter/material.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gs_mobile/web/app_reload.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/app_reload_web.dart';
import 'package:gs_mobile/web/pwa_install.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/pwa_install_web.dart';
import 'package:gs_mobile/web/pwa_install_banner.dart';

/// Conta do Drive do escritório (não o Gmail de quem implantou o Apps Script).
const officeDriveAccount = 'administrativo@gssolucoestec.com.br';

/// Rótulo mostrado em Configurações: ignora Gmail pessoal do implantador.
String officeDriveAccountLabel(String? accountFromScript) {
  final raw = (accountFromScript ?? '').trim().toLowerCase();
  if (raw.isEmpty || raw == officeDriveAccount) return officeDriveAccount;
  if (raw.contains('vinicius') || raw.endsWith('@gmail.com')) {
    return officeDriveAccount;
  }
  return raw;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _profilePassword = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _profileBusy = false;
  var _passwordBusy = false;
  var _driveBusy = false;
  AccountResult? _drive;
  String? _profileMessage;
  String? _passwordMessage;
  var _profileOk = false;
  var _passwordOk = false;

  @override
  void initState() {
    super.initState();
    _fillFromSession();
    _loadDrive();
  }

  void _fillFromSession() {
    final user = AuthSession.instance.user;
    if (user == null) return;
    _name.text = user.name;
    _login.text = user.login;
    _email.text = user.email;
    _phone.text = user.phone;
  }

  Future<void> _loadDrive() async {
    if (AuthSession.instance.user?.canSeeOfficeDrive != true) return;
    setState(() => _driveBusy = true);
    final result = await AccountApi.instance.driveStatus();
    if (!mounted) return;
    setState(() {
      _drive = result;
      _driveBusy = false;
    });
  }

  Future<void> _openDriveFolder() async {
    final url = (_drive?.folderUrl ?? '').trim();
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String get _driveAccountLabel => officeDriveAccountLabel(_drive?.account);

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _email.dispose();
    _phone.dispose();
    _profilePassword.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_profileBusy) return;
    setState(() {
      _profileBusy = true;
      _profileMessage = null;
      _profileOk = false;
    });
    final error = await AuthSession.instance.updateProfile(
      name: _name.text,
      login: _login.text,
      email: _email.text,
      phone: _phone.text,
      currentPassword: _profilePassword.text,
    );
    if (!mounted) return;
    setState(() {
      _profileBusy = false;
      _profileOk = error == null;
      _profileMessage = error ?? 'Perfil atualizado neste aparelho.';
      if (error == null) {
        _profilePassword.clear();
        _fillFromSession();
      }
    });
  }

  Future<void> _savePassword() async {
    if (_passwordBusy) return;
    setState(() {
      _passwordBusy = true;
      _passwordMessage = null;
      _passwordOk = false;
    });
    final error = await AuthSession.instance.changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
      confirmPassword: _confirmPassword.text,
    );
    if (!mounted) return;
    setState(() {
      _passwordBusy = false;
      _passwordOk = error == null;
      _passwordMessage = error ?? 'Senha atualizada. Use a nova senha no próximo login.';
      if (error == null) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListenableBuilder(
        listenable: AuthSession.instance,
        builder: (context, _) {
          final session = AuthSession.instance;
          final user = session.user;
          return ListView(
            key: const Key('settings-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
          Text(
            user?.name ?? 'GS Campo',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              user?.role ?? '',
              if (user != null) '@${user.login}',
            ].where((item) => item.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajuste o nome, o usuário de entrada e a senha. A mudança vale neste aparelho e, quando a planilha estiver no ar, também no login da empresa.',
            style: TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 22),
          if (user?.canSeeOfficeDrive == true) ...[
            const _SectionTitle('Google Drive'),
            const SizedBox(height: 10),
            _Card(
              key: const Key('settings-drive'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _drive?.legacyScript == true
                        ? 'O script do Google publicado ainda é o antigo: os '
                              'arquivos continuam indo para o OneDrive. Cole o '
                              'login_gate.gs novo na conta dona da pasta do Google '
                              'Drive e publique uma Nova versão.'
                        : _drive?.connected == true
                        ? (_drive?.wrongOwner == true
                              ? 'RDO, fotos, anexos e certificados deveriam ir para '
                                    '$_driveAccountLabel, mas o script ainda grava '
                                    'com outra conta — o espaço do administrativo@ '
                                    'não conta até republicar.'
                              : 'RDO, fotos, anexos e certificados vão para a pasta das OS no Google Drive · $_driveAccountLabel.')
                        : _driveBusy
                        ? 'Conferindo a pasta das OS no Google Drive…'
                        : 'A pasta das OS no Google Drive não respondeu.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                  if (_drive?.connected == true &&
                      _drive?.wrongOwner == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      (_drive!.warning ?? '').trim().isNotEmpty
                          ? _drive!.warning!
                          : 'O dono do Drive/Apps Script ainda não é '
                                '$_driveAccountLabel. Transfira pasta e script '
                                'para essa conta (dono único).',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF8B3A3A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((_drive?.error ?? '').isNotEmpty &&
                      _drive?.connected != true) ...[
                    const SizedBox(height: 8),
                    Text(
                      _drive!.error!,
                      style: const TextStyle(color: Color(0xFF8B3A3A)),
                    ),
                    if (_drive!.error!.contains('falar com a planilha')) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Isso é falha na implantação do Apps Script (URL fora '
                        'do ar), não apaga certificados. No Google Apps Script: '
                        'rode bindGsCampoSheet, depois Implantar → lápis → '
                        'Nova versão na MESMA URL.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  if (_drive?.connected == true &&
                      _drive?.legacyScript != true)
                    FilledButton.icon(
                      key: const Key('settings-drive-open'),
                      onPressed: _openDriveFolder,
                      icon: const Icon(Icons.folder_open_outlined),
                      style:
                          FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                      label: const Text('Abrir pasta das OS'),
                    )
                  else
                    OutlinedButton.icon(
                      key: const Key('settings-drive-retry'),
                      onPressed: _driveBusy ? null : _loadDrive,
                      icon: const Icon(Icons.refresh),
                      label: Text(_driveBusy ? 'Aguarde…' : 'Conferir de novo'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          const _SectionTitle('Conta'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('settings-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Como o app deve te chamar',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-login'),
                  controller: _login,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuário',
                    hintText: 'Login de entrada',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-profile-password'),
                  controller: _profilePassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha atual',
                    hintText: 'Confirma a troca de usuário',
                  ),
                ),
                if (_profileMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _profileMessage!,
                    style: TextStyle(
                      color: _profileOk
                          ? const Color(0xFF1F6B3A)
                          : const Color(0xFF8B2E2E),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  key: const Key('settings-save-profile'),
                  onPressed: _profileBusy ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_profileBusy ? 'Salvando…' : 'Salvar conta'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Senha'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Quem quiser trocar a senha faz aqui. A senha atual confirma que é você.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF5C6570),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('settings-current-password'),
                  controller: _currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha atual',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-new-password'),
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha nova',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('settings-confirm-password'),
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Repetir senha nova',
                  ),
                ),
                if (_passwordMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _passwordMessage!,
                    style: TextStyle(
                      color: _passwordOk
                          ? const Color(0xFF1F6B3A)
                          : const Color(0xFF8B2E2E),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  key: const Key('settings-save-password'),
                  onPressed: _passwordBusy ? null : _savePassword,
                  child: Text(_passwordBusy ? 'Salvando…' : 'Trocar senha'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Aparência'),
          const SizedBox(height: 10),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Saudação com nome completo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              subtitle: Text(
                session.greetWithFullName
                    ? 'O início mostra ${user?.name ?? 'o nome inteiro'}.'
                    : 'O início mostra só o primeiro nome.',
              ),
              value: session.greetWithFullName,
              onChanged: (value) => session.setGreetWithFullName(value),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Aplicativo'),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GS Campo $appVersion',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: GsTheme.navy),
                      tooltip: 'Recarregar / Atualizar app (limpar cache)',
                      onPressed: () => AppReload.hardReload(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'GS Soluções · acesso de campo e escritório.',
                  style: TextStyle(color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => AppReload.hardReload(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recarregar e atualizar app'),
                ),
                if (PwaInstall.shouldOffer) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showPwaInstallHelp(context),
                    icon: const Icon(Icons.install_mobile_outlined),
                    label: const Text('Instalar no celular'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => AuthSession.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: GsTheme.navy,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: GsTheme.brass, width: 5),
          top: BorderSide(color: Color(0x331A2330)),
          right: BorderSide(color: Color(0x331A2330)),
          bottom: BorderSide(color: Color(0x331A2330)),
        ),
      ),
      child: child,
    );
  }
}
