import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/field_files.dart'
    if (dart.library.io) 'package:gs_mobile/data/field_files_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/field_files_web.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/office_recipients.dart';
import 'package:gs_mobile/data/prefs_json.dart';
import 'package:gs_mobile/data/staff_sign_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-mail do RH só depois da nuvem — evita holerite no e-mail e lista vazia no app.
bool staffDocShouldSendMail({
  required bool cloudSynced,
  required bool requiresSignature,
  required bool notifyStaff,
  bool isSigned = false,
  bool mailSent = false,
}) {
  if (!cloudSynced) return false;
  if (!requiresSignature || !notifyStaff) return false;
  if (isSigned || mailSent) return false;
  return true;
}

class StaffDocument {
  const StaffDocument({
    required this.id,
    required this.staffEmail,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.requiresSignature = false,
    this.signedAt,
    this.signedBy = '',
    this.path = '',
    this.bytes,
    this.cloudSynced = false,
    this.mailSent = false,
    this.remoteError = '',
    this.mailError = '',
  });

  final String id;
  final String staffEmail;
  final String name;
  final OsFileKind kind;
  final DateTime createdAt;
  final bool requiresSignature;
  final DateTime? signedAt;
  final String signedBy;
  final String path;
  final List<int>? bytes;
  final bool cloudSynced;
  final bool mailSent;
  final String remoteError;
  final String mailError;

  bool get isSigned => signedAt != null || signedBy.trim().isNotEmpty;

  bool get canArchive => !requiresSignature || isSigned;

  bool get needsCloudRetry => !cloudSynced;

  bool get needsMailRetry => requiresSignature && !isSigned && !mailSent;

  bool get hasSyncIssue =>
      needsCloudRetry ||
      (needsMailRetry && mailError.trim().isNotEmpty) ||
      remoteError.trim().isNotEmpty;

  StaffDocument copyWith({
    bool? requiresSignature,
    DateTime? signedAt,
    String? signedBy,
    String? path,
    List<int>? bytes,
    bool? cloudSynced,
    bool? mailSent,
    String? remoteError,
    String? mailError,
  }) {
    return StaffDocument(
      id: id,
      staffEmail: staffEmail,
      name: name,
      kind: kind,
      createdAt: createdAt,
      requiresSignature: requiresSignature ?? this.requiresSignature,
      signedAt: signedAt ?? this.signedAt,
      signedBy: signedBy ?? this.signedBy,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      cloudSynced: cloudSynced ?? this.cloudSynced,
      mailSent: mailSent ?? this.mailSent,
      remoteError: remoteError ?? this.remoteError,
      mailError: mailError ?? this.mailError,
    );
  }

  /// [withBytes] false: PDF já está na nuvem e volta por [StaffDocsStore.bytesOf].
  Map<String, dynamic> toJson({bool withBytes = true}) => {
    'id': id,
    'staffEmail': staffEmail,
    'name': name,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'requiresSignature': requiresSignature,
    if (signedAt != null) 'signedAt': signedAt!.toIso8601String(),
    'signedBy': signedBy,
    'path': path,
    'cloudSynced': cloudSynced,
    'mailSent': mailSent,
    'remoteError': remoteError,
    'mailError': mailError,
    if (withBytes &&
        bytes != null &&
        bytes!.isNotEmpty &&
        bytes!.length < 1500000)
      'data': base64Encode(bytes!),
  };

  factory StaffDocument.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as String?;
    final path = jsonText(json['path'] ?? json['fileId']);
    final cloudSynced =
        json['cloudSynced'] == true ||
        (path.trim().isNotEmpty &&
            !path.contains('/') &&
            !path.contains('\\') &&
            path.length > 12);
    return StaffDocument(
      id: jsonText(json['id']),
      staffEmail: jsonText(json['staffEmail']),
      name: jsonText(json['name']).isEmpty ? 'arquivo' : jsonText(json['name']),
      kind: osFileKindFrom(json['kind'] as String?),
      createdAt:
          DateTime.tryParse(jsonText(json['createdAt'])) ?? DateTime.now(),
      requiresSignature:
          json['requiresSignature'] == true ||
          jsonText(json['requiresSignature']).toLowerCase() == 'sim',
      signedAt: DateTime.tryParse(jsonText(json['signedAt'])),
      signedBy: jsonText(json['signedBy']),
      path: path,
      cloudSynced: cloudSynced,
      mailSent: json['mailSent'] == true,
      remoteError: jsonText(json['remoteError']),
      mailError: jsonText(json['mailError']),
      bytes: data == null || data.isEmpty ? null : base64Decode(data),
    );
  }
}

