import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_job_page.dart';
import 'package:gs_mobile/features/os/calibration_slots_group.dart';

/// Fluxo "Gerar certificado pela OS" em página dedicada.
/// Voltar do certificado mantém a lista/pesquisa (não fecha como modal).
class CalibrationFromOsPage extends StatefulWidget {
  const CalibrationFromOsPage({super.key, this.osId});

  /// Quando vem de uma OS aberta, entra direto nos certificados dela.
  final String? osId;

  @override
  State<CalibrationFromOsPage> createState() => _CalibrationFromOsPageState();
}

class _CalibrationFromOsPageState extends State<CalibrationFromOsPage> {
  final _osQuery = TextEditingController();
  final _slotQuery = TextEditingController();
  var _busy = false;
  var _step = 0; // 0=OS, 1=tipo, 2=certificados
  List<SavedOs> _orders = const [];
  SavedOs? _os;
  CalibrationKind? _kind;
  List<CalibrationSlotGroup> _groups = const [];
  List<OsCalibrationSlot> _slotsOfKind = const [];
  var _selecting = false;
  final _selected = <String>{};

  bool get _canDeleteSlots =>
      AuthSession.instance.user?.canGenerateOs == true &&
      _os != null &&
      !_os!.isClosed;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _osQuery.dispose();
    _slotQuery.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final user = AuthSession.instance.user;
      if (user != null) {
        FieldStore.instance.applyViewerAccess(seeAll: user.seesAllFieldOs);
      }
      try {
        await FieldStore.instance.sync().timeout(const Duration(seconds: 25));
      } catch (_) {}
      try {
        await FieldStore.instance.hydrateMissingCalibrationSlots().timeout(
          const Duration(seconds: 45),
        );
      } catch (_) {}
      try {
        await CalibrationStore.instance.sync().timeout(
          const Duration(seconds: 30),
        );
      } catch (_) {}
      if (!mounted) return;
      final orders = _ordersWithSlots();
      setState(() {
        _orders = orders;
        _busy = false;
      });
      final wanted = widget.osId?.trim() ?? '';
      if (wanted.isEmpty) return;
      SavedOs? match;
      for (final os in orders) {
        if (os.id == wanted) {
          match = os;
          break;
        }
      }
      match ??= FieldStore.instance.byId(wanted);
      if (match != null && mounted) {
        await _pickOs(match);
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<SavedOs> _ordersWithSlots() {
    return [
      for (final os in FieldStore.instance.items)
        if (os.calibrationSlots.isNotEmpty) os,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  String _cloudLaterMessage(CloudSyncException error) =>
      'Certificado salvo neste aparelho. A nuvem não respondeu agora '
      '($error) — será enviado na próxima vez que a OS for salva.';

  List<SavedOs> get _filteredOrders {
    final q = _osQuery.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return [
      for (final os in _orders)
        if ('${os.number} ${os.rdo.client} ${os.rdo.site} ${osStatusLabel(os.status)}'
            .toLowerCase()
            .contains(q))
          os,
    ];
  }

  List<OsCalibrationSlot> get _filteredSlots {
    final q = _slotQuery.text.trim().toLowerCase();
    if (q.isEmpty) return _slotsOfKind;
    return [
      for (final slot in _slotsOfKind)
        if (_slotSearchText(slot).toLowerCase().contains(q)) slot,
    ];
  }

  CalibrationJob? _jobOf(OsCalibrationSlot slot) =>
      CalibrationStore.instance.jobForSlot(
        slot,
        osId: _os?.id,
        osNumber: _os?.number,
      );

  /// Busca só no que a linha mostra; senão "hidratado" acha certificado
  /// de gasolina por causa de um campo antigo escondido.
  String _slotSearchText(OsCalibrationSlot slot) =>
      '${slot.certificateNumber} '
      '${osCalibrationSlotDetailLine(slot, job: _jobOf(slot))}';

  Future<void> _pickOs(SavedOs os) async {
    setState(() => _busy = true);
    try {
      var hydrated = await FieldStore.instance.hydrateOs(os.id) ?? os;
      if (hydrated.calibrationSlots.isEmpty) {
        _toast(
          'OS ${hydrated.number} está sem certificados no aparelho/nuvem.',
        );
        return;
      }
      // NÃO grava dedupe aqui — só lista única em memória (não apaga slots).
      final unique = dedupeCalibrationSlotsByCertificateNumber(
        hydrated.calibrationSlots,
      );
      if (unique.length != hydrated.calibrationSlots.length) {
        _toast(
          'Há ${hydrated.calibrationSlots.length - unique.length} '
          'número(s) duplicado(s) nesta OS — abrindo sem apagar.',
        );
      }
      await CalibrationStore.instance.load();
      final groups = groupCalibrationSlotsByKind(hydrated.calibrationSlots);
      if (groups.isEmpty) {
        _toast('Nenhum certificado nesta OS.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _os = hydrated;
        _groups = groups;
        _kind = groups.length == 1 ? groups.first.kind : null;
        _step = groups.length == 1 ? 2 : 1;
        if (_kind != null) {
          _slotsOfKind = [
            for (final slot in hydrated.calibrationSlots)
              if (calibrationKindFrom(slot.kind) == _kind) slot,
          ];
        }
        _slotQuery.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pickKind(CalibrationKind kind) {
    final os = _os;
    if (os == null) return;
    setState(() {
      _kind = kind;
      _slotsOfKind = [
        for (final slot in os.calibrationSlots)
          if (calibrationKindFrom(slot.kind) == kind) slot,
      ];
      _step = 2;
      _slotQuery.clear();
    });
  }

  /// Volta da calibração: o certificado pode ter saído da OS.
  void _reloadOs() {
    final current = _os;
    if (current == null) return;
    final os = FieldStore.instance.byId(current.id) ?? current;
    final kind = _kind;
    setState(() {
      _os = os;
      _groups = groupCalibrationSlotsByKind(os.calibrationSlots);
      _slotsOfKind = [
        for (final slot in os.calibrationSlots)
          if (calibrationKindFrom(slot.kind) == kind) slot,
      ];
    });
  }

  Future<void> _openSlot(OsCalibrationSlot slot) async {
    final os = _os;
    if (os == null) return;
    final existing = CalibrationStore.instance.jobForSlot(
      slot,
      osId: os.id,
      osNumber: os.number,
    );
    if (existing != null) {
      if (slot.jobId.trim() != existing.id) {
        final nextSlots = [
          for (final item in os.calibrationSlots)
            if (item.id == slot.id) item.copyWith(jobId: existing.id) else item,
        ];
        try {
          final saved = await FieldStore.instance.saveCalibrationSlots(
            osId: os.id,
            slots: nextSlots,
          );
          if (mounted) setState(() => _os = saved);
        } on CloudSyncException catch (error) {
          if (mounted) {
            setState(() => _os = FieldStore.instance.byId(os.id) ?? os);
            _toast(_cloudLaterMessage(error));
          }
        }
      }
      // Restaura produto do slot/cadastro se o job estiver sem fluido.
      if (existing.fluid.trim().isEmpty) {
        final restored = restoreEmptyFluidFromSources(
          existing,
          slot: slot,
        );
        if (restored.fluid.trim().isNotEmpty) {
          await CalibrationStore.instance.save(
            restored,
            pushRemote: true,
          );
        }
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CalibrationJobPage(jobId: existing.id),
        ),
      );
      if (mounted) _reloadOs();
      return;
    }

    final user = AuthSession.instance.user;
    final plannedNumber = slot.certificateNumber.trim();
    var job = jobFromOsCalibrationSlot(
      os: os,
      slot: slot,
      technicianName: preferredCalibrationTechnician(
        osTechnicianName: os.technicianName,
        userName: user?.name ?? '',
        userIsDeveloper: user?.isDeveloper == true,
      ),
    );
    setState(() => _busy = true);
    try {
      job = await CalibrationStore.instance.save(job);
      final renumbered =
          plannedNumber.isNotEmpty &&
          job.number.trim().isNotEmpty &&
          job.number.trim().toLowerCase() != plannedNumber.toLowerCase();
      final nextSlots = [
        for (final item in os.calibrationSlots)
          if (item.id == slot.id)
            item.copyWith(
              jobId: job.id,
              // Mantém lista alinhada ao nº real do certificado (após renumerar).
              certificateNumber: job.number.trim().isNotEmpty
                  ? job.number.trim()
                  : item.certificateNumber,
              // Só grava N/S se o slot/job já tiver — não inventa do cadastro.
              serialNumber: job.serialNumber.trim().isNotEmpty
                  ? job.serialNumber
                  : item.serialNumber,
              equipmentTag: job.equipmentTag.trim().isNotEmpty
                  ? job.equipmentTag
                  : item.equipmentTag,
            )
          else
            item,
      ];
      String? cloudError;
      SavedOs saved;
      try {
        saved = await FieldStore.instance.saveCalibrationSlots(
          osId: os.id,
          slots: nextSlots,
        );
      } on CloudSyncException catch (error) {
        cloudError = _cloudLaterMessage(error);
        saved = FieldStore.instance.byId(os.id) ?? os;
      }
      if (mounted) {
        setState(() => _os = saved);
        if (renumbered) {
          _toast(
            'Nº $plannedNumber já estava em uso. '
            'Certificado aberto como ${job.number}.',
          );
        } else if (cloudError != null) {
          _toast(cloudError);
        }
      }
    } catch (error) {
      if (mounted) _toast('$error');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationJobPage(jobId: job.id),
      ),
    );
    if (mounted) _reloadOs();
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _selectSpares() {
    final os = _os;
    if (os == null) return;
    setState(() {
      for (final slot in _filteredSlots) {
        if (calibrationSlotIsOrphanWithoutJob(slot, job: _jobOf(slot))) {
          _selected.add(slot.id);
        }
      }
    });
    if (_selected.isEmpty) _toast('Nenhum sobressalente nesta lista.');
  }

  Future<void> _deleteSelected() async {
    final os = _os;
    if (os == null || _selected.isEmpty) return;
    final chosen = [
      for (final slot in os.calibrationSlots)
        if (_selected.contains(slot.id)) slot,
    ];
    final jobs = <CalibrationJob>[
      for (final slot in chosen)
        if (_jobOf(slot) case final job?) job,
    ];
    final filled = jobs
        .where(
          (job) =>
              job.status == CalibrationJobStatus.done || job.hasMeasurements,
        )
        .map((job) => job.number)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar ${chosen.length} certificado(s)?'),
        content: Text(
          [
            'Sai${chosen.length == 1 ? '' : 'em'} da OS ${os.number}: '
                '${chosen.map((s) => s.certificateNumber).join(', ')}.',
            if (filled.isNotEmpty)
              'ATENÇÃO: ${filled.join(', ')} já ${filled.length == 1 ? 'tem' : 'têm'} '
                  'medições e ${filled.length == 1 ? 'será apagado' : 'serão apagados'} junto.',
            'Não dá para desfazer.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('os-cal-apagar-selecionados-confirmar'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A1F1F),
            ),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    String? cloudError;
    try {
      final next = [
        for (final slot in os.calibrationSlots)
          if (!_selected.contains(slot.id)) slot,
      ];
      try {
        await FieldStore.instance.saveCalibrationSlots(
          osId: os.id,
          slots: next,
        );
      } on CloudSyncException catch (error) {
        cloudError = '$error';
      }
      for (final job in jobs) {
        await CalibrationStore.instance.delete(job.id);
      }
      if (!mounted) return;
      final updated = FieldStore.instance.byId(os.id) ?? os;
      final kind = _kind;
      setState(() {
        _os = updated;
        _groups = groupCalibrationSlotsByKind(updated.calibrationSlots);
        _slotsOfKind = [
          for (final slot in updated.calibrationSlots)
            if (calibrationKindFrom(slot.kind) == kind) slot,
        ];
        _selecting = false;
        _selected.clear();
      });
      _toast(
        cloudError == null
            ? '${chosen.length} certificado(s) apagado(s).'
            : '${chosen.length} certificado(s) apagado(s) neste aparelho. '
                '$cloudError',
      );
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBackStep() {
    if (_selecting) {
      _stopSelecting();
      return;
    }
    final lockedToOs = widget.osId?.trim().isNotEmpty == true;
    if (_step == 2 && _groups.length > 1) {
      setState(() {
        _step = 1;
        _kind = null;
        _slotsOfKind = const [];
      });
      return;
    }
    if (lockedToOs) {
      Navigator.of(context).pop();
      return;
    }
    if (_step >= 1) {
      setState(() {
        _step = 0;
        _os = null;
        _kind = null;
        _groups = const [];
        _slotsOfKind = const [];
        _orders = _ordersWithSlots();
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Certificado pela OS'
              : _step == 1
              ? 'Tipo · OS ${_os?.number ?? ''}'
              : '${_kind == null ? 'Certificados' : calibrationKindLabel(_kind!)} · OS ${_os?.number ?? ''}',
        ),
        leading: IconButton(
          icon: Icon(_selecting ? Icons.close : Icons.arrow_back),
          onPressed: _goBackStep,
        ),
        actions: [
          if (_step == 2 && _canDeleteSlots && !_selecting)
            IconButton(
              key: const Key('os-cal-selecionar'),
              tooltip: 'Selecionar para apagar',
              icon: const Icon(Icons.checklist),
              onPressed: _busy ? null : () => setState(() => _selecting = true),
            ),
          if (_step == 2 && _selecting)
            TextButton(
              key: const Key('os-cal-selecionar-sobressalentes'),
              onPressed: _busy ? null : _selectSpares,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Sobressalentes'),
            ),
        ],
      ),
      bottomNavigationBar: _step == 2 && _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const Key('os-cal-apagar-selecionados'),
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : _deleteSelected,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8A1F1F),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    _selected.isEmpty
                        ? 'Toque nos certificados para marcar'
                        : 'Apagar ${_selected.length} certificado(s)',
                  ),
                ),
              ),
            )
          : null,
      body: _busy && _orders.isEmpty && _step == 0
          ? const Center(child: CircularProgressIndicator())
          : _step == 0
          ? _buildOsList()
          : _step == 1
          ? _buildKindList()
          : _buildSlotList(),
    );
  }

  Widget _buildOsList() {
    final items = _filteredOrders;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _osQuery,
            decoration: const InputDecoration(
              labelText: 'Buscar OS, cliente, local…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma OS com certificados neste aparelho.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final os = items[index];
                    return ListTile(
                      tileColor: Colors.white,
                      title: Text(
                        'OS ${os.number}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (os.rdo.client.trim().isNotEmpty) os.rdo.client,
                          '${os.calibrationSlots.length} certificado(s)',
                          osStatusLabel(os.status),
                        ].join(' · '),
                      ),
                      onTap: _busy ? null : () => _pickOs(os),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKindList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final os = _os!;
        final withJob = group.slots
            .where(
              (s) =>
                  CalibrationStore.instance.jobForSlot(
                    s,
                    osId: os.id,
                    osNumber: os.number,
                  ) !=
                  null,
            )
            .length;
        final orphan = group.slots.length - withJob;
        return ListTile(
          tileColor: Colors.white,
          title: Text(
            calibrationKindLabel(group.kind),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
            ),
          ),
          subtitle: Text(
            [
              '${group.items.length} certificado(s)',
              if (withJob > 0) '$withJob com calibração',
              if (orphan > 0) '$orphan sem calibração',
            ].join(' · '),
          ),
          onTap: () => _pickKind(group.kind),
        );
      },
    );
  }

  Widget _buildSlotList() {
    final items = _filteredSlots;
    final os = _os!;
    final sameMeter = calibrationSlotsSharingMeter(_slotsOfKind, _jobOf);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _slotQuery,
            decoration: const InputDecoration(
              labelText: 'Buscar certificado, TAG, N/S, produto…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Nenhum certificado neste filtro.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final slot = items[index];
                    final job = CalibrationStore.instance.jobForSlot(
                      slot,
                      osId: os.id,
                      osNumber: os.number,
                    );
                    final repeated = sameMeter[slot.id] ?? const <String>[];
                    final marked = _selected.contains(slot.id);
                    void toggle() => setState(() {
                      if (!_selected.remove(slot.id)) _selected.add(slot.id);
                    });
                    return ListTile(
                      key: Key('os-cal-slot-${slot.id}'),
                      leading: _selecting
                          ? Checkbox(
                              value: marked,
                              onChanged: _busy ? null : (_) => toggle(),
                            )
                          : null,
                      selected: marked,
                      selectedTileColor: const Color(0xFFFDECEC),
                      tileColor: repeated.isEmpty
                          ? Colors.white
                          : const Color(0xFFFFF3E0),
                      title: Text(
                        slot.certificateNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(osCalibrationSlotDetailLine(slot, job: job)),
                          if (repeated.isNotEmpty)
                            Text(
                              'Mesmo medidor do ${repeated.join(', ')} — '
                              'um dos dois está errado',
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      onTap: _busy
                          ? null
                          : (_selecting ? toggle : () => _openSlot(slot)),
                      onLongPress: _busy || !_canDeleteSlots || _selecting
                          ? null
                          : () => setState(() {
                              _selecting = true;
                              _selected.add(slot.id);
                            }),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
