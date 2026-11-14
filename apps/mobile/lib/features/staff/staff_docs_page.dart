import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/office_recipients.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/data/staff_docs_store.dart';
import 'package:gs_mobile/features/staff/staff_docs_group.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum _StaffAttachSignMode {
  /// Só anexa, sem assinatura.
  none,

  /// Funcionário assina em Meus documentos (e-mail).
  requestStaff,

  /// Quem está anexando (RH) assina agora.
  signAsManager,
}

class StaffDocsPage extends StatefulWidget {
  const StaffDocsPage({super.key, required this.user, this.allowAttach = true});

  final RemoteAccount user;
  final bool allowAttach;

  @override
  State<StaffDocsPage> createState() => _StaffDocsPageState();
}

class _StaffDocsPageState extends State<StaffDocsPage> {
  var _busy = false;

  RemoteAccount get user => widget.user;

  AppUser? get _sessionUser => AuthSession.instance.user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() =>
      StaffDocsStore.instance.load(staffEmail: user.email);

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: GsTheme.navy, content: Text(message)),
    );
  }

  Future<_StaffAttachSignMode?> _askAttachSignMode(int fileCount) async {
    return showDialog<_StaffAttachSignMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assinatura do documento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fileCount == 1
                    ? 'Como deseja tratar a assinatura deste arquivo?'
                    : 'Como deseja tratar a assinatura destes $fileCount arquivos?',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 14),
              const Text(
                '• Funcionário: ele recebe e-mail e assina em Meus documentos.\n'
                '• Você (RH): assina agora com o seu nome neste aparelho.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF5C6570),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _StaffAttachSignMode.none),
            child: const Text('Só anexar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _StaffAttachSignMode.requestStaff),
            child: const Text('Solicitar ao funcionário'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _StaffAttachSignMode.signAsManager),
            child: const Text('Assinar eu agora'),
          ),
        ],
      ),
    );
  }

  Future<void> _attach({required bool photo}) async {
    final picked = await _pickStaffFiles(photo: photo);
    if (picked.isEmpty) return;
    if (!mounted) return;
    final mode = await _askAttachSignMode(picked.length);
    if (mode == null) return;

    if (mode == _StaffAttachSignMode.signAsManager) {
      final session = _sessionUser;
      if (session == null) {
        _toast('Faça login novamente para assinar como responsável.');
        return;
      }
      final managerName = session.name.trim().isEmpty
          ? session.login
          : session.name.trim();
      final confirmed = await _confirmSignatureDialog(
        documentLabel: picked.length == 1
            ? picked.first.name
            : '${picked.length} arquivos',
        signerName: managerName,
        cargo: session.cargo.trim(),
        title: 'Assinar como responsável',
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    var saved = 0;
    var errors = 0;
    try {
      for (final file in picked) {
        try {
          final doc = await StaffDocsStore.instance.add(
            staffEmail: user.email,
            staffName: user.name,
            name: file.name,
            bytes: file.bytes,
            kind: file.kind,
            requiresSignature: mode != _StaffAttachSignMode.none,
            notifyStaff: mode == _StaffAttachSignMode.requestStaff,
          );
          if (mode == _StaffAttachSignMode.signAsManager) {
            final session = _sessionUser!;
            final managerName = session.name.trim().isEmpty
                ? session.login
                : session.name.trim();
            final cargo = session.cargo.trim();
            final signedAt = DateTime.now();
            final png = await buildElectronicSignaturePng(
              name: managerName,
              cargo: cargo,
              signedAt: signedAt,
            );
            await StaffDocsStore.instance.markSigned(
              doc: doc,
              signedBy: managerName,
              signedAt: signedAt,
              signaturePng: png,
              cargo: cargo,
            );
          }
          saved++;
        } catch (_) {
          errors++;
        }
      }
      if (!mounted) return;
      final note = StaffDocsStore.instance.lastNotifyMessage;
      if (errors > 0 && saved == 0) {
        _toast('Não foi possível anexar os arquivos.');
      } else if (mode == _StaffAttachSignMode.requestStaff) {
        _toast(
          saved == 1
              ? (note ??
                    'Arquivo anexado e enviado ao funcionário para assinatura.')
              : '$saved arquivo(s) anexado(s) e enviado(s) ao funcionário para assinatura.'
                    '${errors > 0 ? ' · $errors erro(s)' : ''}',
        );
      } else if (mode == _StaffAttachSignMode.signAsManager) {
        _toast(
          saved == 1
              ? 'Arquivo anexado e assinado por você.'
              : '$saved arquivo(s) anexado(s) e assinado(s) por você.'
                    '${errors > 0 ? ' · $errors erro(s)' : ''}',
        );
      } else {
        _toast(
          saved == 1
              ? (note ?? 'Arquivo anexado.')
              : '$saved arquivo(s) anexado(s).'
                    '${errors > 0 ? ' · $errors erro(s)' : ''}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<({String name, List<int> bytes, OsFileKind kind})>>
  _pickStaffFiles({required bool photo}) async {
    final out = <({String name, List<int> bytes, OsFileKind kind})>[];
    if (photo) {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        out.add((name: file.name, bytes: bytes, kind: OsFileKind.photo));
      }
    } else {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
        allowMultiple: true,
      );
      if (picked == null || picked.files.isEmpty) return out;
      for (final file in picked.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        out.add((
          name: file.name,
          bytes: bytes,
          kind: file.name.toLowerCase().endsWith('.pdf')
              ? OsFileKind.certificate
              : OsFileKind.photo,
        ));
      }
    }
    if (out.isEmpty && mounted) {
      _toast('Não deu para ler os arquivos selecionados.');
    }
    return out;
  }

  Future<bool?> _confirmSignatureDialog({
    required String documentLabel,
    required String signerName,
    required String cargo,
    required String title,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Documento: $documentLabel'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Assinatura de: $signerName'
                  '${cargo.trim().isEmpty ? '' : ' · $cargo'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5C6570),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElectronicSignatureCard(name: signerName, cargo: cargo),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar assinatura'),
          ),
        ],
      ),
    );
  }

  /// Assina com a identidade do funcionário (tela Meus documentos).
  Future<void> _signAsStaff(StaffDocument doc) async {
    final name = user.name.trim().isEmpty ? user.login : user.name;
    final cargo = user.cargo.trim();
    final confirmed = await _confirmSignatureDialog(
      documentLabel: doc.name,
      signerName: name,
      cargo: cargo,
      title: 'Assinar documento',
    );
    if (confirmed != true) return;
    await _applySignature(doc: doc, signerName: name, cargo: cargo);
  }

  /// Assina com a identidade de quem está logado (RH / responsável).
  Future<void> _signAsManager(StaffDocument doc) async {
    final session = _sessionUser;
    if (session == null) {
      _toast('Faça login novamente para assinar como responsável.');
      return;
    }
    final name = session.name.trim().isEmpty
        ? session.login
        : session.name.trim();
    final cargo = session.cargo.trim();
    final confirmed = await _confirmSignatureDialog(
      documentLabel: doc.name,
      signerName: name,
      cargo: cargo,
      title: 'Assinar como responsável',
    );
    if (confirmed != true) return;
    await _applySignature(doc: doc, signerName: name, cargo: cargo);
  }

  Future<void> _applySignature({
    required StaffDocument doc,
    required String signerName,
    required String cargo,
  }) async {
    setState(() => _busy = true);
    try {
      final signedAt = DateTime.now();
      final png = await buildElectronicSignaturePng(
        name: signerName,
        cargo: cargo,
        signedAt: signedAt,
      );
      await StaffDocsStore.instance.markSigned(
        doc: doc,
        signedBy: signerName,
        signedAt: signedAt,
        signaturePng: png,
        cargo: cargo,
      );
      if (mounted) {
        _toast(
          doc.name.toLowerCase().endsWith('.pdf')
              ? 'Documento assinado no PDF.'
              : 'Documento assinado.',
        );
      }
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDoc(StaffDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar documento?'),
        content: Text(
          'Remove ${doc.name} desta lista${doc.isSigned ? ' (já assinado)' : ''}. '
          'Use se anexou errado ou deu erro na nuvem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await StaffDocsStore.instance.deleteDoc(doc);
      if (mounted) _toast('Documento apagado.');
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroup(StaffDocGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar todos · ${group.name}?'),
        content: Text(
          'Remove ${group.docs.length} envio(s) deste arquivo da lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar todos'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      for (final doc in group.docs) {
        await StaffDocsStore.instance.deleteDoc(doc);
      }
      if (mounted) _toast('Documentos apagados.');
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryCloud(StaffDocument doc) async {
    setState(() => _busy = true);
    try {
      final message = await StaffDocsStore.instance.retryCloud(
        doc,
        staffName: user.name,
      );
      if (!mounted) return;
      final fresh = StaffDocsStore.instance.byId(doc.id) ?? doc;
      if (message == null && fresh.mailSent) {
        _toast('Salvo na nuvem e e-mail enviado ao técnico.');
      } else {
        _toast(message ?? 'Salvo na nuvem (Google Drive).');
      }
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryMail(StaffDocument doc) async {
    setState(() => _busy = true);
    try {
      final message = await StaffDocsStore.instance.retryMail(
        doc,
        staffName: user.name,
      );
      if (!mounted) return;
      _toast(message ?? 'E-mail reenviado ao técnico.');
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _docRow(StaffDocument doc, {required bool showAttach}) {
    final hasIssue = doc.hasSyncIssue;
    final pendingSign = doc.requiresSignature && !doc.isSigned;
    return Container(
      key: Key('staff-doc-${doc.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: hasIssue ? const Color(0xFFFFF3E0) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: hasIssue ? Border.all(color: const Color(0xFFFFCC80)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (StaffDocsStore.instance
                            .forEmail(user.email)
                            .where(
                              (d) =>
                                  d.name.toLowerCase() ==
                                  doc.name.toLowerCase(),
                            )
                            .length >
                        1)
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(doc.createdAt.toLocal()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      staffDocStatusLine(doc),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                    if (doc.isSigned && doc.signedBy.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Assinado por ${doc.signedBy.trim()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GsTheme.navy,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showAttach)
                IconButton(
                  tooltip: 'Apagar',
                  onPressed: _busy ? null : () => _deleteDoc(doc),
                  icon: const Icon(Icons.delete_outline, size: 22),
                  color: const Color(0xFFB45309),
                ),
            ],
          ),
          if (doc.remoteError.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              doc.remoteError.trim(),
              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (doc.mailError.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              doc.mailError.trim(),
              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (pendingSign && !showAttach)
                FilledButton(
                  onPressed: _busy ? null : () => _signAsStaff(doc),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Assinar'),
                ),
              if (pendingSign && showAttach)
                FilledButton(
                  onPressed: _busy ? null : () => _signAsManager(doc),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Assinar como responsável'),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final bytes = await StaffDocsStore.instance.bytesOf(
                          doc,
                        );
                        if (bytes == null) {
                          if (mounted) {
                            _toast(
                              'Não baixou o arquivo. Atualize o script da planilha.',
                            );
                          }
                          return;
                        }
                        await downloadRdoFile(fileName: doc.name, bytes: bytes);
                      },
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Abrir'),
              ),
              if (showAttach && doc.needsCloudRetry)
                OutlinedButton(
                  onPressed: _busy ? null : () => _retryCloud(doc),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reenviar nuvem'),
                ),
              if (showAttach && doc.needsMailRetry)
                OutlinedButton(
                  onPressed: _busy ? null : () => _retryMail(doc),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reenviar e-mail'),
                ),
              if (showAttach && doc.canArchive) ...[
                OutlinedButton(
                  onPressed: _busy ? null : () => _sendNetwork(doc),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Salvar na rede'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _sendMail(doc),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Enviar e-mail'),
                ),
              ],
              if (showAttach)
                OutlinedButton(
                  onPressed: _busy ? null : () => _deleteDoc(doc),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFB45309),
                  ),
                  child: const Text('Apagar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendNetwork(StaffDocument doc) async {
    if (!doc.canArchive) {
      _toast('Esse documento ainda precisa da assinatura.');
      return;
    }
    final bytes = await StaffDocsStore.instance.bytesOf(doc);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _toast('Arquivo não está neste aparelho.');
      return;
    }
    setState(() => _busy = true);
    try {
      final connected = await ensureDriveReady(context);
      if (!connected) return;
      if (!mounted) return;
      final result = await AccountApi.instance.saveOsToDrive(
        osId: 'rh-${user.email}',
        osNumber: 'RH - ${user.name.isEmpty ? user.login : user.name}',
        files: [
          {
            'name': doc.name,
            'folder': 'Anexos',
            'mime': officeFileMime(doc.name),
            'data': base64Encode(bytes),
          },
        ],
      );
      if (!mounted) return;
      if (result.ok || result.sent) {
        await StaffDocsStore.instance.deleteDoc(doc);
        if (mounted) {
          _toast('Salvo na pasta de RH no Google Drive. Removido desta lista.');
        }
      } else {
        _toast(result.error ?? 'Não salvou na rede.');
      }
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMail(StaffDocument doc) async {
    if (!doc.canArchive) {
      _toast('Esse documento ainda precisa da assinatura.');
      return;
    }
    final bytes = await StaffDocsStore.instance.bytesOf(doc);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _toast('Arquivo não está neste aparelho.');
      return;
    }
    setState(() => _busy = true);
    try {
      final to = {
        ...officeRecipientEmails(),
        if (user.email.contains('@')) user.email.trim().toLowerCase(),
      }.toList();
      final result = await AccountApi.instance.sendOfficeMail(
        osId: 'rh-${user.email}',
        osNumber: 'RH - ${user.name.isEmpty ? user.login : user.name}',
        subject: 'Documento de ${user.name} — ${doc.name}',
        body:
            'Segue documento do funcionário ${user.name} (${user.email}).\nArquivo: ${doc.name}',
        to: to,
        files: [OfficeMailFile(name: doc.name, bytes: bytes)],
      );
      if (!mounted) return;
      _toast(
        result.sent || result.ok
            ? 'E-mail enviado.'
            : (result.error ?? 'Não enviou o e-mail.'),
      );
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim().isEmpty ? user.login : user.name;
    final canManage = AuthSession.instance.user?.canManageStaff == true;
    final showAttach = widget.allowAttach && canManage;
    return Scaffold(
      appBar: AppBar(
        title: Text(showAttach ? 'Documentos · $name' : 'Meus documentos'),
        actions: [
          AnimatedBuilder(
            animation: StaffDocsStore.instance,
            builder: (context, _) => IconButton(
              key: const Key('staff-docs-atualizar'),
              tooltip: 'Atualizar da nuvem',
              onPressed: StaffDocsStore.instance.syncing ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: StaffDocsStore.instance,
        builder: (context, _) {
          final store = StaffDocsStore.instance;
          final items = store.forEmail(user.email);
          final syncError = store.syncError;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  showAttach
                      ? 'Anexe PDF ou foto (holerite, recibo, etc.). Ao anexar, escolha: só anexar, '
                            'solicitar assinatura do funcionário, ou assinar você agora. '
                            'O arquivo precisa entrar na nuvem para aparecer em Meus documentos do técnico. '
                            'Depois de arquivar no Google Drive do RH, o item some desta lista.'
                      : 'Holerites, recibos e documentos que o RH enviou para o seu login. '
                            'Abra para ver; se pedir assinatura, confira e toque em Assinar. '
                            'Puxe para atualizar se acabou de receber um arquivo.',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Color(0xFF5C6570),
                  ),
                ),
                if (showAttach) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _attach(photo: false),
                        style: FilledButton.styleFrom(
                          backgroundColor: GsTheme.brass,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Anexar PDFs'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _attach(photo: true),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Anexar fotos'),
                      ),
                    ],
                  ),
                ],
                if (_busy || store.syncing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (syncError != null && !store.syncing) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('staff-docs-erro-nuvem'),
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            syncError,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('staff-docs-tentar-de-novo'),
                          onPressed: _reload,
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (items.isEmpty && store.syncing)
                  const Text(
                    'Buscando documentos na nuvem…',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  )
                else if (items.isEmpty)
                  Text(
                    showAttach
                        ? 'Nenhum documento neste cadastro ainda.'
                        : syncError != null
                        ? 'Não foi possível carregar da nuvem. Toque em Atualizar.'
                        : 'Nenhum documento na nuvem para o seu login. '
                              'Se o RH acabou de enviar, toque em Atualizar.',
                    style: const TextStyle(color: Color(0xFF5C6570)),
                  )
                else
                  StaffDocsGroupedList(
                    docs: items,
                    itemBuilder: (doc) => _docRow(doc, showAttach: showAttach),
                    groupActionsBuilder: showAttach
                        ? (group) {
                            if (group.docs.length <= 1) {
                              return const SizedBox.shrink();
                            }
                            return TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _deleteGroup(group),
                              icon: const Icon(Icons.delete_sweep_outlined),
                              label: const Text('Apagar todos deste arquivo'),
                            );
                          }
                        : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
