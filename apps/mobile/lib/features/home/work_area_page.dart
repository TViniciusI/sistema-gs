import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/agenda/week_agenda_panel.dart';
import 'package:gs_mobile/features/clients/catalog_review_page.dart';
import 'package:gs_mobile/features/clients/clients_page.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/features/home/technician_area_page.dart';
import 'package:gs_mobile/features/os/office_os_page.dart';
import 'package:gs_mobile/features/os/os_search_page.dart';
import 'package:gs_mobile/features/staff/staff_docs_page.dart';
import 'package:gs_mobile/features/staff/staff_page.dart';
import 'package:gs_mobile/web/app_reload.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/app_reload_web.dart';
import 'package:gs_mobile/web/pwa_install.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/pwa_install_web.dart';
import 'package:gs_mobile/web/pwa_install_banner.dart';

class WorkAreaPage extends StatelessWidget {
  const WorkAreaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    final greetName = AuthSession.instance.greetingName;

    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        bottom: const _SyncBar(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/gs_mark_gold.png',
              height: 26,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 10),
            const Text('GS Campo'),
            const SizedBox(width: 8),
            Text(
              appVersion,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GsTheme.brassLight,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Recarregar / Atualizar app (limpa cache)',
              onPressed: () => AppReload.hardReload(),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'instalar') {
                showPwaInstallHelp(context);
                return;
              }
              if (value == 'sair') AuthSession.instance.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(user?.name ?? 'GS')),
              if (PwaInstall.shouldOffer)
                const PopupMenuItem(
                  value: 'instalar',
                  child: Text('Instalar no celular'),
                ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: ListView(
        key: const Key('home-list'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _WelcomeBanner(
            greeting: 'Olá, $greetName',
            subtitle: user?.hasFullAccess == true
                ? user?.isTechnician == true
                      ? 'Técnico e administrativo. Clientes, OS, RDO e anexos são da empresa.'
                      : 'Acesso principal. Acompanhe OS, RDO, certificados e anexos.'
                : 'Clientes e OS são da empresa; o técnico vê a agenda dele.',
          ),
          const SizedBox(height: 14),
          WeekAgendaPanel(
            key: const Key('week-agenda'),
            onlyMine: user?.homeAgendaOnlyMine ?? true,
          ),
          const SizedBox(height: 12),
          if (user?.canManageStaff == true) ...[
            _AreaCard(
              key: const Key('open-staff'),
              icon: Icons.groups_outlined,
              title: 'Funcionários',
              subtitle: 'Equipe RH: contato, setor, cargo, situação e horas.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StaffPage()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (user?.canManageClients == true) ...[
            AnimatedBuilder(
              animation: FieldStore.instance,
              builder: (context, _) {
                final pending = canReviewCatalogSubmissions(user)
                    ? FieldStore.instance.pendingCatalogSubmissions().length
                    : 0;
                if (pending <= 0) return const SizedBox.shrink();
                return Column(
                  children: [
                    _AreaCard(
                      key: const Key('open-catalog-review'),
                      icon: Icons.notification_important_outlined,
                      title: 'Alerta · cadastro ($pending)',
                      subtitle:
                          'Técnico enviou instrumento(s) para você conferir e aprovar.',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CatalogReviewPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            _AreaCard(
              key: const Key('open-clientes'),
              icon: Icons.apartment_outlined,
              title: 'Clientes',
              subtitle: 'Cadastro da empresa compartilhado entre funcionários.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ClientsPage()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (user?.canGenerateOs == true) ...[
            _AreaCard(
              key: const Key('open-gerar-os'),
              icon: Icons.post_add_outlined,
              title: 'Gerar OS',
              subtitle: 'OS na planilha da empresa; escritório acompanha tudo.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const OfficeOsPage()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (user?.canFinalizeAndReopenOs == true) ...[
            _AreaCard(
              key: const Key('open-pesquisar-os'),
              icon: Icons.manage_search_outlined,
              title: 'Pesquisar / reativar OS',
              subtitle: 'Busca, reativa e encerra OS finalizadas.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const OsSearchPage()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (user?.canWorkField == true) ...[
            _AreaCard(
              key: const Key('open-tecnico'),
              icon: Icons.engineering_outlined,
              title: 'Área do técnico',
              subtitle: user?.seesAllFieldOs == true
                  ? 'OS da empresa: RDO, datas no adesivo e etiquetas.'
                  : 'Agenda das OS delegadas e RDO de campo.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TechnicianAreaPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (user?.canSeeDocs == true) ...[
            _AreaCard(
              key: const Key('open-meus-documentos'),
              icon: Icons.draw_outlined,
              title: 'Meus documentos',
              subtitle:
                  'Holerite e anexos do RH. Assinatura quando pedirem; também por e-mail.',
              onTap: () {
                final current = AuthSession.instance.user;
                if (current == null) return;
                final email = current.email.trim().toLowerCase();
                RemoteAccount? remote;
                for (final item in StaffStore.instance.directory) {
                  if (item.email.trim().toLowerCase() == email) {
                    remote = item;
                    break;
                  }
                }
                remote ??= RemoteAccount(
                  email: current.email,
                  login: current.login,
                  name: current.name,
                  phone: current.phone,
                  role: current.role,
                  status: 'aprovado',
                  active: true,
                  cargo: current.cargo,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StaffDocsPage(user: remote!, allowAttach: false),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GsTheme.radius),
        boxShadow: GsTheme.softShadow,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GsTheme.radius),
          side: const BorderSide(color: Color(0x140C1F33)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: GsTheme.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: GsTheme.brassLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: GsTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0x1FC59E39),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: GsTheme.brass,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.greeting, required this.subtitle});

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: GsTheme.brandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330C1F33),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -6,
            bottom: -6,
            child: Opacity(
              opacity: 0.16,
              child: Image.asset(
                'assets/brand/gs_mark_gold.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: GsTheme.goldGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: GsTheme.paper,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 70),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xCCF4F0E6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa dourada fina enquanto a planilha sincroniza em segundo plano.
class _SyncBar extends StatelessWidget implements PreferredSizeWidget {
  const _SyncBar();

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CloudSyncGate.syncing,
      builder: (context, syncing, _) => SizedBox(
        height: 2,
        child: syncing
            ? const LinearProgressIndicator(
                minHeight: 2,
                color: GsTheme.brassLight,
                backgroundColor: Colors.transparent,
              )
            : null,
      ),
    );
  }
}
