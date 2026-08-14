import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/catalog.dart';
import 'package:gs_mobile/demo/inbox.dart';
import 'package:gs_mobile/demo/office_sync.dart';

class OsDetailPage extends StatefulWidget {
  const OsDetailPage({super.key, required this.os});

  final DemoWorkOrder os;

  @override
  State<OsDetailPage> createState() => _OsDetailPageState();
}

class _OsDetailPageState extends State<OsDetailPage> {
  late final TextEditingController _notes;
  late final TextEditingController _clockIn;
  late final TextEditingController _lunchStart;
  late final TextEditingController _lunchEnd;
  late final TextEditingController _clockOut;
  late final TextEditingController _certNumber;
  var _accepted = false;
  var _signed = false;
  var _sent = false;
  var _busy = false;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _contentType;

  @override
  void initState() {
    super.initState();
    final os = widget.os;
    _notes = TextEditingController(text: os.description);
    _clockIn = TextEditingController(text: os.clockIn);
    _lunchStart = TextEditingController(text: os.lunchStart);
    _lunchEnd = TextEditingController(text: os.lunchEnd);
    _clockOut = TextEditingController(text: os.clockOut);
    _certNumber = TextEditingController(
      text: os.canAttachCertificate ? OfficeInbox.instance.peekNumber() : '',
    );
    _accepted = os.id == 'os-036';
  }

  @override
  void dispose() {
    _notes.dispose();
    _clockIn.dispose();
    _lunchStart.dispose();
    _lunchEnd.dispose();
    _clockOut.dispose();
    _certNumber.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'xls', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _contentType = _typeForName(file.name);
    });
  }

  void _attachDemoSheet() {
    final number = _certNumber.text.trim().isEmpty
        ? OfficeInbox.instance.peekNumber()
        : _certNumber.text.trim();
    final name = 'CERTIFICADO $number.xlsx';
    setState(() {
      _certNumber.text = number;
      _fileName = name;
      _fileBytes = Uint8List.fromList(
        'Planilha GS · $name · ${widget.os.number}'.codeUnits,
      );
      _contentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    });
  }

  Future<void> _sendAttachment() async {
    final bytes = _fileBytes;
    final name = _fileName;
    final number = _certNumber.text.trim();
    if (_busy || bytes == null || name == null || number.isEmpty) return;
    setState(() => _busy = true);
    OfficeInbox.instance.addFromField(
      FieldCertificate(
        number: number,
        workOrderId: widget.os.id,
        workOrderNumber: widget.os.number,
        client: widget.os.client,
        instrument: widget.os.instrument,
        issuedAt: widget.os.date,
        sentToOffice: false,
        fileName: name,
        fileBytes: bytes,
        contentType: _contentType,
      ),
    );
    final ok = await OfficeSync.pushCertificate(
      os: widget.os,
      certNumber: number,
      fileName: name,
      bytes: bytes,
      contentType: _contentType ?? 'application/octet-stream',
    );
    if (!mounted) return;
    if (ok) {
      OfficeInbox.instance.markSent(number);
      setState(() {
        _sent = true;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Certificado $number anexado. Ele caiu em Certificados no sistema web.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          'Anexo ficou no aparelho. Ligue o sistema web em localhost:3000 e envie de novo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final os = widget.os;
    return Scaffold(
      appBar: AppBar(title: Text(os.number)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            os.client,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${os.site} · ${os.city}\n${os.service}',
            style: const TextStyle(color: Color(0xFF5C6570), height: 1.4),
          ),
          const SizedBox(height: 12),
          Text('Equipe: ${os.team}'),
          Text('OC ${os.oc}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0x140C1F33),
            child: Text('GPS da chegada: ${os.gps}'),
          ),
          const SizedBox(height: 16),
          if (!_accepted)
            FilledButton(
              onPressed: () => setState(() => _accepted = true),
              style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
              child: const Text('Aceitar e iniciar deslocamento'),
            )
          else ...[
            const _Label('Registros do dia'),
            Row(
              children: [
                Expanded(child: _TimeField(label: 'Entrada', controller: _clockIn)),
                const SizedBox(width: 8),
                Expanded(child: _TimeField(label: 'Almoço', controller: _lunchStart)),
                const SizedBox(width: 8),
                Expanded(child: _TimeField(label: 'Retorno', controller: _lunchEnd)),
                const SizedBox(width: 8),
                Expanded(child: _TimeField(label: 'Saída', controller: _clockOut)),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Descrição do serviço'),
            TextField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Fotos'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: os.photos
                  .map(
                    (label) => Container(
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(10),
                      color: GsTheme.navy,
                      child: Text(
                        'Foto · $label',
                        style: const TextStyle(
                          color: GsTheme.paper,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const _Label('Assinatura da base'),
            GestureDetector(
              onTap: () => setState(() => _signed = true),
              child: Container(
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: GsTheme.brass),
                ),
                child: Text(
                  _signed ? os.signer : 'Toque para coletar assinatura',
                  style: TextStyle(
                    fontStyle: _signed ? FontStyle.italic : FontStyle.normal,
                    fontSize: _signed ? 22 : 14,
                    color: GsTheme.navy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (os.canAttachCertificate) ...[
              const _Label('Certificado (planilha Excel)'),
              TextField(
                controller: _certNumber,
                decoration: const InputDecoration(
                  labelText: 'Número do certificado',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GsTheme.navy,
                    side: const BorderSide(color: GsTheme.navy),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: Text(_fileName ?? 'Anexar planilha do certificado'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _attachDemoSheet,
                child: const Text('Usar CERTIFICADO TESTE.xlsx (demonstração)'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _signed && _fileName != null && !_busy
                      ? _sendAttachment
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: GsTheme.brass,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0x55C59E39),
                  ),
                  child: Text(
                    _busy
                        ? 'Enviando ao escritório…'
                        : _sent
                            ? 'Certificado ${_certNumber.text} no escritório'
                            : 'Enviar anexo ao escritório',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O certificado continua sendo feito no Excel. O app só anexa o arquivo e sobe com os registros da OS.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
              ),
            ] else
              const Text(
                'Esta OS não exige certificado de calibração.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
              ),
          ],
        ],
      ),
    );
  }

  String _typeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.xlsm')) {
      return 'application/vnd.ms-excel.sheet.macroEnabled.12';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          color: Color(0xFF5C6570),
        ),
      ),
    );
  }
}
