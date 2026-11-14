import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/app_date_picker.dart';
import 'package:gs_mobile/core/technician_cargo_field.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/rdo_excel.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/data/send_os.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/attachment_rename.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const _stepNames = ['Dia', 'Fotos', 'Assinatura'];

class RdoFormPage extends StatefulWidget {
  const RdoFormPage({super.key, required this.os, this.existing});

  final SavedOs os;
  final SavedRdo? existing;

  @override
  State<RdoFormPage> createState() => _RdoFormPageState();
}

class _RdoFormPageState extends State<RdoFormPage> {
  late final TextEditingController _clockIn;
  late final TextEditingController _lunchStart;
  late final TextEditingController _lunchEnd;
  late final TextEditingController _clockOut;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _leadCargoCtrl;
  final _picker = ImagePicker();
  final _photos = <DraftFile>[];
  final _cargoByPerson = <String, String>{};
  final _absentKeys = <String>{};
  late DateTime _date;
  var _step = 0;
  var _busy = false;
  late String _responsibleName;
  late ClientBaseContact _baseSigner;

  SavedOs get _os => FieldStore.instance.byId(widget.os.id) ?? widget.os;

  bool _samePerson(String a, String b) {
    final left = personFirstKey(a);
    final right = personFirstKey(b);
    return left.isNotEmpty && left == right;
  }

  List<ClientBaseContact> _baseSignerOptions(SavedOs os) {
    final fromOs = os.rdo.resolvedBaseContacts;
    final client = ClientStore.instance.findMatch(
      cnpj: os.rdo.cnpj,
      name: os.rdo.client,
    );
    final fromClient = client?.resolvedBaseContacts ?? const <ClientBaseContact>[];
    final out = <ClientBaseContact>[];
    final seen = <String>{};
    void add(ClientBaseContact person) {
      if (!person.hasName) return;
      final key = personFirstKey(person.name);
      if (key.isEmpty || !seen.add(key)) return;
      out.add(person);
    }
    for (final person in fromOs) {
      add(person);
    }
    for (final person in fromClient) {
      add(person);
    }
    return out.take(3).toList();
  }

  ClientBaseContact _defaultBaseSigner(SavedOs os, SavedRdo? existing) {
    final options = _baseSignerOptions(os);
    final signed = existing?.clientSignedName.trim() ?? '';
    if (signed.isNotEmpty) {
      for (final person in options) {
        if (_samePerson(person.name, signed)) return person;
      }
    }
    final current = os.rdo.baseName.trim();
    if (current.isNotEmpty) {
      for (final person in options) {
        if (_samePerson(person.name, current)) return person;
      }
      return ClientBaseContact(
        name: current,
        cargo: os.rdo.baseCargo,
        email: os.rdo.baseEmail,
        phone: os.rdo.basePhone,
      );
    }
    return options.isEmpty ? const ClientBaseContact() : options.first;
  }

  void _selectBaseSigner(ClientBaseContact person) {
    setState(() => _baseSigner = person);
  }

  List<String> _responsibleOptions(SavedOs os, [String extra = '']) {
    final me = AuthSession.instance.user?.name.trim() ?? '';
    final user = AuthSession.instance.user;
    final names = <String>[];
    final seen = <String>{};

    void add(String raw) {
      final name = raw.trim();
      if (name.isEmpty || name == '-') return;
      final key = personFirstKey(name);
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      names.add(name);
    }

    // Só quem foi destinado na OS. Quem só visualiza (adm/Cleber) não entra
    // na lista — senão esquecem de desmarcar e o nome vai no RDO.
    for (final name in teamNamesForOs(os)) {
      add(name);
    }
    if (user != null &&
        me.isNotEmpty &&
        os.isAssignedToAny(assigneeKeysFor(user))) {
      add(me);
    }
    // Edição: mantém o responsável já gravado neste RDO, se houver.
    add(extra);
    return names;
  }

  String _defaultResponsible(SavedOs os, SavedRdo? existing) {
    final saved = existing?.responsibleName.trim() ?? '';
    if (saved.isNotEmpty) return saved;
    final options = _responsibleOptions(os);
    return options.isEmpty ? '' : options.first;
  }