class StaffDocsStore extends ChangeNotifier {
  StaffDocsStore._();
  static final instance = StaffDocsStore._();

  static const _key = staffDocsPrefsKey;

  final _files = createFieldFiles();
  List<StaffDocument> _all = [];
  var _loaded = false;
  var _syncing = false;
  String? _syncError;

  bool get syncing => _syncing;

  /// Última falha ao buscar a lista na nuvem (null se deu certo).
  String? get syncError => _syncError;

  List<StaffDocument> forEmail(String email) {
    final key = email.trim().toLowerCase();
    return [
      for (final item in _all)
        if (item.staffEmail.trim().toLowerCase() == key) item,
    ];
  }

  StaffDocument? byId(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final item in _all) {
      if (item.id == needle) return item;
    }
    return null;
  }

  Future<void> load({String staffEmail = ''}) async {
    if (!_loaded) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          _all = [
            for (final item in decoded)
              if (item is Map)
                StaffDocument.fromJson(Map<String, dynamic>.from(item)),
          ];
        } catch (error) {
          debugPrint('StaffDocsStore local: $error');
        }
      }
      _loaded = true;
    }
    await syncRemote(staffEmail: staffEmail);
    notifyListeners();
  }

  Future<void> syncRemote({String staffEmail = ''}) async {
    if (!AccountApi.useRemote) return;
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      var result = await AccountApi.instance.listStaffDocs(
        staffEmail: staffEmail,
      );
      if (!result.ok && !result.reachable) {
        result = await AccountApi.instance.listStaffDocs(
          staffEmail: staffEmail,
        );
      }
      if (!result.ok && result.docs.isEmpty) {
        _syncError = result.reachable
            ? (result.error ?? 'A nuvem não devolveu os documentos.')
            : 'Sem resposta da nuvem. Confira a internet e tente de novo.';
        return;
      }
      final remote = [
        for (final item in result.docs) StaffDocument.fromJson(item),
      ];
      if (remote.isEmpty && staffEmail.trim().isEmpty) return;
      final byId = <String, StaffDocument>{
        for (final item in _all) item.id: item,
      };
      for (final item in remote) {
        final previous = byId[item.id];
        byId[item.id] = previous == null
            ? item
            : item.copyWith(
                bytes: previous.bytes,
                path: item.path.trim().isEmpty ? previous.path : item.path,
                cloudSynced: item.cloudSynced || previous.cloudSynced,
                mailSent: item.mailSent || previous.mailSent,
                remoteError: previous.remoteError.trim().isNotEmpty
                    ? previous.remoteError
                    : item.remoteError,
                mailError: previous.mailError.trim().isNotEmpty
                    ? previous.mailError
                    : item.mailError,
              );
      }
      _all = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _persist();
    } catch (error) {
      debugPrint('StaffDocsStore sync: $error');
      _syncError = 'Não foi possível buscar os documentos na nuvem.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<StaffDocument> add({
    required String staffEmail,
    required String name,
    required List<int> bytes,
    OsFileKind kind = OsFileKind.certificate,
    bool requiresSignature = false,
    bool notifyStaff = true,
    String staffName = '',
  }) async {
    await load(staffEmail: staffEmail);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final path = await _files.save(
      ownerEmail: staffEmail,
      osId: 'rh',
      fileName: '${id}_$name',
      bytes: Uint8List.fromList(bytes),
    );
    final createdAt = DateTime.now();
    var doc = StaffDocument(
      id: id,
      staffEmail: staffEmail,
      name: name,
      kind: kind,
      createdAt: createdAt,
      requiresSignature: requiresSignature,
      path: path,
      bytes: bytes,
    );
    _all = [doc, ..._all];
    await _persist();
    notifyListeners();

    String? remoteError;
    String? mailError;
    var cloudSynced = false;
    var mailSent = false;
    try {
      final saved = await AccountApi.instance.saveStaffDoc(
        id: id,
        staffEmail: staffEmail,
        name: name,
        bytes: bytes,
        kind: kind.name,
        requiresSignature: requiresSignature,
        createdAt: createdAt.toIso8601String(),
      );
      if (saved.ok && saved.docs.isNotEmpty) {
        final remote = StaffDocument.fromJson(saved.docs.first);
        doc = doc.copyWith(
          path: remote.path,
          cloudSynced: true,
          remoteError: '',
        );
        cloudSynced = true;
        _all = [
          for (final item in _all)
            if (item.id == id) doc else item,
        ];
        await _persist();
        notifyListeners();
      } else if (saved.error != null) {
        remoteError = saved.error;
      }
    } catch (error) {
      remoteError = '$error';
    }

    // E-mail só depois da nuvem: senão o técnico recebe o PDF e Meus documentos fica vazio.
    if (staffDocShouldSendMail(
      cloudSynced: cloudSynced,
      requiresSignature: requiresSignature,
      notifyStaff: notifyStaff,
    )) {
      final mail = await _notifyTechnicianToSign(
        doc: doc,
        bytes: bytes,
        staffName: staffName,
      );
      if (mail == null) {
        mailSent = true;
        doc = doc.copyWith(mailSent: true, mailError: '');
      } else {
        mailError = mail;
      }
    } else if (requiresSignature && notifyStaff && !cloudSynced) {
      mailError =
          'Arquivo não entrou na nuvem — o técnico não verá no app. '
          'E-mail não foi enviado. Use Tentar de novo.';
    }

    doc = doc.copyWith(
      cloudSynced: cloudSynced,
      mailSent: mailSent,
      remoteError: remoteError ?? '',
      mailError: mailError ?? '',
    );
    _all = [
      for (final item in _all)
        if (item.id == id) doc else item,
    ];
    await _persist();
    notifyListeners();

    if (remoteError != null && requiresSignature && notifyStaff) {
      lastNotifyMessage =
          '${_staffDocRemoteHint(remoteError)}\n\n'
          'Arquivo não entrou na nuvem — o técnico não verá no app. '
          'E-mail não foi enviado. Use Tentar de novo.';
    } else if (requiresSignature && notifyStaff) {
      lastNotifyMessage = [
        if (mailError != null && !mailSent) mailError,
        if (mailSent) 'E-mail enviado ao técnico com o anexo para assinatura.',
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      if (lastNotifyMessage!.trim().isEmpty) lastNotifyMessage = null;
    } else if (remoteError != null) {
      lastNotifyMessage =
          '${_staffDocRemoteHint(remoteError)}\n\n'
          'Arquivo não entrou na nuvem — o técnico não verá no app. '
          'Use Tentar de novo.';
    } else {
      lastNotifyMessage = null;
    }
    return doc;
  }

  String? lastNotifyMessage;

  static String _staffDocRemoteHint(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('driveapp') ||
        lower.contains('permissão') ||
        lower.contains('permission') ||
        lower.contains('mailapp')) {
      return 'Arquivo local ok; nuvem: $error\n\n'
          'No Apps Script: execute authorizeStaffDocs, aceite Drive e e-mail, '
          'depois Implantar → Nova versão.';
    }
    return 'Arquivo local ok; nuvem: $error';
  }

  Future<String?> _notifyTechnicianToSign({
    required StaffDocument doc,
    required List<int> bytes,
    String staffName = '',
  }) async {
    final to = doc.staffEmail.trim().toLowerCase();
    if (!to.contains('@')) {
      return 'Sem e-mail do técnico para enviar o anexo.';
    }
    final who = staffName.trim().isEmpty ? to : staffName.trim();
    try {
      final result = await AccountApi.instance.sendOfficeMail(
        osId: 'rh-${doc.staffEmail}',
        osNumber: 'RH - $who',
        subject: 'Documento para assinatura — ${doc.name}',
        body:
            'Olá, $who.\n\n'
            'Segue em anexo o documento "${doc.name}" para você assinar no GS Campo '
            '(Área de trabalho → Meus documentos).\n\n'
            'Depois de assinar, o RH consegue salvar na rede ou arquivar.\n\n'
            'GS Soluções Técnicas',
        to: [to],
        cc: officeRecipientEmails(),
        files: [OfficeMailFile(name: doc.name, bytes: bytes)],
      );
      if (result.sent || result.ok) return null;
      return result.error ?? 'Não enviou o e-mail ao técnico.';
    } catch (error) {
      return 'Não enviou o e-mail ao técnico. $error';
    }
  }

  Future<void> update(StaffDocument doc) async {
    _all = [
      for (final item in _all)
        if (item.id == doc.id) doc else item,
    ];
    if (doc.bytes != null && doc.bytes!.isNotEmpty) {
      await _files.save(
        ownerEmail: doc.staffEmail,
        osId: 'rh',
        fileName: '${doc.id}_${doc.name}',
        bytes: Uint8List.fromList(doc.bytes!),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markSigned({
    required StaffDocument doc,
    required String signedBy,
    required DateTime signedAt,
    Uint8List? signaturePng,
    String cargo = '',
  }) async {
    final original = await bytesOf(doc);
    if (original == null || original.isEmpty) {
      throw StateError('Arquivo não está neste aparelho.');
    }
    List<int> stampedBytes = original;
    var stampedInline = false;
    if (doc.name.toLowerCase().endsWith('.pdf')) {
      try {
        stampedBytes = await stampSignatureOnStaffPdf(
          pdfBytes: Uint8List.fromList(original),
          staffName: signedBy,
          cargo: cargo,
          signedAt: signedAt,
          signaturePng: signaturePng,
        );
        stampedInline = true;
      } catch (error) {
        debugPrint('StaffDocsStore stamp inline: $error');
        final fallback = await buildStaffSignPdf(
          staffName: signedBy,
          cargo: cargo,
          documentName: doc.name,
          signedAt: signedAt,
          signaturePng: signaturePng,
        );
        stampedBytes = fallback;
      }
    }
    final next = doc.copyWith(
      signedAt: signedAt,
      signedBy: signedBy,
      bytes: stampedBytes,
    );
    await update(next);
    try {
      if (AccountApi.useRemote) {
        await AccountApi.instance.saveStaffDoc(
          id: doc.id,
          staffEmail: doc.staffEmail,
          name: doc.name,
          bytes: stampedBytes,
          kind: doc.kind.name,
          requiresSignature: doc.requiresSignature,
          createdAt: doc.createdAt.toIso8601String(),
        );
        await AccountApi.instance.signStaffDoc(
          id: doc.id,
          signedBy: signedBy,
          signedAt: signedAt.toIso8601String(),
          signPdfBytes: stampedInline ? null : stampedBytes,
          signName: stampedInline
              ? ''
              : 'assinatura_${doc.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')}.pdf',
        );
      }
    } catch (error) {
      debugPrint('StaffDocsStore sign remote: $error');
    }
  }

  Future<String?> retryCloud(
    StaffDocument doc, {
    String staffName = '',
    bool notifyIfNeeded = true,
  }) async {
    final bytes = await bytesOf(doc);
    if (bytes == null || bytes.isEmpty) {
      return 'Arquivo não está neste aparelho.';
    }
    try {
      final saved = await AccountApi.instance.saveStaffDoc(
        id: doc.id,
        staffEmail: doc.staffEmail,
        name: doc.name,
        bytes: bytes,
        kind: doc.kind.name,
        requiresSignature: doc.requiresSignature,
        createdAt: doc.createdAt.toIso8601String(),
      );
      if (saved.ok && saved.docs.isNotEmpty) {
        final remote = StaffDocument.fromJson(saved.docs.first);
        var next = doc.copyWith(
          path: remote.path,
          cloudSynced: true,
          remoteError: '',
        );
        await update(next);
        if (notifyIfNeeded && next.needsMailRetry) {
          final mail = await _notifyTechnicianToSign(
            doc: next,
            bytes: bytes,
            staffName: staffName,
          );
          if (mail == null) {
            await update(next.copyWith(mailSent: true, mailError: ''));
            return null;
          }
          await update(next.copyWith(mailError: mail));
          return 'Salvo na nuvem, mas o e-mail falhou: $mail';
        }
        return null;
      }
      final error = saved.error ?? 'Não salvou na nuvem.';
      await update(doc.copyWith(remoteError: error));
      return _staffDocRemoteHint(error);
    } catch (error) {
      final message = '$error';
      await update(doc.copyWith(remoteError: message));
      return _staffDocRemoteHint(message);
    }
  }

  Future<String?> retryMail(StaffDocument doc, {String staffName = ''}) async {
    if (!doc.requiresSignature || doc.isSigned) return null;
    var current = byId(doc.id) ?? doc;
    if (!current.cloudSynced) {
      final cloud = await retryCloud(
        current,
        staffName: staffName,
        notifyIfNeeded: true,
      );
      current = byId(doc.id) ?? current;
      if (cloud != null) {
        return cloud.startsWith('Salvo na nuvem')
            ? cloud
            : 'Salve na nuvem antes do e-mail. $cloud';
      }
      if (current.mailSent) return null;
    }
    current = byId(doc.id) ?? current;
    if (!current.cloudSynced) {
      return 'Arquivo não entrou na nuvem — o técnico não verá no app. '
          'Use Tentar de novo na nuvem antes do e-mail.';
    }
    if (current.mailSent) return null;
    final bytes = await bytesOf(current);
    if (bytes == null || bytes.isEmpty) {
      return 'Arquivo não está neste aparelho.';
    }
    final mail = await _notifyTechnicianToSign(
      doc: current,
      bytes: bytes,
      staffName: staffName,
    );
    if (mail == null) {
      await update(current.copyWith(mailSent: true, mailError: ''));
      return null;
    }
    await update(current.copyWith(mailError: mail));
    return mail;
  }

  Future<void> deleteDoc(StaffDocument doc) async {
    if (AccountApi.useRemote && doc.id.trim().isNotEmpty) {
      try {
        await AccountApi.instance.deleteStaffDoc(doc.id);
      } catch (error) {
        debugPrint('StaffDocsStore delete remote: $error');
      }
    }
    await remove(doc.id);
  }

  Future<void> remove(String id) async {
    _all = [
      for (final item in _all)
        if (item.id != id) item,
    ];
    await _persist();
    notifyListeners();
  }

  Future<List<int>?> bytesOf(StaffDocument doc) async {
    if (doc.bytes != null && doc.bytes!.isNotEmpty) return doc.bytes;
    final local = await _files.read(doc.path);
    if (local != null && local.isNotEmpty) return local;
    if (!AccountApi.useRemote || doc.id.trim().isEmpty) return null;
    try {
      final result = await AccountApi.instance.getStaffDoc(doc.id);
      final data = result.fileData;
      if (data == null || data.isEmpty) return null;
      final bytes = base64Decode(data);
      await _files.save(
        ownerEmail: doc.staffEmail,
        osId: 'rh',
        fileName: '${doc.id}_${doc.name}',
        bytes: Uint8List.fromList(bytes),
      );
      await update(doc.copyWith(bytes: bytes));
      return bytes;
    } catch (error) {
      debugPrint('StaffDocsStore bytesOf: $error');
      return null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(
        _key,
        jsonEncode([
          for (final item in _all) item.toJson(withBytes: !item.cloudSynced),
        ]),
      );
    } catch (error) {
      debugPrint('StaffDocsStore persist: $error');
    }
  }
}
