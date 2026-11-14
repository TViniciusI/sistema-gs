import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/search_pick_sheet.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_bundle_pdf.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/certificate_sign_dialog.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_badges.dart';
import 'package:gs_mobile/features/calibration/calibration_delete.dart';
import 'package:gs_mobile/features/calibration/calibration_fluids_page.dart';
import 'package:gs_mobile/features/calibration/calibration_job_page.dart';
import 'package:gs_mobile/features/calibration/calibration_standards_page.dart';
import 'package:gs_mobile/features/clients/client_edit_page.dart';
import 'package:gs_mobile/features/clients/catalog_review_page.dart';
import 'package:gs_mobile/features/os/certificate_book_pick_dialog.dart';
import 'package:intl/intl.dart';

enum _JobFilter { all, inProgress, pendingReview, draft, done }

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  var _busy = false;
  var _filter = _JobFilter.all;

  @override
  void initState() {
    super.initState();
    final user = AuthSession.instance.user;
    if (user != null) {
      FieldStore.instance.applyViewerAccess(seeAll: user.seesAllFieldOs);
    }
    // Dados já vieram no login; sync manual fica nos botões da tela.
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _openNew(CalibrationKind kind) async {
    final user = AuthSession.instance.user;
    var job = newCalibrationJob(kind: kind, technicianName: user?.name ?? '');
    job = await CalibrationStore.instance.save(job);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationJobPage(jobId: job.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCatalog(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<bool> _deleteJob(CalibrationJob job) =>
      confirmDeleteCalibration(context, job);

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final sync = await ClientStore.instance.sync();
      if (!mounted) return;
      if (!sync.ok) {
        _toast(
          sync.error ??
              'Não sincronizou com a nuvem. A planilha pode ficar incompleta.',
        );
      }
      final clients = ClientStore.instance.items;
      final instruments = [
        for (final client in clients) ...client.equipment,
      ].length;
      final bytes = buildClientExcelTemplate(
        clients: clients,
        withExample: clients.isEmpty,
      );
      await downloadRdoFile(fileName: clientExcelFileName, bytes: bytes);
      if (!mounted) return;
      _toast(
        clients.isEmpty
            ? 'Planilha modelo baixada (nenhum cliente na nuvem ainda).'
            : 'Planilha: $instruments instrumento(s) · '
                  '${clients.length} cliente(s) local'
                  '${sync.ok ? ' · ${sync.remoteCount} na nuvem' : ' · sync falhou'}.',
      );
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSheet() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast('Não deu para ler a planilha.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ClientStore.instance.sync();
      final result = await importClientWorkbook(bytes);
      await ClientStore.instance.sync();
      if (mounted) _toast(result.message);
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAlerts() async {
    await FieldStore.instance.sync();
    if (!mounted) return;
    final alerts = CalibrationCatalog.instance.alerts;
    final catalogPending = FieldStore.instance.pendingCatalogSubmissions();
    final user = AuthSession.instance.user;
    final canReview = canReviewCatalogSubmissions(user);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notificações'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canReview) ...[
                  const Text(
                    'Cadastro · técnico enviou para conferência',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GsTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (catalogPending.isEmpty)
                    const Text(
                      'Nenhum instrumento aguardando aprovação.',
                      style: TextStyle(color: Color(0xFF5C6570)),
                    )
                  else ...[
                    Text(
                      '${catalogPending.length} envio(s) precisando de conferência.',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in catalogPending.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'OS ${item.os.number} · ${item.slot.certificateNumber}'
                          '${item.slot.catalogSubmittedBy.trim().isEmpty ? '' : ' · ${item.slot.catalogSubmittedBy}'}',
                          style: const TextStyle(
                            color: Color(0xFF5C6570),
                            height: 1.3,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showCatalogReviewAlerts(this.context);
                      },
                      child: const Text('Abrir conferência de cadastro'),
                    ),
                  ],
                  const Divider(height: 28),
                ],
                const Text(
                  'Padrões vencidos ou a vencer em até 30 dias',
                  style: TextStyle(color: Color(0xFF5C6570), height: 1.35),
                ),
                const SizedBox(height: 12),
                if (alerts.isEmpty)
                  const Text(
                    'Nenhum padrão vencido ou a vencer nos próximos 30 dias.',
                  )
                else
                  for (final alert in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.standard.name.trim().isEmpty
                                      ? 'Padrão'
                                      : alert.standard.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: GsTheme.navy,
                                  ),
                                ),
                                Text(
                                  alert.message,
                                  style: const TextStyle(
                                    color: Color(0xFF5C6570),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          validityPill(alert.standard.validityStatus),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openCatalog(const CalibrationStandardsPage());
            },
            child: const Text('Ver padrões de vazão'),
          ),
        ],
      ),
    );
  }

  List<CalibrationJob> _applyFilter(List<CalibrationJob> jobs) {
    switch (_filter) {
      case _JobFilter.all:
        return jobs;
      case _JobFilter.inProgress:
        return [
          for (final job in jobs)
            if (job.status == CalibrationJobStatus.inProgress) job,
        ];
      case _JobFilter.pendingReview:
        return [
          for (final job in jobs)
            if (job.status == CalibrationJobStatus.pendingReview) job,
        ];
      case _JobFilter.draft:
        return [
          for (final job in jobs)
            if (job.status == CalibrationJobStatus.draft) job,
        ];
      case _JobFilter.done:
        return [
          for (final job in jobs)
            if (job.status == CalibrationJobStatus.done) job,
        ];
    }
  }

  DateTime _jobDate(CalibrationJob job) => job.updatedAt ?? job.createdAt;

  String _jobSubtitle(CalibrationJob job) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(_jobDate(job));
    return '${job.subtitle}\n$date · ${job.statusLabel}';
  }

  Future<void> _openSavedJobs(List<CalibrationJob> jobs) async {
    if (jobs.isEmpty) {
      _toast('Nenhuma calibração neste filtro.');
      return;
    }
    final picked = await showSearchPickSheet<CalibrationJob>(
      context: context,
      title: 'Calibrações (mais recente primeiro)',
      items: jobs,
      pageSize: 8,
      emptyMessage: 'Nenhuma calibração encontrada.',
      labelOf: (job) => job.title,
      subtitleOf: _jobSubtitle,
      searchOf: (job) =>
          '${job.title} ${job.subtitle} ${job.clientName} ${job.equipmentTag} ${job.systemTag}',
      trailingOf: (sheetContext, job) {
        final isRemote = CalibrationStore.instance.isRemote(job.id);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isRemote
                  ? 'Salvo na nuvem (toque para atualizar ou cópia)'
                  : 'Salvar na nuvem',
              icon: Icon(
                isRemote ? Icons.cloud_done : Icons.cloud_upload_outlined,
                color: isRemote ? const Color(0xFF2E7D32) : GsTheme.navy,
                size: 20,
              ),
              onPressed: () async {
                await _saveJobToCloudWithDialog(job);
                if (sheetContext.mounted) {
                  (sheetContext as Element).markNeedsBuild();
                }
              },
            ),
            IconButton(
              key: Key('calibracao-excluir-${job.id}'),
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFF8A1F1F),
              onPressed: () async {
                final deleted = await _deleteJob(job);
                if (!deleted) return;
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) setState(() {});
              },
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationJobPage(jobId: picked.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _saveJobToCloudWithDialog(CalibrationJob job) async {
    final isRemote = CalibrationStore.instance.isRemote(job.id);
    if (isRemote) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: GsTheme.paper,
          title: const Text(
            'Certificado já na nuvem',
            style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
          ),
          content: Text(
            'O certificado ${job.number} (${job.clientName}) já foi salvo na nuvem.\n\n'
            'Deseja sobrescrever na nuvem ou salvar como uma nova cópia?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, 'copy'),
              child: const Text('Salvar como cópia'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, 'overwrite'),
              style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
              child: const Text('Sobrescrever'),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel' || !mounted) return;

      if (action == 'copy') {
        final copy = CalibrationStore.instance.createCopy(job);
        final savedCopy = await CalibrationStore.instance.save(copy);
        final res = await CalibrationStore.instance.pushRemoteJob(savedCopy);
        if (mounted) {
          _toast(
            res.ok
                ? 'Cópia ${savedCopy.number} criada e salva na nuvem!'
                : 'Erro ao salvar cópia: ${res.error}',
          );
          setState(() {});
        }
      } else if (action == 'overwrite') {
        final res = await CalibrationStore.instance.pushRemoteJob(job);
        if (mounted) {
          _toast(
            res.ok
                ? 'Certificado ${job.number} atualizado na nuvem!'
                : 'Erro ao sobrescrever: ${res.error}',
          );
          setState(() {});
        }
      }
    } else {
      final res = await CalibrationStore.instance.pushRemoteJob(job);
      if (mounted) {
        _toast(
          res.ok
              ? 'Certificado ${job.number} salvo na nuvem com sucesso!'
              : 'Erro ao salvar: ${res.error}',
        );
        setState(() {});
      }
    }
  }

  Future<void> _openCloudManager() async {
    final all = CalibrationStore.instance.items;
    if (all.isEmpty) {
      _toast('Nenhum certificado cadastrado para salvar na nuvem.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CloudCalibrationsSheet(onToast: _toast),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openNewClient() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClientEditPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openClientsBar() async {
    setState(() => _busy = true);
    try {
      await ClientStore.instance.sync();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    final clients = ClientStore.instance.items;
    if (clients.isEmpty) {
      _toast('Nenhum cliente cadastrado ainda. Toque em Novo cliente.');
      return;
    }
    final picked = await showSearchPickSheet<SavedClient>(
      context: context,
      title: 'Clientes cadastrados',
      items: clients,
      pageSize: 10,
      emptyMessage: 'Nenhum cliente encontrado.',
      labelOf: (client) => client.name,
      subtitleOf: (client) =>
          '${client.equipment.length} instrumento(s)'
          '${client.cnpj.trim().isEmpty ? '' : ' · ${client.cnpj}'}',
      searchOf: (client) =>
          '${client.name} ${client.cnpj} ${client.city} ${[for (final eq in client.equipment) eq.tag].join(' ')}',
    );
    if (picked == null || !mounted) return;
    final full = await ClientStore.instance.ensureFull(picked.id) ?? picked;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ClientEditPage(existing: full)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: const Text('Calibração'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com a nuvem',
            icon: const Icon(Icons.sync),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final user = AuthSession.instance.user;
                      if (user != null) {
                        FieldStore.instance.applyViewerAccess(
                          seeAll: user.seesAllFieldOs,
                        );
                      }
                      await Future.wait([
                        CalibrationStore.instance.sync(),
                        CalibrationCatalog.instance.sync(),
                        ClientStore.instance.sync(),
                        FieldStore.instance.sync(),
                      ]);
                      if (mounted) _toast('Dados sincronizados com a nuvem!');
                    } catch (e) {
                      if (mounted) _toast('Erro ao sincronizar: $e');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
          AnimatedBuilder(
            animation: Listenable.merge([
              CalibrationCatalog.instance,
              FieldStore.instance,
            ]),
            builder: (context, _) {
              final standards = CalibrationCatalog.instance.alerts.length;
              final catalog =
                  canReviewCatalogSubmissions(AuthSession.instance.user)
                  ? FieldStore.instance.pendingCatalogSubmissions().length
                  : 0;
              final count = standards + catalog;
              return IconButton(
                key: const Key('calibracao-alertas'),
                tooltip: 'Notificações',
                onPressed: _openAlerts,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFC62828),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          CalibrationStore.instance,
          ClientStore.instance,
          CalibrationCatalog.instance,
        ]),
        builder: (context, _) {
          final all = CalibrationStore.instance.items;
          final inProgress = [
            for (final job in all)
              if (job.status == CalibrationJobStatus.inProgress) job,
          ];
          final pendingReview = [
            for (final job in all)
              if (job.status == CalibrationJobStatus.pendingReview) job,
          ];
          final drafts = [
            for (final job in all)
              if (job.status == CalibrationJobStatus.draft) job,
          ];
          final done = [
            for (final job in all)
              if (job.status == CalibrationJobStatus.done) job,
          ];
          final jobs = _applyFilter(all);
          final emptyBecauseFilter = all.isNotEmpty && jobs.isEmpty;
          final clientCount = ClientStore.instance.items.length;
          final instrumentCount = [
            for (final client in ClientStore.instance.items)
              ...client.equipment,
          ].length;
          final user = AuthSession.instance.user;
          final canManageCadastro = user?.canManageClientCadastro == true;
          final canExcel = user?.canUseClientExcel == true;
          return ListView(
            cacheExtent: 1200,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            children: [
              const Text(
                'Critérios do cliente antes de medir. Conferência só se a verificação estourar o erro.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                all.isEmpty
                    ? 'Nenhuma calibração ainda.'
                    : emptyBecauseFilter
                    ? 'Nenhuma neste filtro.'
                    : '${jobs.length} calibração(ões)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusFilterChip(
                    key: const Key('calibracao-filtro-todas'),
                    label: 'Todas (${all.length})',
                    selected: _filter == _JobFilter.all,
                    onTap: () => setState(() => _filter = _JobFilter.all),
                  ),
                  _StatusFilterChip(
                    key: const Key('calibracao-filtro-andamento'),
                    label: 'Andamento (${inProgress.length})',
                    selected: _filter == _JobFilter.inProgress,
                    onTap: () =>
                        setState(() => _filter = _JobFilter.inProgress),
                  ),
                  _StatusFilterChip(
                    key: const Key('calibracao-filtro-analise'),
                    label: 'Análise (${pendingReview.length})',
                    selected: _filter == _JobFilter.pendingReview,
                    onTap: () =>
                        setState(() => _filter = _JobFilter.pendingReview),
                  ),
                  _StatusFilterChip(
                    key: const Key('calibracao-filtro-rascunho'),
                    label: 'Rascunho (${drafts.length})',
                    selected: _filter == _JobFilter.draft,
                    onTap: () => setState(() => _filter = _JobFilter.draft),
                  ),
                  _StatusFilterChip(
                    key: const Key('calibracao-filtro-concluidas'),
                    label: 'Concluídas (${done.length})',
                    selected: _filter == _JobFilter.done,
                    onTap: () => setState(() => _filter = _JobFilter.done),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _OpenBar(
                key: const Key('calibracao-abrir-salvas'),
                icon: Icons.history_edu_outlined,
                label: jobs.isEmpty
                    ? 'Abrir calibração salva'
                    : 'Abrir calibração salva (${jobs.length})',
                hint: jobs.isEmpty
                    ? 'Nenhuma neste filtro'
                    : 'Mais recente em cima · páginas na lista',
                enabled: jobs.isNotEmpty,
                onTap: () => _openSavedJobs(jobs),
              ),
              const SizedBox(height: 12),
              _OpenBar(
                key: const Key('calibracao-nuvem-salvar'),
                icon: Icons.cloud_upload_outlined,
                label: 'Salvar certificados na nuvem',
                hint: 'Salvar individual, selecionar todos ou apenas novos',
                enabled: all.isNotEmpty && !_busy,
                onTap: _openCloudManager,
              ),
              const SizedBox(height: 12),
              const Text(
                'Os certificados de uma OS são gerados dentro da OS, em '
                'Gerar certificados da OS. O livro sai desses certificados salvos.',
                style: TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nova calibração',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _KindChip(
                    key: const Key('calibracao-nova-volumetrica'),
                    label: 'Volumétrica',
                    onTap: () => _openNew(CalibrationKind.volumetric),
                  ),
                  _KindChip(
                    key: const Key('calibracao-nova-volumetrica-invertida'),
                    label: 'Volumétrica invertida',
                    onTap: () => _openNew(CalibrationKind.volumetricInverted),
                  ),
                  _KindChip(
                    label: 'Malha de temperatura',
                    onTap: () => _openNew(CalibrationKind.temperatureMesh),
                  ),
                  _KindChip(
                    label: 'Temperatura',
                    onTap: () => _openNew(CalibrationKind.temperature),
                  ),
                  _KindChip(
                    label: 'Densidade',
                    onTap: () => _openNew(CalibrationKind.density),
                  ),
                  _KindChip(
                    label: 'Pressão',
                    onTap: () => _openNew(CalibrationKind.pressure),
                  ),
                  _KindChip(
                    key: const Key('calibracao-nova-condutividade'),
                    label: 'Condutividade',
                    onTap: () => _openNew(CalibrationKind.conductivity),
                  ),
                  _KindChip(
                    key: const Key('calibracao-nova-telemetria'),
                    label: 'Telemetria',
                    onTap: () => _openNew(CalibrationKind.telemetry),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ShortcutCard(
                      key: const Key('calibracao-atalho-padroes'),
                      icon: Icons.speed_outlined,
                      label: 'Padrões',
                      onTap: () =>
                          _openCatalog(const CalibrationStandardsPage()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ShortcutCard(
                      key: const Key('calibracao-atalho-fluidos'),
                      icon: Icons.water_drop_outlined,
                      label: 'Fluidos',
                      onTap: () => _openCatalog(const CalibrationFluidsPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (canManageCadastro) ...[
                const Text(
                  'Cadastro de instrumentos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cadastre o cliente, os sistemas e os instrumentos direto no '
                  'app. Os produtos saem da lista de Fluidos, com densidade e '
                  'viscosidade já preenchidas. Em campo o técnico confere/preenche '
                  'na OS, no número do certificado.',
                  style: TextStyle(
                    color: Color(0xFF5C6570),
                    height: 1.3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      key: const Key('calibracao-novo-cliente'),
                      onPressed: _busy ? null : _openNewClient,
                      style: FilledButton.styleFrom(
                        backgroundColor: GsTheme.brass,
                        foregroundColor: Colors.black,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_business_outlined, size: 18),
                      label: const Text('Novo cliente'),
                    ),
                    if (canExcel) ...[
                      OutlinedButton.icon(
                        key: const Key('calibracao-modelo'),
                        onPressed: _busy ? null : _downloadTemplate,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.table_view_outlined, size: 18),
                        label: const Text('Modelo Excel'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('calibracao-importar'),
                        onPressed: _busy ? null : _importSheet,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('Importar'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$clientCount cliente(s) · $instrumentCount instrumento(s)',
                  style: const TextStyle(
                    color: Color(0xFF5C6570),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                _OpenBar(
                  key: const Key('calibracao-abrir-clientes'),
                  icon: Icons.apartment_outlined,
                  label: clientCount == 0
                      ? 'Clientes cadastrados'
                      : 'Clientes cadastrados ($clientCount)',
                  hint: clientCount == 0
                      ? 'Toque em Novo cliente para cadastrar'
                      : 'Toque para buscar e abrir',
                  enabled: clientCount > 0,
                  onTap: _openClientsBar,
                ),
              ] else ...[
                const Text(
                  'Cadastro de instrumentos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'O cadastro de clientes fica com o escritório. Na OS, toque no '
                  'número do certificado para conferir ou preencher os dados do instrumento.',
                  style: TextStyle(
                    color: Color(0xFF5C6570),
                    height: 1.3,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OpenBar extends StatelessWidget {
  const _OpenBar({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD8DDE3)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? GsTheme.navy : const Color(0xFF9AA3AD),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: enabled ? GsTheme.navy : const Color(0xFF9AA3AD),
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more,
                color: enabled
                    ? const Color(0xFF5C6570)
                    : const Color(0xFFB0B7BF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: GsTheme.navy),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: GsTheme.brass.withValues(alpha: 0.35),
      checkmarkColor: GsTheme.navy,
      side: BorderSide(
        color: selected ? GsTheme.navy : const Color(0xFFD0D5DA),
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: GsTheme.navy,
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD8DDE3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: GsTheme.navy, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: GsTheme.navy,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF5C6570),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudCalibrationsSheet extends StatefulWidget {
  const _CloudCalibrationsSheet({required this.onToast});

  final void Function(String) onToast;

  @override
  State<_CloudCalibrationsSheet> createState() =>
      _CloudCalibrationsSheetState();
}

class _FolderGroup {
  _FolderGroup({
    required this.title,
    required this.osNumber,
    required this.clientName,
  });
  final String title;
  final String osNumber;
  final String clientName;
  final Map<CalibrationKind, List<CalibrationJob>> kindMap = {};

  List<CalibrationJob> get allJobs => [
    for (final list in kindMap.values) ...list,
  ];
}

class _CloudCalibrationsSheetState extends State<_CloudCalibrationsSheet> {
  final _selectedIds = <String>{};
  final _searchController = TextEditingController();
  var _busy = false;
  var _groupByFolders = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveOsNumber(CalibrationJob job) {
    var osNum = job.osNumber.trim();
    if (osNum.isEmpty && job.osId.trim().isNotEmpty) {
      final linked = FieldStore.instance.byId(job.osId.trim());
      if (linked != null && linked.number.trim().isNotEmpty) {
        osNum = linked.number.trim();
      }
    }
    if (osNum.isEmpty && job.clientName.trim().isNotEmpty) {
      final clientNameNorm = job.clientName.trim().toLowerCase();
      final clientCnpjNorm = job.clientCnpj.replaceAll(RegExp(r'\D'), '');
      for (final o in FieldStore.instance.officeItems) {
        if (clientCnpjNorm.isNotEmpty &&
            o.rdo.cnpj.replaceAll(RegExp(r'\D'), '') == clientCnpjNorm) {
          osNum = o.number.trim();
          break;
        }
        if (clientNameNorm.isNotEmpty &&
            o.rdo.client.trim().toLowerCase() == clientNameNorm) {
          osNum = o.number.trim();
          break;
        }
      }
    }
    if (osNum.isEmpty) {
      final order = job.orderNumber.trim();
      final lower = order.toLowerCase();
      if (order.isNotEmpty &&
          lower != 's/n' &&
          lower != 'sn' &&
          lower != 'n/a' &&
          lower != 'na' &&
          lower != '-') {
        osNum = order;
      }
    }
    final lower = osNum.toLowerCase();
    if (lower == 's/n' ||
        lower == 'sn' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-') {
      return '';
    }
    return osNum;
  }

  List<_FolderGroup> _groupJobs(List<CalibrationJob> jobs) {
    final map = <String, _FolderGroup>{};
    for (final job in jobs) {
      final os = _resolveOsNumber(job);
      final client = job.clientName.trim();
      String key;
      String title;
      if (os.isNotEmpty && client.isNotEmpty) {
        key = 'os:$os:$client';
        title = 'OS $os · $client';
      } else if (os.isNotEmpty) {
        key = 'os:$os';
        title = 'OS $os';
      } else if (client.isNotEmpty) {
        key = 'client:$client';
        title = 'Base / Cliente: $client';
      } else {
        key = 'other';
        title = 'Sem OS / Base definida';
      }
      final group = map.putIfAbsent(
        key,
        () => _FolderGroup(title: title, osNumber: os, clientName: client),
      );
      group.kindMap.putIfAbsent(job.kind, () => []).add(job);
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CalibrationStore.instance,
      builder: (context, _) {
        final all = CalibrationStore.instance.items;
        final query = _searchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? all
            : all.where((job) {
                final resolvedOs = _resolveOsNumber(job);
                final s =
                    '${job.number} ${job.clientName} ${job.equipmentTag} $resolvedOs ${job.orderNumber} ${job.title} ${calibrationKindLabel(job.kind)}'
                        .toLowerCase();
                return s.contains(query);
              }).toList();

        final allSelected =
            filtered.isNotEmpty &&
            filtered.every((j) => _selectedIds.contains(j.id));
        final remoteIds = CalibrationStore.instance.remoteJobIds;
        final folderGroups = _groupJobs(filtered);

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: GsTheme.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: GsTheme.navy,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Salvar Certificados na Nuvem',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GsTheme.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _groupByFolders
                            ? 'Ver como lista'
                            : 'Agrupar por pastas (OS / Base)',
                        icon: Icon(
                          _groupByFolders ? Icons.folder_open : Icons.view_list,
                          color: GsTheme.navy,
                        ),
                        onPressed: () =>
                            setState(() => _groupByFolders = !_groupByFolders),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por OS, número, cliente, tag...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _searchController.clear()),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect : Icons.select_all,
                          size: 16,
                        ),
                        label: Text(
                          allSelected ? 'Desmarcar todos' : 'Selecionar todos',
                        ),
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  if (allSelected) {
                                    for (final j in filtered) {
                                      _selectedIds.remove(j.id);
                                    }
                                  } else {
                                    for (final j in filtered) {
                                      _selectedIds.add(j.id);
                                    }
                                  }
                                });
                              },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.cloud_off_outlined, size: 16),
                        label: const Text('Apenas não salvos'),
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _selectedIds.clear();
                                  for (final j in filtered) {
                                    if (!remoteIds.contains(j.id)) {
                                      _selectedIds.add(j.id);
                                    }
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum certificado encontrado.',
                            style: TextStyle(color: Color(0xFF5C6570)),
                          ),
                        )
                      : _groupByFolders
                      ? ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          itemCount: folderGroups.length,
                          itemBuilder: (context, fIdx) {
                            final folder = folderGroups[fIdx];
                            final folderJobs = folder.allJobs;
                            final folderSelectedCount = folderJobs
                                .where((j) => _selectedIds.contains(j.id))
                                .length;
                            final isAllFolderSelected =
                                folderJobs.isNotEmpty &&
                                folderSelectedCount == folderJobs.length;
                            final isPartialFolderSelected =
                                folderSelectedCount > 0 && !isAllFolderSelected;
                            final folderRemoteCount = folderJobs
                                .where((j) => remoteIds.contains(j.id))
                                .length;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Color(0xFFDDE3EA),
                                ),
                              ),
                              elevation: 0,
                              color: Colors.white,
                              child: Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: Checkbox(
                                    tristate: true,
                                    value: isAllFolderSelected
                                        ? true
                                        : (isPartialFolderSelected
                                              ? null
                                              : false),
                                    onChanged: _busy
                                        ? null
                                        : (val) {
                                            setState(() {
                                              if (val == true) {
                                                for (final j in folderJobs) {
                                                  _selectedIds.add(j.id);
                                                }
                                              } else {
                                                for (final j in folderJobs) {
                                                  _selectedIds.remove(j.id);
                                                }
                                              }
                                            });
                                          },
                                  ),
                                  title: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_rounded,
                                        color: GsTheme.navy,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              folder.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: GsTheme.navy,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${folderJobs.length} certificado(s) · $folderRemoteCount na nuvem',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF5C6570),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip:
                                            'Gerar livro PDF neste aparelho',
                                        icon: const Icon(
                                          Icons.menu_book_outlined,
                                          color: GsTheme.navy,
                                          size: 20,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _buildCertificateBook(
                                                targetJobs: folderJobs,
                                              ),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'calibracao-book-drive-${folder.title}',
                                        ),
                                        tooltip:
                                            'Salvar livro PDF no Google Drive',
                                        icon: const Icon(
                                          Icons.menu_book,
                                          color: GsTheme.brass,
                                          size: 20,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _buildCertificateBook(
                                                targetJobs: folderJobs,
                                                saveToDrive: true,
                                              ),
                                      ),
                                      IconButton(
                                        tooltip:
                                            'Salvar certificados (PDF de cada um) no Google Drive',
                                        icon: const Icon(
                                          Icons.drive_folder_upload,
                                          color: GsTheme.navy,
                                          size: 20,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _saveBatchToDrive(
                                                folderJobs,
                                              ),
                                      ),
                                      IconButton(
                                        tooltip:
                                            'Salvar todos desta pasta na nuvem',
                                        icon: Icon(
                                          folderRemoteCount == folderJobs.length
                                              ? Icons.cloud_done
                                              : Icons.cloud_upload_outlined,
                                          color:
                                              folderRemoteCount ==
                                                  folderJobs.length
                                              ? const Color(0xFF2E7D32)
                                              : GsTheme.navy,
                                          size: 20,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _saveBatch(folderJobs),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    for (final entry
                                        in folder.kindMap.entries) ...[
                                      () {
                                        final kind = entry.key;
                                        final kindJobs = entry.value;
                                        final kindSelectedCount = kindJobs
                                            .where(
                                              (j) =>
                                                  _selectedIds.contains(j.id),
                                            )
                                            .length;
                                        final isAllKindSelected =
                                            kindJobs.isNotEmpty &&
                                            kindSelectedCount ==
                                                kindJobs.length;
                                        final isPartialKindSelected =
                                            kindSelectedCount > 0 &&
                                            !isAllKindSelected;
                                        final kindRemoteCount = kindJobs
                                            .where(
                                              (j) => remoteIds.contains(j.id),
                                            )
                                            .length;

                                        return Container(
                                          margin: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF7F9FB),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE5EBF0),
                                            ),
                                          ),
                                          child: ExpansionTile(
                                            initiallyExpanded: true,
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 0,
                                                ),
                                            leading: Checkbox(
                                              tristate: true,
                                              value: isAllKindSelected
                                                  ? true
                                                  : (isPartialKindSelected
                                                        ? null
                                                        : false),
                                              onChanged: _busy
                                                  ? null
                                                  : (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          for (final j
                                                              in kindJobs) {
                                                            _selectedIds.add(
                                                              j.id,
                                                            );
                                                          }
                                                        } else {
                                                          for (final j
                                                              in kindJobs) {
                                                            _selectedIds.remove(
                                                              j.id,
                                                            );
                                                          }
                                                        }
                                                      });
                                                    },
                                            ),
                                            title: Row(
                                              children: [
                                                const Icon(
                                                  Icons.folder_open_rounded,
                                                  color: Color(0xFF4A5568),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${calibrationKindLabel(kind)} (${kindJobs.length})',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Color(0xFF2D3748),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip:
                                                      'Salvar este tipo no Google Drive',
                                                  icon: const Icon(
                                                    Icons.drive_folder_upload,
                                                    color: GsTheme.navy,
                                                    size: 19,
                                                  ),
                                                  onPressed: _busy
                                                      ? null
                                                      : () =>
                                                            _saveBatchToDrive(
                                                              kindJobs,
                                                            ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Salvar este tipo na nuvem',
                                                  icon: Icon(
                                                    kindRemoteCount ==
                                                            kindJobs.length
                                                        ? Icons.cloud_done
                                                        : Icons
                                                              .cloud_upload_outlined,
                                                    color:
                                                        kindRemoteCount ==
                                                            kindJobs.length
                                                        ? const Color(
                                                            0xFF2E7D32,
                                                          )
                                                        : GsTheme.navy,
                                                    size: 19,
                                                  ),
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _saveBatch(
                                                          kindJobs,
                                                        ),
                                                ),
                                              ],
                                            ),
                                            children: [
                                              for (final job in kindJobs) ...[
                                                () {
                                                  final isSelected =
                                                      _selectedIds.contains(
                                                        job.id,
                                                      );
                                                  final isRemote = remoteIds
                                                      .contains(job.id);
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          6,
                                                          8,
                                                          6,
                                                        ),
                                                    decoration:
                                                        const BoxDecoration(
                                                          border: Border(
                                                            top: BorderSide(
                                                              color: Color(
                                                                0xFFEDF2F7,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Checkbox(
                                                          value: isSelected,
                                                          onChanged: _busy
                                                              ? null
                                                              : (val) {
                                                                  setState(() {
                                                                    if (val ==
                                                                        true) {
                                                                      _selectedIds
                                                                          .add(
                                                                            job.id,
                                                                          );
                                                                    } else {
                                                                      _selectedIds
                                                                          .remove(
                                                                            job.id,
                                                                          );
                                                                    }
                                                                  });
                                                                },
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                job
                                                                        .number
                                                                        .isNotEmpty
                                                                    ? job.number
                                                                    : 'Sem número',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                  color: GsTheme
                                                                      .navy,
                                                                ),
                                                              ),
                                                              Text(
                                                                [
                                                                  if (job
                                                                      .equipmentTag
                                                                      .isNotEmpty)
                                                                    'TAG: ${job.equipmentTag}',
                                                                  if (job
                                                                      .model
                                                                      .isNotEmpty)
                                                                    'Mod: ${job.model}',
                                                                  if (job
                                                                      .clientName
                                                                      .isNotEmpty)
                                                                    job.clientName,
                                                                ].join(' · '),
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFF5C6570,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isRemote
                                                                ? const Color(
                                                                    0xFFE8F5E9,
                                                                  )
                                                                : const Color(
                                                                    0xFFFFF3E0,
                                                                  ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                isRemote
                                                                    ? Icons
                                                                          .cloud_done
                                                                    : Icons
                                                                          .cloud_upload_outlined,
                                                                size: 12,
                                                                color: isRemote
                                                                    ? const Color(
                                                                        0xFF2E7D32,
                                                                      )
                                                                    : const Color(
                                                                        0xFFE65100,
                                                                      ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                isRemote
                                                                    ? 'Na nuvem'
                                                                    : 'Pendente',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      isRemote
                                                                      ? const Color(
                                                                          0xFF2E7D32,
                                                                        )
                                                                      : const Color(
                                                                          0xFFE65100,
                                                                        ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              'Salvar PDF no Google Drive da OS',
                                                          icon: const Icon(
                                                            Icons
                                                                .drive_folder_upload,
                                                            color: GsTheme.navy,
                                                            size: 19,
                                                          ),
                                                          onPressed: _busy
                                                              ? null
                                                              : () =>
                                                                    _saveBatchToDrive(
                                                                      [job],
                                                                    ),
                                                        ),
                                                        IconButton(
                                                          tooltip: isRemote
                                                              ? 'Atualizar/copiar na nuvem'
                                                              : 'Salvar na nuvem',
                                                          icon: Icon(
                                                            isRemote
                                                                ? Icons
                                                                      .cloud_done
                                                                : Icons
                                                                      .cloud_upload_outlined,
                                                            color: isRemote
                                                                ? const Color(
                                                                    0xFF2E7D32,
                                                                  )
                                                                : GsTheme.navy,
                                                            size: 20,
                                                          ),
                                                          onPressed: _busy
                                                              ? null
                                                              : () =>
                                                                    _saveSingle(
                                                                      job,
                                                                    ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }(),
                                              ],
                                            ],
                                          ),
                                        );
                                      }(),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final job = filtered[index];
                            final isSelected = _selectedIds.contains(job.id);
                            final isRemote = remoteIds.contains(job.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: _busy
                                    ? null
                                    : (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedIds.add(job.id);
                                          } else {
                                            _selectedIds.remove(job.id);
                                          }
                                        });
                                      },
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.number.isNotEmpty
                                          ? job.number
                                          : 'Sem número',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: GsTheme.navy,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isRemote
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isRemote
                                              ? Icons.cloud_done
                                              : Icons.cloud_upload_outlined,
                                          size: 13,
                                          color: isRemote
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFE65100),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isRemote ? 'Na nuvem' : 'Pendente',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isRemote
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${_resolveOsNumber(job).isNotEmpty ? 'OS ${_resolveOsNumber(job)} · ' : ''}${job.clientName.trim().isEmpty ? 'Sem cliente' : job.clientName.trim()} · ${calibrationKindLabel(job.kind)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5C6570),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Salvar PDF no Google Drive da OS',
                                    icon: const Icon(
                                      Icons.drive_folder_upload,
                                      color: GsTheme.navy,
                                      size: 20,
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _saveBatchToDrive([job]),
                                  ),
                                  IconButton(
                                    tooltip: isRemote
                                        ? 'Atualizar/copiar na nuvem'
                                        : 'Salvar na nuvem',
                                    icon: Icon(
                                      isRemote
                                          ? Icons.cloud_done
                                          : Icons.cloud_upload_outlined,
                                      color: isRemote
                                          ? const Color(0xFF2E7D32)
                                          : GsTheme.navy,
                                      size: 22,
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _saveSingle(job),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                foregroundColor: GsTheme.navy,
                              ),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: Text(
                                _selectedIds.isEmpty
                                    ? 'Nuvem Planilha'
                                    : 'Nuvem (${_selectedIds.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _busy || _selectedIds.isEmpty
                                  ? null
                                  : () => _saveBatch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: GsTheme.navy,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.drive_folder_upload),
                              label: Text(
                                _selectedIds.isEmpty
                                    ? 'Drive por OS'
                                    : 'Drive (${_selectedIds.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _busy || _selectedIds.isEmpty
                                  ? null
                                  : () => _saveBatchToDrive(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _saveSingle(CalibrationJob job) async {
    final isRemote = CalibrationStore.instance.isRemote(job.id);
    if (isRemote) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: GsTheme.paper,
          title: const Text(
            'Certificado já na nuvem',
            style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
          ),
          content: Text(
            'O certificado ${job.number} (${job.clientName}) já foi salvo na nuvem.\n\n'
            'Deseja sobrescrever na nuvem ou salvar como uma nova cópia?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, 'copy'),
              child: const Text('Salvar como cópia'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, 'overwrite'),
              style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
              child: const Text('Sobrescrever'),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel' || !mounted) return;

      setState(() => _busy = true);
      if (action == 'copy') {
        final copy = CalibrationStore.instance.createCopy(job);
        final savedCopy = await CalibrationStore.instance.save(copy);
        final res = await CalibrationStore.instance.pushRemoteJob(savedCopy);
        if (mounted) {
          setState(() => _busy = false);
          widget.onToast(
            res.ok
                ? 'Cópia ${savedCopy.number} criada e salva na nuvem!'
                : 'Erro ao salvar cópia: ${res.error}',
          );
        }
      } else if (action == 'overwrite') {
        final res = await CalibrationStore.instance.pushRemoteJob(job);
        if (mounted) {
          setState(() => _busy = false);
          widget.onToast(
            res.ok
                ? 'Certificado ${job.number} atualizado na nuvem!'
                : 'Erro ao sobrescrever: ${res.error}',
          );
        }
      }
    } else {
      setState(() => _busy = true);
      final res = await CalibrationStore.instance.pushRemoteJob(job);
      if (mounted) {
        setState(() => _busy = false);
        widget.onToast(
          res.ok
              ? 'Certificado ${job.number} salvo na nuvem com sucesso!'
              : 'Erro ao salvar na nuvem: ${res.error}',
        );
      }
    }
  }

  Future<void> _saveBatch([List<CalibrationJob>? targetJobs]) async {
    final selectedJobs =
        targetJobs ??
        [
          for (final j in CalibrationStore.instance.items)
            if (_selectedIds.contains(j.id)) j,
        ];
    if (selectedJobs.isEmpty) return;

    final remoteIds = CalibrationStore.instance.remoteJobIds;
    final alreadyRemote = [
      for (final j in selectedJobs)
        if (remoteIds.contains(j.id)) j,
    ];

    String conflictStrategy = 'overwrite';
    if (alreadyRemote.isNotEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: GsTheme.paper,
          title: const Text(
            'Certificados já na nuvem',
            style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
          ),
          content: Text(
            '${alreadyRemote.length} dos ${selectedJobs.length} certificados selecionados já existem na nuvem.\n\n'
            'Como deseja proceder com os certificados repetidos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, 'skip'),
              child: const Text('Pular repetidos (só novos)'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, 'copy'),
              child: const Text('Salvar como cópias'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, 'overwrite'),
              style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
              child: const Text('Sobrescrever'),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel' || !mounted) return;
      conflictStrategy = action;
    }

    setState(() => _busy = true);
    var saved = 0;
    var updated = 0;
    var copied = 0;
    var errors = 0;

    for (final job in selectedJobs) {
      final isRemote = remoteIds.contains(job.id);
      if (isRemote) {
        if (conflictStrategy == 'skip') {
          continue;
        } else if (conflictStrategy == 'copy') {
          final copy = CalibrationStore.instance.createCopy(job);
          final savedCopy = await CalibrationStore.instance.save(copy);
          final res = await CalibrationStore.instance.pushRemoteJob(savedCopy);
          if (res.ok)
            copied++;
          else
            errors++;
        } else {
          final res = await CalibrationStore.instance.pushRemoteJob(job);
          if (res.ok)
            updated++;
          else
            errors++;
        }
      } else {
        final res = await CalibrationStore.instance.pushRemoteJob(job);
        if (res.ok)
          saved++;
        else
          errors++;
      }
    }

    if (mounted) {
      setState(() => _busy = false);
      final parts = <String>[];
      if (saved > 0) parts.add('$saved novo(s) salvo(s)');
      if (updated > 0) parts.add('$updated sobrescrito(s)');
      if (copied > 0) parts.add('$copied cópia(s) criada(s)');
      if (errors > 0) parts.add('$errors erro(s)');
      if (parts.isEmpty) parts.add('Nenhum certificado novo enviado.');
      widget.onToast(parts.join(' · '));
    }
  }

  Future<void> _saveBatchToDrive([List<CalibrationJob>? targetJobs]) async {
    final selectedJobs =
        targetJobs ??
        [
          for (final j in CalibrationStore.instance.items)
            if (_selectedIds.contains(j.id)) j,
        ];
    if (selectedJobs.isEmpty) return;
    setState(() => _busy = true);
    try {
      await archiveCalibrationJobsToDrive(context, selectedJobs);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildCertificateBook({
    List<CalibrationJob>? targetJobs,
    bool saveToDrive = false,
  }) async {
    if (saveToDrive) {
      final ready = await ensureDriveReady(context);
      if (!ready || !mounted) return;
    }
    final candidates =
        targetJobs ??
        [
          for (final j in CalibrationStore.instance.items)
            if (_selectedIds.contains(j.id)) j,
        ];
    if (candidates.isEmpty) {
      widget.onToast('Selecione certificados para montar o livro.');
      return;
    }
    final selectedJobs = await showCertificateBookPickDialog(
      context,
      jobs: candidates,
      title: saveToDrive
          ? 'Salvar livro no Google Drive'
          : 'Quais certificados no livro?',
    );
    if (selectedJobs == null || !mounted) return;
    if (selectedJobs.isEmpty) {
      widget.onToast('Marque ao menos um certificado para gerar o livro.');
      return;
    }
    final signed = await askCertificateSignatureMode(
      context,
      title: 'Assinatura do livro',
    );
    if (signed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final requester = selectedJobs
          .map((j) => j.serviceRequester.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final bytes = await buildCalibrationCertificateBundle(
        jobs: selectedJobs,
        requesterName: requester,
        clientName: selectedJobs
            .map((j) => j.clientName.trim())
            .firstWhere((v) => v.isNotEmpty, orElse: () => ''),
        osNumber: selectedJobs
            .map((j) => j.osNumber.trim())
            .firstWhere((v) => v.isNotEmpty, orElse: () => ''),
        withSignature: signed,
      );
      final fileName = calibrationBundleFileName(
        osNumber: selectedJobs.first.osNumber,
        requester: requester,
      );
      final savedAt = await saveLocalFile(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'GS Campo/Certificados',
      );
      var inDrive = false;
      if (saveToDrive) {
        final first = selectedJobs.first;
        inDrive = await saveGeneratedPdfToDrive(
          osId: first.osId,
          osNumber: calibrationJobOsFolderKey(first),
          folder: driveBookFolder,
          fileName: fileName,
          bytes: bytes,
        );
      }
      if (!mounted) return;
      if (saveToDrive) {
        widget.onToast(
          inDrive
              ? 'Livro com ${selectedJobs.length} certificado(s) salvo no Google Drive '
                    '(Certificados de Calibração/Book).'
              : 'Livro gerado no aparelho ($savedAt), mas não entrou no Google Drive. '
                    'Confira a pasta das OS em Configurações.',
        );
      } else {
        widget.onToast(
          'Livro com ${selectedJobs.length} certificado(s) gerado. $savedAt '
          'Use o ícone do livro dourado para salvar no Google Drive.',
        );
      }
    } catch (error) {
      widget.onToast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