  Map<String, String> _funcoesForLead(SavedOs os, String lead) {
    final leadKey = personFirstKey(lead);
    final map = Map<String, String>.from(os.rdo.technicianFuncoes);
    if (leadKey.isEmpty) return map;
    for (final key in map.keys.toList()) {
      if (personFirstKey(key) != leadKey &&
          map[key] == 'Responsável técnico') {
        map[key] = 'Suporte Técnico';
      }
    }
    map[leadKey] = 'Responsável técnico';
    return map;
  }

  String _leadCargo(SavedOs os, String lead) {
    final key = personFirstKey(lead);
    final edited = _cargoByPerson[key]?.trim() ?? '';
    if (edited.isNotEmpty) return edited;
    return technicianCargoFor(lead, rdo: os.rdo);
  }

  void _selectResponsible(String name) {
    final prev = personFirstKey(_responsibleName);
    if (prev.isNotEmpty) {
      _cargoByPerson[prev] = _leadCargoCtrl.text.trim();
    }
    setState(() {
      _responsibleName = name;
      _absentKeys.remove(personFirstKey(name));
      _leadCargoCtrl.text = _leadCargo(_os, name);
    });
  }

  bool _isAbsent(String name) => _absentKeys.contains(personFirstKey(name));

  List<String> _presentOptions(SavedOs os) => [
    for (final name in _responsibleOptions(os, _responsibleName))
      if (!_isAbsent(name)) name,
  ];

  void _setPresent(SavedOs os, String name, bool present) {
    final key = personFirstKey(name);
    if (key.isEmpty) return;
    if (present) {
      setState(() => _absentKeys.remove(key));
      return;
    }
    if (_samePerson(name, _responsibleName)) {
      final others = [
        for (final item in _presentOptions(os))
          if (!_samePerson(item, name)) item,
      ];
      if (others.isEmpty) {
        _toast('Pelo menos um técnico precisa ter ido neste dia.');
        return;
      }
      _absentKeys.add(key);
      _selectResponsible(others.first);
      _toast('$name saiu deste dia. Quem assina agora: ${others.first}.');
      return;
    }
    setState(() => _absentKeys.add(key));
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? DateTime.now();
    _clockIn = TextEditingController(text: existing?.clockIn ?? '');
    _lunchStart = TextEditingController(text: existing?.lunchStart ?? '');
    _lunchEnd = TextEditingController(text: existing?.lunchEnd ?? '');
    _clockOut = TextEditingController(text: existing?.clockOut ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    for (final name in existing?.absentNames ?? const <String>[]) {
      final key = personFirstKey(name);
      if (key.isNotEmpty) _absentKeys.add(key);
    }
    _responsibleName = _defaultResponsible(_os, existing);
    _baseSigner = _defaultBaseSigner(_os, existing);
    _leadCargoCtrl = TextEditingController(
      text: _leadCargo(_os, _responsibleName),
    );
    if (existing != null) {
      for (final file in existing.files) {
        final draft = DraftFile(
          name: file.name,
          kind: file.kind,
          path: file.path,
          bytes: FieldStore.instance.bytesFor(file),
          label: file.label,
        );
        if (file.kind == OsFileKind.photo) {
          _photos.add(draft);
        }
      }
    }
  }

  @override
  void dispose() {
    _clockIn.dispose();
    _lunchStart.dispose();
    _lunchEnd.dispose();
    _clockOut.dispose();
    _description.dispose();
    _notes.dispose();
    _leadCargoCtrl.dispose();
    super.dispose();
  }

  List<DraftFile> _slotPhotos(String slot) {
    final items = [
      for (final photo in _photos)
        if (photoBelongsToSlot(photo.label, slot)) photo,
    ];
    items.sort(
      (a, b) => photoSlotIndex(
        a.label,
        slot,
      ).compareTo(photoSlotIndex(b.label, slot)),
    );
    return items;
  }

  List<DraftFile> get _orphanPhotos {
    return [
      for (final photo in _photos)
        if (photoSlotLabels.every((slot) => !photoBelongsToSlot(photo.label, slot)))
          photo,
    ];
  }

  void _reindexSlot(String slot) {
    var index = 0;
    final next = <DraftFile>[];
    for (final photo in _photos) {
      if (!photoBelongsToSlot(photo.label, slot)) {
        next.add(photo);
        continue;
      }
      next.add(photo.copyWith(label: photoSlotStoredLabel(slot, index)));
      index++;
    }
    _photos
      ..clear()
      ..addAll(next);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await pickAppDate(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addSlotPhotos(
    String slot, {
    ImageSource source = ImageSource.camera,
  }) async {
    final room = photoSlotCapacity - _slotPhotos(slot).length;
    if (room <= 0) {
      _toast('Pode anexar até $photoSlotCapacity fotos em $slot.');
      return;
    }
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 75,
        );
        if (picked.isEmpty) return;
        final drafts = <DraftFile>[];
        var index = _slotPhotos(slot).length;
        for (final file in picked.take(room)) {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          final draft = await _namedSlotPhoto(
            slot: slot,
            index: index,
            originalName: file.name,
            bytes: bytes,
          );
          if (draft == null) continue;
          drafts.add(draft);
          index++;
        }
        if (drafts.isNotEmpty) setState(() => _photos.addAll(drafts));
        return;
      }
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final index = _slotPhotos(slot).length;
      if (index >= photoSlotCapacity) {
        _toast('Pode anexar até $photoSlotCapacity fotos em $slot.');
        return;
      }
      final draft = await _namedSlotPhoto(
        slot: slot,
        index: index,
        originalName: picked.name,
        bytes: bytes,
      );
      if (draft == null) return;
      setState(() => _photos.add(draft));
    } catch (_) {
      if (source == ImageSource.camera) {
        await _addSlotPhotos(slot, source: ImageSource.gallery);
        return;
      }
      _toast('Não foi possível abrir a foto.');
    }
  }

