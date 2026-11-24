import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/clients/client_edit_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  var _syncing = false;
  String? _busyClientId;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matchesClient(SavedClient client, String query) {
    if (query.isEmpty) return true;
    final blob = foldPersonKey(
      [
        client.name,
        client.cnpj,
        client.cnpj.replaceAll(RegExp(r'\D'), ''),
        client.city,
        client.state,
        client.requester,
        ...client.sites,
      ].join(' '),
    );
    return foldPersonKey(
      query,
    ).split(' ').where((word) => word.isNotEmpty).every(blob.contains);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await ClientStore.instance.sync();
    if (mounted) setState(() => _syncing = false);
  }

  Future<SavedClient> _fullClient(SavedClient client) async {
    // force: exclusões feitas no notebook precisam chegar ao abrir o card.
    return await ClientStore.instance.ensureFull(client.id, force: true) ??
        client;
  }

  Future<void> _downloadExcel(SavedClient client) async {
    if (_busyClientId != null) return;
    setState(() => _busyClientId = client.id);
    try {
      final full = await _fullClient(client);
      final bytes = buildClientExcelTemplate(
        clients: [full],
        withExample: false,
      );
      final safeName = full.name
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = safeName.isEmpty
          ? clientExcelFileName
          : 'GS_Calibracao_${safeName.length > 40 ? safeName.substring(0, 40) : safeName}.xlsx';
      await downloadRdoFile(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      final n = full.equipment.length;
      _toast(
        n == 0
            ? 'Planilha de ${full.name} baixada (ainda sem instrumentos).'
            : 'Planilha de ${full.name}: $n instrumento(s).',
      );
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busyClientId = null);
    }
  }

  Future<void> _importExcel(SavedClient client) async {
    if (_busyClientId != null) return;
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
    setState(() => _busyClientId = client.id);
    try {
      final full = await _fullClient(client);
      final result = await importClientWorkbook(bytes, onlyClient: full);
      if (!mounted) return;
      _toast(result.message);
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busyClientId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExcel = AuthSession.instance.user?.canUseClientExcel == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Atualizar cadastro compartilhado',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ClientStore.instance,
        builder: (context, _) {
          final all = ClientStore.instance.items;
          final query = _query.text.trim();
          final items = [
            for (final client in all)
              if (_matchesClient(client, query)) client,
          ];
          final searching = query.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Cadastro compartilhado entre todos os funcionários. '
                'Toque no cliente para editar dados, sistemas, instrumentos e '
                'produtos — tudo pelo app, sem planilha.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Color(0xFF5C6570),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('nova-cliente'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClientEditPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 26),
                style: FilledButton.styleFrom(
                  backgroundColor: GsTheme.brass,
                  foregroundColor: Colors.black,
                ),
                label: const Text('Novo cliente'),
              ),
              const SizedBox(height: 18),
              if (all.isNotEmpty) ...[
                TextField(
                  key: const Key('clientes-busca'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar cliente',
                    hintText: 'Nome, CNPJ, cidade ou local',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searching
                        ? IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_query.clear),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Nenhum cliente na empresa ainda.\nSalve um cliente aqui ou gere uma OS: o contratante fica no cadastro compartilhado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Nenhum cliente com esse texto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      color: Color(0xFF5C6570),
                    ),
                  ),
                )
              else ...[
                Text(
                  searching
                      ? '${items.length} encontrado(s)'
                      : '${items.length} cliente(s)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 10),
                for (final client in items) ...[
                  _ClientCard(
                    client: client,
                    busy: _busyClientId == client.id,
                    canExcel: canExcel,
                    onDownloadExcel: () => _downloadExcel(client),
                    onImportExcel: () => _importExcel(client),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.busy,
    required this.canExcel,
    required this.onDownloadExcel,
    required this.onImportExcel,
  });

  final SavedClient client;
  final bool busy;
  final bool canExcel;
  final VoidCallback onDownloadExcel;
  final VoidCallback onImportExcel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: busy
            ? null
            : () async {
                final full =
                    await ClientStore.instance.ensureFull(
                      client.id,
                      force: true,
                    ) ??
                    client;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClientEditPage(existing: full),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: GsTheme.brass, width: 5),
              top: BorderSide(color: Color(0x331A2330)),
              right: BorderSide(color: Color(0x331A2330)),
              bottom: BorderSide(color: Color(0x331A2330)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                client.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                  fontSize: 20,
                ),
              ),
              if (client.cnpj.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'CNPJ ${client.cnpj}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C6570),
                  ),
                ),
              ],
              if (client.addressLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  client.addressLine,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C6570),
                  ),
                ),
              ],
              if (client.equipment.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${client.equipment.length} instrumento(s)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
              ],
              if (client.sites.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '${client.sites.length} locais',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
              ],
              if (canExcel) ...[
                const SizedBox(height: 12),
                if (busy)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onDownloadExcel,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Baixar Excel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onImportExcel,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('Importar Excel'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