  Future<DraftFile?> _namedSlotPhoto({
    required String slot,
    required int index,
    required String originalName,
    required List<int> bytes,
  }) async {
    if (!mounted) return null;
    final label = photoSlotStoredLabel(slot, index);
    final suggested = _photoFileName(label, originalName);
    final renamed = await promptAttachmentName(
      context,
      currentName: suggested,
      title: 'Nome da foto · $slot',
      hint: photoSlotDisplayLabel(slot, index),
    );
    if (renamed == null) return null;
    return DraftFile(
      name: renamed,
      kind: OsFileKind.photo,
      bytes: bytes,
      label: label,
    );
  }

  void _removeSlotPhoto(String slot, DraftFile photo) {
    setState(() {
      _photos.remove(photo);
      _reindexSlot(slot);
    });
  }

  Future<void> _renameSlotPhoto(DraftFile photo) async {
    final renamed = await promptAttachmentName(
      context,
      currentName: photo.name,
      title: 'Renomear foto',
    );
    if (renamed == null || !mounted) return;
    final idx = _photos.indexOf(photo);
    if (idx < 0) return;
    setState(() => _photos[idx] = photo.copyWith(name: renamed));
  }

  Future<void> _openSlotAlbum(String slot) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GsTheme.paper,
      builder: (context) {
        return _SlotAlbumSheet(
          slot: slot,
          photosOf: () => _slotPhotos(slot),
          bytesOf: FieldStore.instance.bytesForDraft,
          onAdd: (source) => _addSlotPhotos(slot, source: source),
          onRemove: (photo) => _removeSlotPhoto(slot, photo),
          onRename: _renameSlotPhoto,
          onPreview: (bytes, title) => _preview(bytes, title: title),
        );
      },
    );
  }

  Future<void> _save({bool download = false, bool email = false}) async {
    if (_busy) return;
    if (_description.text.trim().isEmpty) {
      setState(() => _step = 0);
      _toast('Descreva o serviço do dia.');
      return;
    }
    setState(() => _busy = true);
    try {
      final os = _os;
      final signedBy = AuthSession.instance.user?.name.trim() ?? '';
      final user = AuthSession.instance.user;
      final assignedViewer = user != null &&
          os.isAssignedToAny(assigneeKeysFor(user));
      final presentTeam = [
        for (final name in teamNamesForOs(
          os,
          signedBy: assignedViewer ? signedBy : '',
        ))
          if (name != '-' && !_isAbsent(name)) name,
      ];
      final teamNames = presentTeam.isEmpty ? const ['-'] : presentTeam;
      final absentNames = [
        for (final name in _responsibleOptions(os, _responsibleName))
          if (_isAbsent(name)) name,
      ];
      final lead = _responsibleName.trim().isNotEmpty
          ? _responsibleName.trim()
          : (teamNames.first != '-'
              ? teamNames.first
              : (assignedViewer ? signedBy : ''));
      if (lead.isEmpty) {
        setState(() {
          _busy = false;
          _step = 2;
        });
        _toast('Escolha o responsável técnico deste RDO.');
        return;
      }
      final cargo = _leadCargoCtrl.text.trim().isEmpty
          ? _leadCargo(os, lead)
          : _leadCargoCtrl.text.trim();
      final leadKey = personFirstKey(lead);
      if (leadKey.isNotEmpty) _cargoByPerson[leadKey] = cargo;
      final teamCargos = snapshotTechnicianCargos(
        os,
        [lead, ...teamNames],
        overrides: _cargoByPerson,
      );
      if (leadKey.isNotEmpty) teamCargos[leadKey] = cargo;
      await persistTechnicianCargo(lead, cargo);
      final signedAt = DateTime.now();
      final day = SavedRdo(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: _date,
        clockIn: _clockIn.text.trim(),
        lunchStart: _lunchStart.text.trim(),
        lunchEnd: _lunchEnd.text.trim(),
        clockOut: _clockOut.text.trim(),
        description: _description.text.trim(),
        notes: _notes.text.trim(),
        files: const [],
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        responsibleName: lead,
        signedAt: signedAt,
        clientSignedName: widget.existing?.clientSignedName ?? '',
        clientSignedAt: widget.existing?.clientSignedAt,
        signToken: widget.existing?.signToken ?? '',
        absentNames: absentNames,
      );
      final header = os.rdo
          .copyWith(technicianCargos: teamCargos)
          .withBaseContact(_baseSigner);
      final pdfBytes = await buildRdoPdf(
        osNumber: os.number,
        technicianName: uniquePersonNames(
          [lead, ...teamNames].join(', '),
        ),
        rdo: header.mergedWithDay(day),
        date: _date,
        signerName: header.baseName,
        responsibleName: lead,
        teamFuncoes: _funcoesForLead(os, lead),
        teamCargos: teamCargos,
        signedAt: signedAt,
        clientSignedAt: widget.existing?.clientSignedAt,
        withSignature: true,
        photos: [
          for (final photo in _photos)
            if (FieldStore.instance.bytesForDraft(photo) case final bytes?
                when bytes.isNotEmpty)
              RdoPdfPhoto(
                label: (photo.label ?? '').trim().isEmpty
                    ? photo.name
                    : photo.label!,
                bytes: bytes,
              ),
        ],
      );
      final rdoFile = DraftFile(
        name: rdoFileName(os.number, _date),
        kind: OsFileKind.rdo,
        bytes: pdfBytes,
      );
      final saved = await FieldStore.instance.saveRdo(
        osId: os.id,
        draft: day,
        files: [..._photos, rdoFile],
        technicianCargos: teamCargos,
        baseSigner: _baseSigner,
      );
      final entry = saved.rdos.where((item) => item.id == day.id).firstOrNull;
      final inDrive = entry == null
          ? Future.value(false)
          : autoSaveRdoToDrive(saved, entry);
      if (!mounted) return;
      if (email) {
        await showSendRdoSheet(context, saved, rdoIds: [day.id]);
        if (!mounted) return;
      } else if (download) {
        await downloadRdoFile(fileName: rdoFile.name, bytes: pdfBytes);
        if (!mounted) return;
        _toast('RDO do dia salvo e pronto para baixar.');
      } else {
        final drive = await inDrive;
        if (!mounted) return;
        _toast(
          'RDO de ${DateFormat('dd/MM/yyyy').format(_date)} salvo na OS ${saved.number}.'
          '${driveSavedSuffix(drive)}',
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Não foi possível salvar o RDO. $error');
    }
  }

  void _preview(List<int> bytes, {String title = 'Foto'}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: GsTheme.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final os = _os;
    return Scaffold(
      appBar: AppBar(
        title: Text('RDO · OS ${os.number}'),
      ),
      body: Column(
        children: [
          _StepHeader(step: _step),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _buildDayStep(os),
                _buildPhotosStep(),
                _buildSignStep(os),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildDayStep(SavedOs os) {
    final signedBy = AuthSession.instance.user?.name.trim() ?? '';
    final user = AuthSession.instance.user;
    final assignedViewer = user != null &&
        os.isAssignedToAny(assigneeKeysFor(user));
    final team = [
      for (final name in teamNamesForOs(
        os,
        signedBy: assignedViewer ? signedBy : '',
      ))
        if (name != '-' && !_isAbsent(name)) name,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DADOS DA OS · JÁ PREENCHIDOS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.brass,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OS ${os.number}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              if (os.rdo.client.isNotEmpty)
                Text(
                  os.rdo.client,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: GsTheme.navy,
                  ),
                ),
              if (os.rdo.cnpj.isNotEmpty)
                Text(
                  'CNPJ ${os.rdo.cnpj}',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
                ),
              if (os.rdo.site.isNotEmpty)
                Text(
                  os.rdo.site,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
                ),
              if (os.rdo.service.isNotEmpty)
                Text(
                  os.rdo.service,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Lançamento do dia',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Só horário, data, descrição e informações adicionais. Depois assine e salve. Amanhã é outro RDO nesta mesma OS. Sem serviço no dia, deixe o horário em branco — não conta hora extra.',
          style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
        ),
        if (team.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Equipe neste serviço: ${team.join(', ')}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GsTheme.navy,
            ),
          ),
          Text(
            _responsibleName.trim().isEmpty
                ? 'Na assinatura você escolhe quem é o responsável técnico deste dia.'
                : 'Responsável técnico neste RDO: $_responsibleName. Dá para trocar na hora de assinar.',
            style: const TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
          ),
        ],
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data do serviço'),
          subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _clockIn,
                decoration: const InputDecoration(
                  labelText: 'Entrada',
                  hintText: '08:00',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lunchStart,
                decoration: const InputDecoration(
                  labelText: 'Almoço',
                  hintText: '12:00',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lunchEnd,
                decoration: const InputDecoration(
                  labelText: 'Retorno',
                  hintText: '13:00',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _clockOut,
                decoration: const InputDecoration(
                  labelText: 'Saída',
                  hintText: '17:00',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('rdo-description'),
          controller: _description,
          minLines: 4,
          maxLines: 16,
          decoration: const InputDecoration(labelText: 'Descrição do serviço'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Informações adicionais',
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildPhotosStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const Text(
          'Fotos do dia',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Opcional. Até 4 fotos em cada quadro. A primeira fica com o nome do item; as outras entram como Anexo 1, 2 e 3.',
          style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final slot in photoSlotLabels)
              _PhotoSlot(
                title: slot,
                previews: [
                  for (final photo in _slotPhotos(slot))
                    FieldStore.instance.bytesForDraft(photo),
                ].whereType<Uint8List>().toList(),
                onAdd: _busy ? null : () => _addSlotPhotos(slot),
                onGallery: _busy
                    ? null
                    : () => _addSlotPhotos(slot, source: ImageSource.gallery),
                onOpen: _busy
                    ? () {}
                    : () {
                        if (_slotPhotos(slot).isEmpty) {
                          _addSlotPhotos(slot);
                          return;
                        }
                        _openSlotAlbum(slot);
                      },
              ),
          ],
        ),
        if (_orphanPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in _orphanPhotos)
                _ExtraPhoto(
                  bytes: FieldStore.instance.bytesForDraft(photo),
                  onOpen: () {
                    final bytes = FieldStore.instance.bytesForDraft(photo);
                    if (bytes != null) _preview(bytes, title: photo.name);
                  },
                  onRemove: _busy
                      ? null
                      : () => setState(() => _photos.remove(photo)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSignStep(SavedOs os) {
    final lead = _responsibleName.trim();
    final cargo = _leadCargoCtrl.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const Text(
          'Assinatura eletrônica',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Escolha quem fez o relatório. O PDF recebe o bloco eletrônico com o nome dessa pessoa, o cargo dela e a data. Não precisa desenhar. Certificado digital da empresa continua no Adobe.',
          style: TextStyle(fontSize: 16, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Quem trabalhou neste dia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Só os técnicos destinários da OS. Desmarque quem não foi neste dia: sai do RDO e não conta horas.',
          style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 10),
        for (final name in _responsibleOptions(os, _responsibleName)) ...[
          Material(
            color: Colors.white,
            child: CheckboxListTile(
              key: Key('rdo-presente-${personFirstKey(name)}'),
              value: !_isAbsent(name),
              onChanged: (value) => _setPresent(os, name, value ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: GsTheme.navy,
              shape: Border.all(color: const Color(0x331A2330)),
              title: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _isAbsent(name)
                      ? const Color(0xFF8A9099)
                      : GsTheme.navy,
                  decoration: _isAbsent(name)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: _isAbsent(name)
                  ? const Text('Ausente neste dia')
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const Text(
          'Técnico que fez este RDO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'O nome na assinatura muda conforme a seleção. Cada dia pode ser uma pessoa da equipe.',
          style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 10),
        for (final name in _presentOptions(os)) ...[
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _selectResponsible(name),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _samePerson(_responsibleName, name)
                        ? GsTheme.brass
                        : const Color(0x331A2330),
                    width: _samePerson(_responsibleName, name) ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _samePerson(_responsibleName, name)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: GsTheme.navy,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                        ),
                      ),
                    ),
                    if (_samePerson(
                      name,
                      AuthSession.instance.user?.name ?? '',
                    ))
                      const Text(
                        'você',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GsTheme.brass,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        TechnicianCargoField(
          controller: _leadCargoCtrl,
          enabled: lead.isNotEmpty,
          label: 'Cargo desta pessoa no RDO',
          helperText:
              'Cada técnico tem o próprio cargo (níveis do quadro). Salvar grava no cadastro dele.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ElectronicSignatureCard(
          title: 'Prévia no PDF · técnico',
          name: lead.isEmpty ? 'Nome do funcionário' : lead,
          cargo: cargo,
        ),
        const SizedBox(height: 18),
        const Text(
          'Responsável da base neste RDO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Escolha quem assina pelo cliente. Cadastre até 3 pessoas no cliente.',
          style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 10),
        if (_baseSignerOptions(os).isEmpty)
          const Text(
            'Nenhum responsável cadastrado neste cliente. Inclua no cadastro do cliente ou na OS.',
            style: TextStyle(fontSize: 15, color: Color(0xFF8A3B3B)),
          )
        else
          for (final person in _baseSignerOptions(os)) ...[
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => _selectBaseSigner(person),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _samePerson(_baseSigner.name, person.name)
                          ? GsTheme.brass
                          : const Color(0x331A2330),
                      width: _samePerson(_baseSigner.name, person.name) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _samePerson(_baseSigner.name, person.name)
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: GsTheme.navy,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: GsTheme.navy,
                              ),
                            ),
                            if (person.cargo.trim().isNotEmpty)
                              Text(
                                person.cargo,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5C6570),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 10),
        OpenClientSignCard(
          name: _baseSigner.name,
          cargo: _baseSigner.cargo,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: _step < 2
              ? Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _step -= 1),
                          child: const Text('Voltar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _step += 1),
                        style: FilledButton.styleFrom(
                          backgroundColor: GsTheme.navy,
                        ),
                        child: const Text('Continuar'),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _save(),
                      style: FilledButton.styleFrom(
                        backgroundColor: GsTheme.brass,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(_busy ? 'Aguarde…' : 'Salvar RDO do dia'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _save(email: true),
                      icon: const Icon(Icons.email_outlined),
                      style: FilledButton.styleFrom(
                        backgroundColor: GsTheme.navy,
                      ),
                      label: Text(
                        _busy ? 'Aguarde…' : 'Salvar e enviar RDO',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _save(download: true),
                      icon: const Icon(Icons.download),
                      label: const Text('Salvar e baixar PDF'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _step -= 1),
                      child: const Text('Voltar'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _photoFileName(String? label, String original) {
  final ext = original.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
  final slug = (label ?? 'servico').toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  return 'foto_${slug}_${DateTime.now().millisecondsSinceEpoch}.$ext';
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Text(
            'Passo ${step + 1} de 3 · ${_stepNames[step]}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    color: i <= step ? GsTheme.brass : const Color(0x331A2330),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.title,
    required this.previews,
    required this.onOpen,
    this.onAdd,
    this.onGallery,
  });

  final String title;
  final List<Uint8List> previews;
  final VoidCallback? onAdd;
  final VoidCallback? onGallery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final filled = previews.isNotEmpty;
    final canAdd = filled && previews.length < photoSlotCapacity;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: filled ? onOpen : onAdd,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: filled ? GsTheme.brass : const Color(0x331A2330),
              width: filled ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (filled)
                Positioned.fill(child: _SlotMosaic(previews: previews))
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          color: GsTheme.navy,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: GsTheme.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (filled)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: const Color(0xCC0C1F33),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      '$title · ${previews.length}/$photoSlotCapacity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (!filled || canAdd)
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    tooltip: 'Galeria',
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    color: filled ? Colors.white : GsTheme.navy,
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: filled
                      ? (canAdd ? 'Adicionar foto' : 'Ver fotos')
                      : 'Tirar foto',
                  color: filled ? Colors.white : GsTheme.navy,
                  onPressed: filled
                      ? (canAdd ? onAdd : onOpen)
                      : onAdd,
                  icon: Icon(
                    filled
                        ? (canAdd
                              ? Icons.add_a_photo_outlined
                              : Icons.collections_outlined)
                        : Icons.add_a_photo_outlined,
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

class _SlotMosaic extends StatelessWidget {
  const _SlotMosaic({required this.previews});

  final List<Uint8List> previews;

  @override
  Widget build(BuildContext context) {
    if (previews.length == 1) {
      return Image.memory(previews.first, fit: BoxFit.cover);
    }
    Widget cell(int index) {
      if (index >= previews.length) {
        return const ColoredBox(color: Color(0x221A2330));
      }
      return Image.memory(previews[index], fit: BoxFit.cover);
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(0)),
              const SizedBox(width: 1),
              Expanded(child: cell(1)),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(2)),
              const SizedBox(width: 1),
              Expanded(child: cell(3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotAlbumSheet extends StatefulWidget {
  const _SlotAlbumSheet({
    required this.slot,
    required this.photosOf,
    required this.bytesOf,
    required this.onAdd,
    required this.onRemove,
    required this.onRename,
    required this.onPreview,
  });

  final String slot;
  final List<DraftFile> Function() photosOf;
  final Uint8List? Function(DraftFile) bytesOf;
  final Future<void> Function(ImageSource source) onAdd;
  final void Function(DraftFile photo) onRemove;
  final Future<void> Function(DraftFile photo) onRename;
  final void Function(Uint8List bytes, String title) onPreview;

  @override
  State<_SlotAlbumSheet> createState() => _SlotAlbumSheetState();
}

class _SlotAlbumSheetState extends State<_SlotAlbumSheet> {
  var _busy = false;

  Future<void> _add(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onAdd(source);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photosOf();
    final canAdd = photos.length < photoSlotCapacity;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.slot,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Até $photoSlotCapacity fotos. Dê um nome claro em cada foto '
              '(ex.: plaqueta, TAG). A primeira fica ligada a ${widget.slot.toLowerCase()}.',
              style: const TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
              children: [
                for (var i = 0; i < photos.length; i++)
                  _AlbumThumb(
                    title: attachmentStem(photos[i].name).isNotEmpty
                        ? attachmentStem(photos[i].name)
                        : photoSlotDisplayLabel(widget.slot, i),
                    bytes: widget.bytesOf(photos[i]),
                    onOpen: () {
                      final bytes = widget.bytesOf(photos[i]);
                      if (bytes != null) {
                        widget.onPreview(
                          bytes,
                          attachmentStem(photos[i].name),
                        );
                      }
                    },
                    onRename: _busy
                        ? null
                        : () async {
                            await widget.onRename(photos[i]);
                            if (mounted) setState(() {});
                          },
                    onRemove: _busy
                        ? null
                        : () {
                            widget.onRemove(photos[i]);
                            setState(() {});
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || !canAdd
                        ? null
                        : () => _add(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeria'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy || !canAdd
                        ? null
                        : () => _add(ImageSource.camera),
                    style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(canAdd ? 'Tirar foto' : 'Limite 4'),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AlbumThumb extends StatelessWidget {
  const _AlbumThumb({
    required this.title,
    required this.onOpen,
    this.bytes,
    this.onRename,
    this.onRemove,
  });

  final String title;
  final Uint8List? bytes;
  final VoidCallback onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x331A2330)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: bytes == null
                    ? const Icon(Icons.image_outlined, color: GsTheme.navy)
                    : Image.memory(bytes!, fit: BoxFit.cover),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0xCC0C1F33),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onRename != null)
                      IconButton(
                        tooltip: 'Renomear',
                        onPressed: onRename,
                        icon: const Icon(
                          Icons.drive_file_rename_outline,
                          color: Colors.white,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Remover',
                      onPressed: onRemove,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraPhoto extends StatelessWidget {
  const _ExtraPhoto({required this.onOpen, this.bytes, this.onRemove});

  final Uint8List? bytes;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onOpen,
              child: ColoredBox(
                color: Colors.white,
                child: bytes == null
                    ? const Icon(Icons.image_outlined)
                    : Image.memory(bytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
