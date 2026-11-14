import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/app_date_picker.dart';
import 'package:gs_mobile/core/search_pick_sheet.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_math.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/certificate_sign_dialog.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_delete.dart';
import 'package:gs_mobile/features/calibration/fluid_pick_page.dart';
import 'package:intl/intl.dart';

class CalibrationJobPage extends StatefulWidget {
  const CalibrationJobPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<CalibrationJobPage> createState() => _CalibrationJobPageState();
}

class _CalibrationJobPageState extends State<CalibrationJobPage> {
  CalibrationJob? _job;

  String _defaultWorkingPrinciple(CalibrationJob job, String equipmentType) {
    if (job.isVolumetric) {
      return equipmentType.toLowerCase().contains('coriolis')
          ? 'Coriolis'
          : 'Medição Volumétrica';
    }
    switch (job.kind) {
      case CalibrationKind.temperature:
        return 'Termorresistência';
      case CalibrationKind.temperatureMesh:
        return 'Malha de temperatura';
      case CalibrationKind.density:
        return 'Tubo Vibratório';
      case CalibrationKind.conductivity:
        return 'Célula de condutividade';
      case CalibrationKind.telemetry:
        return 'Servo Operado';
      case CalibrationKind.pressure:
      case CalibrationKind.volumetric:
      case CalibrationKind.volumetricInverted:
        return '';
    }
  }
  var _busy = false;
  /// N/S digitado na tela. Não deixa o slot antigo cobrir essa correção no PDF.
  /// Filtro de produto no funil (antes de escolher a TAG).
  String _pickProduct = '';

  CalibrationJob get job => _job!;

  SavedClient? get _selectedClientRecord {
    final id = job.clientId.trim();
    if (id.isNotEmpty) {
      final byId = ClientStore.instance.byId(id);
      if (byId != null) return byId;
    }
    return ClientStore.instance.findMatch(
      cnpj: job.clientCnpj,
      name: job.clientName,
    );
  }

  @override
  void initState() {
    super.initState();
    _job = _withTelemetryDefaults(CalibrationStore.instance.byId(widget.jobId));
    CalibrationStore.instance.load().then((_) async {
      if (!mounted) return;
      await ClientStore.instance.load();
      if (!mounted) return;
      final before = _withTelemetryDefaults(
        CalibrationStore.instance.byId(widget.jobId) ?? _job,
      );
      await CalibrationCatalog.instance.load();
      if (!mounted) return;
      if (before == null) return;
      // Mostra a mesma TAG/N/S da lista. Não puxa o medidor de outra plataforma.
      final prepared = _withTelemetryDefaults(prepareCertificateJob(before));
      if (prepared == null) return;
      final next = enrichCalibrationJobFluidFromCatalog(prepared);
      setState(() => _job = next);
      _ensureCadastroFluid();
    });
  }

  void _patch(CalibrationJob next) {
    setState(() => _job = next);
  }

  CalibrationJob? _withTelemetryDefaults(CalibrationJob? job) {
    if (job == null || !job.isTelemetry) return job;
    var next = job;
    if (next.telemetryChannels.isEmpty) {
      next = next.copyWith(telemetryChannels: defaultTelemetryChannels());
    }
    if (next.standards.length < 2) {
      next = next.copyWith(
        standards: [
          ...next.standards,
          for (var i = next.standards.length; i < 2; i++)
            CalibrationStandard(id: '${next.id}-std-$i'),
        ],
      );
    }
    return next;
  }

  Future<void> _save({bool pop = false}) async {
    if (_job == null) return;
    setState(() => _busy = true);
    try {
      final toSave = _job!.status == CalibrationJobStatus.draft
          ? _job!.copyWith(status: CalibrationJobStatus.inProgress)
          : _job!;
      final saved = await CalibrationStore.instance.save(toSave);
      if (!mounted) return;
      setState(() {
        _job = saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Calibração salva.'),
        ),
      );
      if (pop) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _saveToCloud() async {
    if (_job == null) return;
    setState(() => _busy = true);
    try {
      final toSave = _job!.status == CalibrationJobStatus.draft
          ? _job!.copyWith(status: CalibrationJobStatus.inProgress)
          : _job!;
      final current = await CalibrationStore.instance.save(toSave);
      if (!mounted) return;

      final isAlreadyRemote = CalibrationStore.instance.isRemote(current.id);
      if (isAlreadyRemote) {
        setState(() => _busy = false);
        final action = await showDialog<String>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: GsTheme.paper,
            title: const Text(
              'Certificado já na nuvem',
              style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            content: Text(
              'O certificado ${current.number} (${current.clientName}) já foi salvo na nuvem.\n\n'
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
          final copy = CalibrationStore.instance.createCopy(current);
          final savedCopy = await CalibrationStore.instance.save(copy);
          final res = await CalibrationStore.instance.pushRemoteJob(savedCopy);
          if (!mounted) return;
          setState(() {
            _job = savedCopy;
            _busy = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: res.ok ? GsTheme.navy : const Color(0xFF8A1F1F),
              content: Text(
                res.ok
                    ? 'Cópia ${savedCopy.number} criada e salva na nuvem!'
                    : 'Erro ao salvar cópia: ${res.error}',
              ),
            ),
          );
          return;
        } else if (action == 'overwrite') {
          final res = await CalibrationStore.instance.pushRemoteJob(current);
          if (!mounted) return;
          setState(() {
            _job = current;
            _busy = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: res.ok ? GsTheme.navy : const Color(0xFF8A1F1F),
              content: Text(
                res.ok
                    ? 'Certificado ${current.number} atualizado na nuvem!'
                    : 'Erro ao sobrescrever: ${res.error}',
              ),
            ),
          );
          return;
        }
      } else {
        final res = await CalibrationStore.instance.pushRemoteJob(current);
        if (!mounted) return;
        setState(() {
          _job = current;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: res.ok ? GsTheme.navy : const Color(0xFF8A1F1F),
            content: Text(
              res.ok
                  ? 'Certificado ${current.number} salvo na nuvem com sucesso!'
                  : 'Erro ao salvar na nuvem: ${res.error}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $error')),
        );
      }
    }
  }

  Future<void> _saveToDrive() async {
    if (_job == null) return;
    setState(() => _busy = true);
    try {
      final current = await CalibrationStore.instance.save(_job!);
      if (!mounted) return;
      final saved = await archiveCalibrationJobsToDrive(context, [current]);
      if (saved && mounted) {
        setState(() => _job = CalibrationStore.instance.byId(current.id) ?? _job);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _certificate() async {
    if (_job == null) return;
    final signed = await askCertificateSignatureMode(context);
    if (signed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final current = prepareCertificateJob(_job!);
      final saved = await CalibrationStore.instance.save(
        current.copyWith(status: CalibrationJobStatus.done),
      );
      await FieldStore.instance.syncSlotFromSavedJob(
        saved,
        knownJobs: CalibrationStore.instance.items,
      );
      final bytes = await buildCalibrationCertificate(
        saved,
        withSignature: signed,
      );
      final pdfName = calibrationPdfFileName(saved, withSignature: signed);
      final savedAt = await saveLocalFile(
        fileName: pdfName,
        bytes: bytes,
        subfolder: 'GS Campo/Certificados',
      );
      final backupName =
          '${saved.number.trim().isEmpty ? saved.id : saved.number}_backup.json';
      final jsonBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(saved.toJson()),
      );
      try {
        await saveLocalFile(
          fileName: backupName,
          bytes: jsonBytes,
          subfolder: 'GS Campo/Certificados/Backup',
        );
      } catch (_) {}
      final inDrive = await saveGeneratedFilesToDrive(
        osId: saved.osId,
        osNumber: calibrationJobOsFolderKey(saved),
        files: [
          (
            folder:
                'Certificados de Calibração/${calibrationKindFolder(saved.kind)}',
            name: pdfName,
            bytes: bytes,
          ),
          (
            folder: 'Certificados de Calibração/Backup',
            name: backupName,
            bytes: jsonBytes,
          ),
        ],
      );
      if (!mounted) return;
      setState(() => _job = saved);
      final onWeb = kIsWeb;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            (onWeb
                    ? 'Certificado gerado. Veja em Downloads no navegador.'
                    : 'Certificado gerado neste computador:\n$savedAt') +
                driveSavedSuffix(inDrive),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendForReview() async {
    if (_job == null) return;
    setState(() => _busy = true);
    try {
      final saved = await CalibrationStore.instance.save(
        _job!.copyWith(status: CalibrationJobStatus.pendingReview),
      );
      if (!mounted) return;
      setState(() {
        _job = saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Preenchimento enviado para análise. O certificado só é gerado com autorização.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final current = _job;
    if (current == null) return;
    if (!await confirmDeleteCalibration(context, current)) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickClient() async {
    final clients = ClientStore.instance.items;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre o cliente antes, na lista abaixo ou em Clientes.')),
      );
      return;
    }
    final selected = await showSearchPickSheet<SavedClient>(
      context: context,
      title: 'Cliente da calibração',
      items: clients,
      selected: _selectedClientRecord,
      labelOf: (client) => client.name,
      subtitleOf: (client) => client.cnpj,
      searchOf: (client) => '${client.name} ${client.cnpj}',
      emptyMessage: 'Nenhum cliente com esse texto.',
    );
    if (selected == null || !mounted) return;
    setState(() => _pickProduct = '');
    _patch(_jobFromClient(selected));
  }

  CalibrationJob _jobFromClient(SavedClient selected) {
    return job.copyWith(
      clientId: selected.id,
      clientName: selected.name,
      serviceRequester: selected.requester.trim().isNotEmpty
          ? selected.requester.trim()
          : job.serviceRequester,
      clientCnpj: selected.cnpj,
      clientAddress: selected.addressLine,
      site: selected.primarySite.isNotEmpty ? selected.primarySite : job.site,
      systemType: '',
      systemId: '',
      systemTag: '',
      assemblyKind: '',
      presetTag: '',
      presetManufacturer: '',
      presetModel: '',
      presetSerial: '',
      instrumentRole: '',
      equipmentId: '',
      equipmentTag: '',
      equipmentType: '',
      manufacturer: '',
      model: '',
      serialNumber: '',
      workingPrinciple: '',
      installLocation: '',
    );
  }

  List<ClientSystem> get _clientSystems =>
      _selectedClientRecord?.resolvedSystems ?? const [];

  List<String> get _systemTypes => uniqueClientSystemTypes(_clientSystems);

  List<String> get _installLocations => uniqueClientInstallLocations(
        _clientSystems,
        systemType: job.systemType,
      );

  List<ClientEquipment> get _equipmentAtPlace {
    final all = filterClientEquipmentCascade(
      _clientSystems,
      systemType: job.systemType,
      installLocation: job.installLocation,
      includeMeshes: job.kind == CalibrationKind.temperatureMesh,
    );
    return [
      for (final item in all)
        if (clientEquipmentMatchesCalibrationKind(item, job.kind)) item,
    ];
  }

  List<String> get _productsAtPlace => uniqueClientProducts(_equipmentAtPlace);

  List<ClientEquipment> get _equipmentForTagPick {
    final all = filterClientEquipmentCascade(
      _clientSystems,
      systemType: job.systemType,
      installLocation: job.installLocation,
      product: _pickProduct,
      includeMeshes: job.kind == CalibrationKind.temperatureMesh,
    );
    return [
      for (final item in all)
        if (clientEquipmentMatchesCalibrationKind(item, job.kind)) item,
    ];
  }

  bool _isCurrentEquipment(ClientEquipment item) {
    final id = job.equipmentId.trim();
    if (id.isNotEmpty && _equipmentForKindAnywhere.any((e) => e.id == id)) {
      return item.id == id;
    }
    final serial = job.serialNumber.trim().toLowerCase();
    return serial.isNotEmpty &&
        item.serialNumber.trim().toLowerCase() == serial &&
        item.tag.trim().toLowerCase() == job.equipmentTag.trim().toLowerCase();
  }

  List<ClientEquipment> get _equipmentForKindAnywhere {
    final all = filterClientEquipmentCascade(
      _clientSystems,
      includeMeshes: job.kind == CalibrationKind.temperatureMesh,
    );
    return [
      for (final item in all)
        if (clientEquipmentMatchesCalibrationKind(item, job.kind)) item,
    ];
  }

  List<String> get _currentInstrumentProducts {
    final eq = _equipmentForTagPick.firstWhere(
      (e) => e.id == job.equipmentId,
      orElse: () => _equipmentAtPlace.firstWhere(
        (e) =>
            e.id == job.equipmentId ||
            (e.tag.isNotEmpty && e.tag == job.equipmentTag),
        orElse: () => const ClientEquipment(
          id: '',
          systemType: '',
          equipmentType: '',
          quantity: 1,
          installLocation: '',
        ),
      ),
    );
    final prods = splitClientProducts(eq.product);
    if (prods.isNotEmpty) return prods;
    if (_productsAtPlace.isNotEmpty) return _productsAtPlace;
    return const [];
  }

  List<String> get _availableSigners {
    final list = <String>[];
    void addName(String raw) {
      final name = raw.trim();
      if (name.isEmpty || name == '-') return;
      if (!list.any((item) => item.trim().toLowerCase() == name.toLowerCase())) {
        list.add(name);
      }
    }

    if (job.osId.trim().isNotEmpty) {
      final os = FieldStore.instance.byId(job.osId.trim());
      if (os != null) {
        final team = teamNamesForOs(os);
        for (final member in team) {
          addName(member);
        }
      }
    }

    if (list.isEmpty) {
      for (final user in StaffStore.instance.technicianAccounts) {
        addName(user.name);
      }
      for (final tech in fieldTechnicians) {
        addName(tech.name);
      }
      for (final user in StaffStore.instance.employees) {
        addName(user.name);
      }
    }

    if (job.technicianName.trim().isNotEmpty) {
      addName(job.technicianName);
    }
    return list;
  }

  void _clearEquipmentFields(CalibrationJob base) {
    _patch(
      base.copyWith(
        systemId: '',
        systemTag: '',
        assemblyKind: '',
        presetTag: '',
        presetManufacturer: '',
        presetModel: '',
        presetSerial: '',
        instrumentRole: '',
        equipmentId: '',
        equipmentTag: '',
        equipmentType: '',
        manufacturer: '',
        model: '',
        serialNumber: '',
        workingPrinciple: '',
      ),
    );
  }

  void _applySystemType(String systemType) {
    final same = systemType.trim().toLowerCase() ==
        job.systemType.trim().toLowerCase();
    if (same) {
      if (calibrationJobInstrumentIncomplete(job)) {
        _maybeAutoPickAfterLocation();
      }
      return;
    }
    setState(() => _pickProduct = '');
    final locations = uniqueClientInstallLocations(
      _clientSystems,
      systemType: systemType,
    );
    final onlyLocation = locations.length == 1 ? locations.first : '';
    _clearEquipmentFields(
      job.copyWith(
        systemType: systemType,
        installLocation: onlyLocation,
      ),
    );
    if (onlyLocation.isNotEmpty) {
      _maybeAutoPickAfterLocation();
    }
  }

  void _applyInstallLocation(String location) {
    final same = location.trim().toLowerCase() ==
        job.installLocation.trim().toLowerCase();
    if (same) {
      if (calibrationJobInstrumentIncomplete(job)) {
        _maybeAutoPickAfterLocation();
      }
      return;
    }
    setState(() => _pickProduct = '');
    _clearEquipmentFields(
      job.copyWith(
        installLocation: location,
      ),
    );
    _maybeAutoPickAfterLocation();
  }

  void _applyProductFilter(String product) {
    setState(() => _pickProduct = product);
    _clearEquipmentFields(job);
    final items = [
      for (final item in filterClientEquipmentCascade(
        _clientSystems,
        systemType: job.systemType,
        installLocation: job.installLocation,
        product: product,
        includeMeshes: job.kind == CalibrationKind.temperatureMesh,
      ))
        if (clientEquipmentMatchesCalibrationKind(item, job.kind)) item,
    ];
    if (items.length == 1) {
      _applyEquipment(items.first);
    }
  }

  void _maybeAutoPickAfterLocation() {
    final items = _equipmentAtPlace;
    if (items.length == 1) {
      _applyEquipment(items.first);
      return;
    }
    final products = uniqueClientProducts(items);
    if (products.length == 1) {
      _applyProductFilter(products.first);
    }
  }

  Future<void> _applyFluidFromCatalogIfMatched(String fluidName) async {
    final name = fluidName.trim().toLowerCase();
    if (name.isEmpty) return;
    await CalibrationCatalog.instance.load();
    final fluids = CalibrationCatalog.instance.fluids;
    for (final f in fluids) {
      if (f.name.trim().toLowerCase() == name) {
        _patch(
          job.copyWith(
            fluid: f.name,
            fluidDensityMin: f.densityMin,
            fluidDensityMax: f.densityMax,
            fluidViscosityMin: f.viscosityMin,
            fluidViscosityMax: f.viscosityMax,
            fluidDensityRefTemp: f.densityRefTemp,
            fluidViscosityRefTemp: f.viscosityRefTemp,
            fluidReferenceTemp: f.densityRefTemp,
          ),
        );
        return;
      }
    }
  }

  void _applyEquipment(ClientEquipment item, {bool overwriteIdentity = false}) {
    final prods = splitClientProducts(item.product);
    final previousFluid = job.fluid.trim();
    final applied = applyClientEquipmentToCalibrationJob(
      job,
      item,
      overwriteIdentity: overwriteIdentity,
    ).copyWith(
      workingPrinciple: item.workingPrinciple.trim().isNotEmpty
          ? item.workingPrinciple.trim()
          : (item.meshWorkingPrinciple.trim().isNotEmpty
              ? item.meshWorkingPrinciple.trim()
              : _defaultWorkingPrinciple(job, item.equipmentType)),
    );
    // Um produto no cadastro entra direto. Vários: mantém o que já foi
    // escolhido neste certificado, senão o técnico escolhe qual calibrar.
    String fluid;
    if (prods.length == 1) {
      fluid = prods.first;
      _pickProduct = prods.first;
    } else if (prods.isEmpty) {
      fluid = previousFluid;
    } else {
      String? keep;
      for (final name in prods) {
        if (name.toLowerCase() == previousFluid.toLowerCase()) {
          keep = name;
          break;
        }
      }
      if (keep == null) {
        final filter = _pickProduct.trim().toLowerCase();
        if (filter.isNotEmpty) {
          for (final name in prods) {
            if (name.toLowerCase() == filter) {
              keep = name;
              break;
            }
          }
        }
      }
      fluid = keep ?? '';
      if (keep != null) _pickProduct = keep;
    }
    final changed = fluid.toLowerCase() != previousFluid.toLowerCase();
    _patch(
      applied.copyWith(
        fluid: fluid,
        fluidDensityMin: changed ? '' : applied.fluidDensityMin,
        fluidDensityMax: changed ? '' : applied.fluidDensityMax,
        fluidViscosityMin: changed ? '' : applied.fluidViscosityMin,
        fluidViscosityMax: changed ? '' : applied.fluidViscosityMax,
        fluidDensityRefTemp: changed ? '' : applied.fluidDensityRefTemp,
        fluidViscosityRefTemp: changed ? '' : applied.fluidViscosityRefTemp,
        fluidReferenceTemp: changed ? '' : applied.fluidReferenceTemp,
        productDensity: changed ? '' : applied.productDensity,
        productTemperature: changed ? '' : applied.productTemperature,
      ),
    );
    if (fluid.isNotEmpty) _applyFluidFromCatalogIfMatched(fluid);
  }

  void _ensureCadastroFluid() {
    if (_job == null || job.isConductivity) return;
    final products = _currentInstrumentProducts;
    if (products.length == 1 && job.fluid.trim().isEmpty) {
      _pickProduct = products.first;
      _setFluid(products.first);
      return;
    }
    final fluid = job.fluid.trim();
    if (fluid.isEmpty || splitClientProducts(fluid).length != 1) return;
    if (job.fluidDensityMin.trim().isEmpty &&
        job.fluidDensityMax.trim().isEmpty &&
        job.fluidViscosityMin.trim().isEmpty &&
        job.fluidViscosityMax.trim().isEmpty) {
      _applyFluidFromCatalogIfMatched(fluid);
    }
  }

  void _setFluid(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      _pickProduct = '';
      _patch(
        job.copyWith(
          fluid: '',
          fluidDensityMin: '',
          fluidDensityMax: '',
          fluidViscosityMin: '',
          fluidViscosityMax: '',
          fluidDensityRefTemp: '',
          fluidViscosityRefTemp: '',
          fluidReferenceTemp: '',
          productDensity: '',
          productTemperature: '',
        ),
      );
      return;
    }
    _patch(job.copyWith(fluid: name));
    _applyFluidFromCatalogIfMatched(name);
  }

  List<Widget> _cadastroProductFields(CalibrationJob job) {
    final products = _currentInstrumentProducts;
    final fluid = job.fluid.trim();
    final fromCadastro = products.any(
      (name) => name.toLowerCase() == fluid.toLowerCase(),
    );
    if (products.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RegisteredFluidField(
            key: const Key('calibracao-fluido'),
            label: 'Produto / fluido',
            value: job.fluid,
            onChanged: _applyPickedFluid,
            onClear: () => _setFluid(''),
          ),
        ),
        if (fluid.isNotEmpty) ..._calibrationMeasureFields(job),
      ];
    }
    final chosen = fromCadastro
        ? fluid
        : (products.length == 1 && fluid.isEmpty ? products.first : '');
    if (chosen.isEmpty) {
      return [
        const Text(
          'Produto do cadastro',
          style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Este medidor tem mais de um produto. Escolha qual foi calibrado. '
          'A faixa padrão já vem do cadastro; aqui só a densidade e a temperatura medidas.',
          style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final prod in products)
              ChoiceChip(
                key: Key('calibracao-produto-cert-$prod'),
                label: Text(prod, style: const TextStyle(fontSize: 12)),
                selected: false,
                onSelected: (selected) {
                  if (!selected) return;
                  _pickProduct = prod;
                  _setFluid(prod);
                },
              ),
          ],
        ),
      ];
    }
    if (!fromCadastro && products.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _job == null) return;
        if (_job!.fluid.trim().isNotEmpty) return;
        final again = _currentInstrumentProducts;
        if (again.length != 1) return;
        _pickProduct = again.first;
        _setFluid(again.first);
      });
    }
    return [
      const Text(
        'Produto do cadastro',
        style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
      ),
      const SizedBox(height: 4),
      Text(
        chosen,
        key: const Key('calibracao-produto-cadastro'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
        ),
      ),
      if (products.length > 1)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              _pickProduct = '';
              _setFluid('');
            },
            child: const Text('Trocar produto'),
          ),
        ),
      ..._calibrationMeasureFields(job),
    ];
  }

  List<Widget> _calibrationMeasureFields(CalibrationJob job) {
    final densityRange = catalogRangeLabel(
      job.fluidDensityMin,
      job.fluidDensityMax,
    );
    final viscosityRange = catalogRangeLabel(
      job.fluidViscosityMin,
      job.fluidViscosityMax,
    );
    final densityTemp = job.fluidDensityRefTemp.trim().isNotEmpty
        ? job.fluidDensityRefTemp.trim()
        : (job.fluidReferenceTemp.trim().isNotEmpty
            ? job.fluidReferenceTemp.trim()
            : fluidDensityRefTempDefault);
    final viscosityTemp = job.fluidViscosityRefTemp.trim().isNotEmpty
        ? job.fluidViscosityRefTemp.trim()
        : fluidViscosityRefTempDefault;
    return [
      const SizedBox(height: 4),
      Text(
        [
          if (densityRange.isNotEmpty)
            'Densidade cadastro (mín–máx): $densityRange',
          if (densityRange.isNotEmpty) 'Temp. ref. densidade: $densityTemp',
          if (viscosityRange.isNotEmpty)
            'Viscosidade cadastro (mín–máx): $viscosityRange',
          if (viscosityRange.isNotEmpty)
            'Temp. ref. viscosidade: $viscosityTemp',
          if (densityRange.isEmpty && viscosityRange.isEmpty)
            'Sem faixa padrão na biblioteca de fluidos para este nome.',
        ].join('\n'),
        style: const TextStyle(height: 1.35, color: Color(0xFF5C6570)),
      ),
      const SizedBox(height: 8),
      _textField(
        'Densidade do produto na calibração',
        job.productDensity,
        (value) => _patch(job.copyWith(productDensity: value)),
        key: const Key('calibracao-densidade-produto'),
        helperText: 'Valor medido na calibração.',
      ),
      _textField(
        'Temperatura do produto na calibração',
        job.productTemperature,
        (value) => _patch(job.copyWith(productTemperature: value)),
        key: const Key('calibracao-temperatura-produto'),
        helperText: 'Temperatura do fluido no momento da calibração.',
      ),
    ];
  }

  void _applyPickedFluid(CatalogFluid selected) {
    if (!mounted || _job == null) return;
    FocusScope.of(context).unfocus();
    _pickProduct = selected.name;
    _patch(
      job.copyWith(
        fluid: selected.name,
        fluidDensityMin: selected.densityMin,
        fluidDensityMax: selected.densityMax,
        fluidViscosityMin: selected.viscosityMin,
        fluidViscosityMax: selected.viscosityMax,
        fluidDensityRefTemp: selected.densityRefTemp,
        fluidViscosityRefTemp: selected.viscosityRefTemp,
        fluidReferenceTemp: selected.densityRefTemp,
      ),
    );
  }

  Future<void> _pickStandardFromLibrary() async {
    await CalibrationCatalog.instance.load();
    final standards = CalibrationCatalog.instance.standards;
    if (standards.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre o padrão em Calibração, no atalho Padrões.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final category = standardCategoryForKind(job.kind);
    final place = [job.site, job.installLocation, job.clientAddress].join(' ');
    bool otherCategory(CatalogStandard item) =>
        item.categories.isNotEmpty && !item.categories.contains(category);
    bool ownClient(CatalogStandard item) => item.belongsToClient(
      clientId: job.clientId,
      clientName: job.clientName,
    );
    int score(CatalogStandard item) {
      var value = 0;
      if (otherCategory(item)) value -= 100;
      if (item.categories.contains(category)) value += 10;
      if (ownClient(item)) {
        value += 40;
      } else if (item.isClientOwned) {
        value -= 30;
      }
      if (item.locationMatching(place).isNotEmpty) value += 20;
      return value;
    }

    final ordered = [...standards]
      ..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final selected = await showSearchPickSheet<CatalogStandard>(
      context: context,
      title: 'Padrão · ${category.label}',
      items: ordered,
      labelOf: (item) =>
          item.name.trim().isEmpty ? item.serial : item.name,
      subtitleOf: (item) {
        final matchedPlace = item.locationMatching(place);
        return [
          [
            item.type,
            if (item.serial.trim().isNotEmpty) 'N/S ${item.serial}',
            if (item.certificate.trim().isNotEmpty) item.certificate,
            if (item.uncertainty.trim().isNotEmpty)
              item.uncertainty.trim().startsWith('±')
                  ? item.uncertainty.trim()
                  : '±${item.uncertainty.trim()}',
          ].join(' · '),
          [
            ownClient(item) ? '${item.ownerLabel} (desta OS)' : item.ownerLabel,
            if (matchedPlace.isNotEmpty)
              'Usado aqui: $matchedPlace'
            else if (item.locationsLabel.isNotEmpty)
              'Locais: ${item.locationsLabel}',
            if (otherCategory(item))
              'Outra categoria: ${item.categories.map((c) => c.label).join(', ')}',
          ].join(' · '),
        ].join('\n');
      },
      searchOf: (item) => [
        item.name,
        item.serial,
        item.type,
        item.certificate,
        item.uncertainty,
        item.ownerLabel,
        item.locationsLabel,
      ].join(' '),
      emptyMessage: 'Nenhum padrão com esse texto.',
    );
    if (selected == null || !mounted) return;
    final mapped = CalibrationStandard(
      id: newCatalogId(),
      tag: selected.name.trim().isEmpty ? selected.serial : selected.name,
      description: selected.type.trim(),
      serialNumber: selected.serial,
      certificate: selected.certificate,
      validity: selected.validity,
      uncertainty: selected.uncertainty,
      coverageK: selected.coverageK,
    );
    var next = [...job.standards];
    if (job.isTelemetry) {
      final emptyIndex = next.indexWhere((item) => !item.isFilled);
      if (emptyIndex >= 0) {
        next[emptyIndex] = next[emptyIndex].copyWith(
          tag: mapped.tag,
          description: mapped.description,
          serialNumber: mapped.serialNumber,
          certificate: mapped.certificate,
          validity: mapped.validity,
          uncertainty: mapped.uncertainty,
          coverageK: mapped.coverageK,
        );
      } else {
        next.add(mapped);
      }
    } else {
      if (next.isEmpty) {
        next = [mapped];
      } else {
        final emptyIndex = next.indexWhere((item) => !item.isFilled);
        if (emptyIndex >= 0) {
          next[emptyIndex] = next[emptyIndex].copyWith(
            tag: mapped.tag,
            description: mapped.description,
            serialNumber: mapped.serialNumber,
            certificate: mapped.certificate,
            validity: mapped.validity,
            uncertainty: mapped.uncertainty,
            coverageK: mapped.coverageK,
          );
          final kept = next[emptyIndex];
          next = [
            for (var i = 0; i < next.length; i++)
              if (i == emptyIndex || !_sameStandardIdentity(next[i], kept))
                next[i],
          ];
        } else {
          // Todos preenchidos: adiciona outro padrão (ex.: 2º em temperatura).
          next = [...next, mapped];
        }
      }
    }
    _patch(job.copyWith(standards: next));
  }

  bool _sameStandardIdentity(CalibrationStandard a, CalibrationStandard b) {
    final serialA = a.serialNumber.trim().toLowerCase();
    final serialB = b.serialNumber.trim().toLowerCase();
    if (serialA.isNotEmpty && serialB.isNotEmpty) return serialA == serialB;
    final tagA = a.tag.trim().toLowerCase();
    final tagB = b.tag.trim().toLowerCase();
    if (tagA.isEmpty || tagB.isEmpty) return false;
    return tagA == tagB;
  }

  Future<void> _pickEquipmentTag({bool anywhere = false}) async {
    final items = anywhere ? _equipmentForKindAnywhere : _equipmentForTagPick;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum instrumento neste tipo/local/produto.'),
        ),
      );
      return;
    }
    ClientEquipment? current;
    for (final item in items) {
      if (_isCurrentEquipment(item)) {
        current = item;
        break;
      }
    }
    final selected = await showSearchPickSheet<ClientEquipment>(
      context: context,
      title: 'TAG / instrumento',
      items: items,
      selected: current,
      labelOf: (item) => item.title,
      subtitleOf: (item) => [
        if (anywhere && item.installLocation.trim().isNotEmpty)
          item.installLocation.trim(),
        if (anywhere && item.systemType.trim().isNotEmpty)
          item.systemType.trim(),
        if (item.product.trim().isNotEmpty) item.product.trim(),
        if (item.presetTag.trim().isNotEmpty) 'Preset ${item.presetTag}',
        if (item.serialNumber.trim().isNotEmpty) 'N/S ${item.serialNumber}',
        if (item.instrumentRole.trim().isNotEmpty)
          clientInstrumentRoleLabel(
            clientInstrumentRoleFrom(item.instrumentRole),
          ),
      ].join(' · '),
      searchOf: (item) =>
          '${item.tag} ${item.product} ${item.serialNumber} ${item.presetTag} '
          '${item.equipmentType} ${item.installLocation} ${item.systemType}',
      emptyMessage: 'Nenhum instrumento com esse texto.',
    );
    if (selected == null || !mounted) return;
    _applyEquipment(selected, overwriteIdentity: anywhere);
  }

  OsCalibrationSlot? get _linkedSlot =>
      _job == null ? null : slotLinkedToCalibrationJob(job);

  /// Outros certificados da mesma OS com o mesmo medidor que este.
  List<String> get _sameMeterCertificates {
    final key = calibrationMeterKey(job);
    if (key.isEmpty) return const [];
    final os = job.osId.trim().isEmpty
        ? null
        : FieldStore.instance.byId(job.osId.trim());
    if (os == null) return const [];
    return [
      for (final slot in os.calibrationSlots)
        if (slot.id != job.calibrationSlotId &&
            calibrationKindFrom(slot.kind) == job.kind)
          ...() {
            final other = CalibrationStore.instance.jobForSlot(
              slot,
              osId: os.id,
              osNumber: os.number,
            );
            if (other == null || other.id == job.id) return const <String>[];
            final shown = calibrationJobForCertificatePrint(other, slot: slot);
            return calibrationMeterKey(shown) == key
                ? [slot.certificateNumber]
                : const <String>[];
          }(),
    ];
  }

  Widget _warningBox({required Key key, required List<Widget> children}) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static const _warningStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF8A4B08),
  );

  Widget _slotMismatchBanner() {
    final repeated = _sameMeterCertificates;
    final slot = _linkedSlot;
    final diffs = slot == null
        ? const <String>[]
        : calibrationSlotJobMismatch(slot, job);
    if (repeated.isEmpty && diffs.isEmpty) return const SizedBox.shrink();
    final mine = [
      if (job.equipmentTag.trim().isNotEmpty) 'TAG ${job.equipmentTag.trim()}',
      if (job.serialNumber.trim().isNotEmpty) 'N/S ${job.serialNumber.trim()}',
      if (job.presetTag.trim().isNotEmpty) 'Preset ${job.presetTag.trim()}',
    ].join(' · ');
    return Column(
      children: [
        if (repeated.isNotEmpty)
          _warningBox(
            key: const Key('calibracao-medidor-repetido'),
            children: [
              Text(
                'O mesmo medidor ($mine) também está no '
                '${repeated.join(', ')}. Dois certificados não podem ser do '
                'mesmo medidor: confira qual foi calibrado e troque o errado.',
                style: _warningStyle,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('calibracao-trocar-repetido'),
                onPressed: _busy ? null : () => _pickEquipmentTag(anywhere: true),
                icon: const Icon(Icons.manage_search),
                label: const Text('Trocar instrumento'),
              ),
            ],
          ),
        if (diffs.isNotEmpty)
          _warningBox(
            key: const Key('calibracao-difere-os'),
            children: [
              Text(
                'Confira: o certificado está com $mine. '
                'Na OS ficou anotado ${diffs.join(' · ')}.',
                style: _warningStyle,
              ),
              const SizedBox(height: 4),
              const Text(
                'Só um está certo. O que ficar aqui vale para a lista, o PDF, '
                'o livro e a etiqueta.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('calibracao-manter-certificado'),
                    onPressed: _busy ? null : () => _save(),
                    child: Text('Manter $mine'),
                  ),
                  OutlinedButton(
                    key: const Key('calibracao-usar-da-os'),
                    onPressed: _busy
                        ? null
                        : () => _patch(
                            applyOsSlotInstrumentToCalibrationJob(job, slot!),
                          ),
                    child: Text('Trocar para ${diffs.join(' · ')}'),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  void _setCycleCount(int count) {
    final n = count.clamp(1, 10);
    _patch(
      job.copyWith(
        cycleCount: n,
        genericPoints: padGenericPoints(
          job.genericPoints,
          job.genericPoints.length,
          n,
        ),
      ),
    );
  }

  void _setRunCount(int count) {
    _patch(
      job.copyWith(
        runCount: count,
        points: padFlowPoints(job.points, job.flowCount, count),
        genericPoints: padGenericPoints(job.genericPoints, job.genericPoints.length, count),
        cycleCount: count,
      ),
    );
  }

  void _setFlowCount(int count) {
    _patch(
      job.copyWith(
        flowCount: count,
        points: padFlowPoints(job.points, count, job.runCount),
      ),
    );
  }

  void _setFlowUnit(String unit) {
    final value = unit.trim().isEmpty ? 'L/min' : unit.trim();
    _patch(
      job.copyWith(
        points: [
          for (final point in job.points) point.copyWith(flowUnit: value),
        ],
      ),
    );
  }

  void _setMeterFactorDigits(int digits) {
    final n = clampMeterFactorDigits(digits);
    if (n == job.mfDigits) return;
    final inverted = job.invertedVolumetric;
    _patch(
      job.copyWith(
        meterFactorDigits: n,
        points: [
          for (final point in job.points)
            point.recalculateAppliedFactors(
              job.limits,
              inverted: inverted,
              meterFactorDigits: n,
            ),
        ],
      ),
    );
  }

  void _maybeAdoptTypedFactorDigits(String raw) {
    final places = decimalPlacesFromTypedNumber(raw);
    if (places == null) return;
    if (places < 3 || places > 6) return;
    if (places == job.mfDigits) return;
    // Só muda a regra de exibição; o chip 4/5 é que recalcula os fatores.
    _patch(job.copyWith(meterFactorDigits: places));
  }

  void _startConference(int index) {
    final point = job.points[index];
    final factor = point.suggestedNewFactor(
      job.limits,
      inverted: job.invertedVolumetric,
      meterFactorDigits: job.mfDigits,
    );
    final attempt = ConferenceAttempt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      meterFactorApplied: factor,
      runs: [
        for (var i = 0; i < job.runCount; i++)
          VolumeRun(id: '${point.id}-conf-${DateTime.now().microsecondsSinceEpoch}-$i'),
      ],
    );
    final points = [...job.points];
    points[index] = point.copyWith(conferences: [...point.conferences, attempt]);
    _patch(job.copyWith(points: points, status: CalibrationJobStatus.inProgress));
  }

  void _removeConference(int pointIndex, int confIndex) {
    final point = job.points[pointIndex];
    final attempts = [...point.conferences]..removeAt(confIndex);
    final points = [...job.points];
    points[pointIndex] = point.copyWith(conferences: attempts);
    _patch(job.copyWith(points: points));
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Calibração')),
        body: const Center(child: Text('Calibração não encontrada.')),
      );
    }
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: Text(job.number.trim().isEmpty ? calibrationKindLabel(job.kind) : job.number),
        actions: [
          IconButton(
            tooltip: 'Salvar PDF no Google Drive (Pastas da OS)',
            onPressed: _busy ? null : _saveToDrive,
            icon: const Icon(Icons.drive_folder_upload, color: Colors.white),
          ),
          IconButton(
            tooltip: CalibrationStore.instance.isRemote(job.id)
                ? 'Salvo na nuvem (toque para atualizar ou cópia)'
                : 'Salvar na nuvem (Planilha)',
            onPressed: _busy ? null : _saveToCloud,
            icon: Icon(
              CalibrationStore.instance.isRemote(job.id)
                  ? Icons.cloud_done
                  : Icons.cloud_upload_outlined,
              color: CalibrationStore.instance.isRemote(job.id)
                  ? const Color(0xFF81C784)
                  : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Excluir calibração',
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton(
            onPressed: _busy ? null : () => _save(),
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _slotMismatchBanner(),
          Text(
            calibrationKindLabel(job.kind),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          if (job.isTelemetry) ...[
            const Text(
              'Modelo de tanque (ATG): medidor de nível servo e temperatura. Três tomadas de nível, dados encontrados e deixados, trena e termômetro como padrão.',
              style: TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 12),
          ],
          if (job.isVolumetric) ...[
            const Text(
              'Antes de começar: informe a repetibilidade, o erro volumétrico e a linearidade que este cliente aceita. Depois escolha 2, 3 ou 5 corridas.',
              style: TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 12),
            _section('Critérios do cliente'),
            _numberField(
              key: const Key('calibracao-limite-repetibilidade'),
              label: 'Repetibilidade máxima (%)',
              value: job.limits.maxRepeatabilityPct,
              onChanged: (value) => _patch(
                job.copyWith(
                  limits: job.limits.copyWith(maxRepeatabilityPct: value),
                ),
              ),
            ),
            _numberField(
              label: 'Erro volumétrico máximo (%)',
              value: job.limits.maxVolumetricErrorPct,
              onChanged: (value) => _patch(
                job.copyWith(
                  limits: job.limits.copyWith(maxVolumetricErrorPct: value),
                ),
              ),
            ),
            _numberField(
              label: 'Linearidade máxima (%)',
              value: job.limits.maxLinearityPct,
              onChanged: (value) => _patch(
                job.copyWith(
                  limits: job.limits.copyWith(maxLinearityPct: value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Corridas em cada item'),
            Wrap(
              spacing: 8,
              children: [
                for (final count in const [2, 3, 5])
                  ChoiceChip(
                    key: count == 2 ? const Key('calibracao-corridas-2') : null,
                    label: Text('$count'),
                    selected: job.runCount == count,
                    onSelected: (_) => _setRunCount(count),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Quantidade de vazões (1 a 8)'),
            Wrap(
              spacing: 8,
              children: [
                for (var count = 1; count <= 8; count++)
                  ChoiceChip(
                    label: Text('$count'),
                    selected: job.flowCount == count,
                    onSelected: (_) => _setFlowCount(count),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _unitPicker(
              label: 'Unidade da vazão',
              value: job.points.isEmpty
                  ? 'L/min'
                  : job.points.first.flowUnit,
              suggestions: calibrationFlowUnits,
              fieldKey: 'calibracao-unidade-vazao',
              onChanged: _setFlowUnit,
            ),
            _unitPicker(
              label: 'Unidade do volume (Display)',
              value: job.volumeUnit,
              suggestions: calibrationVolumeUnits,
              fieldKey: 'calibracao-unidade-volume',
              onChanged: (unit) => _patch(job.copyWith(volumeUnit: unit)),
            ),
          ],
          const SizedBox(height: 16),
          _section('Cliente e instrumento'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              job.clientName.trim().isEmpty ? 'Selecionar cliente' : job.clientName,
            ),
            subtitle: Text(
              [
                if (job.serviceRequester.trim().isNotEmpty)
                  'Solicitante: ${job.serviceRequester.trim()}',
                if (job.clientCnpj.trim().isNotEmpty) job.clientCnpj,
                if (job.systemType.trim().isNotEmpty) job.systemType,
                if (job.installLocation.trim().isNotEmpty) job.installLocation,
                if (job.presetTag.trim().isNotEmpty) 'Preset ${job.presetTag}',
                if (job.equipmentTag.trim().isNotEmpty) 'TAG ${job.equipmentTag}',
                if (job.serialNumber.trim().isNotEmpty) 'N/S ${job.serialNumber}',
              ].join(' · ').ifEmpty('Puxa do cadastro do cliente'),
            ),
            trailing: const Icon(Icons.business_outlined),
            onTap: _pickClient,
          ),
          _textField(
            'Solicitante do serviço',
            job.serviceRequester,
            (value) => _patch(job.copyWith(serviceRequester: value)),
            key: const Key('calibracao-solicitante'),
            helperText:
                'Ex.: TESCAN ou nome fantasia. Sai em destaque nos Dados do Cliente.',
          ),
          _textField(
            'Nº do pedido / OC (opcional)',
            job.orderNumber,
            (value) => _patch(job.copyWith(orderNumber: value)),
            key: const Key('calibracao-numero-pedido'),
            helperText: 'Ex.: OC101-24. Sai no certificado se preenchido.',
          ),
          if (_selectedClientRecord != null) ...[
            const SizedBox(height: 8),
            const Text(
              '1. Tipo de sistema',
              style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Agrupa o que você cadastrou (carregamento, descarga, telemetria…).',
              style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 6),
            if (_clientSystems.isEmpty)
              const Text(
                'Nenhum sistema neste cliente. Cadastre em Clientes: tipo, local, medidor, preset, PT100…',
                style: TextStyle(color: Color(0xFF5C6570)),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _systemTypes)
                    ChoiceChip(
                      key: Key('calibracao-tipo-sistema-$type'),
                      label: Text(type),
                      selected:
                          job.systemType.trim().toLowerCase() ==
                          type.toLowerCase(),
                      onSelected: (_) => _applySystemType(type),
                    ),
                ],
              ),
              if (job.systemType.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '2. Local instalado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                if (_installLocations.isEmpty)
                  const Text(
                    'Esse tipo não tem local cadastrado. Edite o sistema no cliente.',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final location in _installLocations)
                        ChoiceChip(
                          key: Key('calibracao-local-$location'),
                          label: Text(location),
                          selected:
                              job.installLocation.trim().toLowerCase() ==
                              location.toLowerCase(),
                          onSelected: (_) => _applyInstallLocation(location),
                        ),
                    ],
                  ),
              ],
              if (job.systemType.trim().isNotEmpty &&
                  job.installLocation.trim().isNotEmpty) ...[
                if (_productsAtPlace.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '3. Produto',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('calibracao-produto-todos'),
                        label: const Text('Todos'),
                        selected: _pickProduct.trim().isEmpty,
                        onSelected: (_) => _applyProductFilter(''),
                      ),
                      for (final product in _productsAtPlace)
                        ChoiceChip(
                          key: Key('calibracao-produto-$product'),
                          label: Text(product),
                          selected:
                              _pickProduct.trim().toLowerCase() ==
                              product.toLowerCase(),
                          onSelected: (_) => _applyProductFilter(product),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _productsAtPlace.isEmpty
                      ? '3. TAG / instrumento'
                      : '4. TAG / instrumento',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Com o mesmo preset em várias linhas, escolha a TAG do medidor (ou PT100) certo.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('calibracao-pick-instrumento'),
                    onPressed: _pickEquipmentTag,
                    icon: const Icon(Icons.search),
                    label: Text(
                      _equipmentForTagPick.length > 8
                          ? 'Buscar TAG (${_equipmentForTagPick.length})'
                          : 'Selecionar TAG',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_equipmentForTagPick.isEmpty)
                  const Text(
                    'Nenhum instrumento neste filtro.',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  )
                else if (_equipmentForTagPick.length > 12)
                  Text(
                    job.equipmentId.trim().isEmpty
                        ? 'Use Buscar para escolher entre ${_equipmentForTagPick.length} instrumentos.'
                        : [
                            if (job.equipmentTag.trim().isNotEmpty)
                              'TAG ${job.equipmentTag}',
                            if (job.presetTag.trim().isNotEmpty)
                              'Preset ${job.presetTag}',
                            if (job.serialNumber.trim().isNotEmpty)
                              'N/S ${job.serialNumber}',
                          ].join(' · '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in _equipmentForTagPick)
                        ChoiceChip(
                          key: Key('calibracao-instrumento-${item.id}'),
                          label: Text(
                            [
                              item.title,
                              if (item.serialNumber.trim().isNotEmpty &&
                                  _equipmentForTagPick
                                          .where((e) => e.title == item.title)
                                          .length >
                                      1)
                                'N/S ${item.serialNumber.trim()}',
                              if (item.product.trim().isNotEmpty &&
                                  _pickProduct.trim().isEmpty)
                                item.product.trim(),
                            ].join(' · '),
                          ),
                          selected: _isCurrentEquipment(item),
                          onSelected: (_) => _applyEquipment(item),
                        ),
                    ],
                  ),
              ],
            ],
          ],
          _textField(
            'Princípio de funcionamento',
            job.workingPrinciple,
            (value) => _patch(job.copyWith(workingPrinciple: value)),
            key: const Key('calibracao-principio'),
            helperText: job.isTelemetry
                ? 'Ex.: servo operado. O tipo do medidor fica no cadastro do instrumento.'
                : job.isVolumetric
                    ? 'Se for Coriolis, o certificado ganha o fator do medidor.'
                    : job.isConductivity
                        ? 'Ex.: Célula de condutividade.'
                        : 'Princípio de medição / funcionamento do instrumento calibrado.',
          ),
          if (job.isVolumetric) ...[
            const SizedBox(height: 8),
            _coriolisFactorSection(),
          ],
          if (job.isTelemetry) ...[
            _textField(
              'Tipo do instrumento',
              job.equipmentType,
              (value) => _patch(job.copyWith(equipmentType: value)),
              key: const Key('calibracao-tipo-instrumento'),
              helperText: 'Ex.: Medidor de Nível tipo Servo Operado.',
            ),
            _textField(
              'TAG',
              job.equipmentTag,
              (value) => _patch(job.copyWith(equipmentTag: value)),
              key: const Key('calibracao-tag'),
            ),
            _textField(
              'Fabricante do instrumento',
              job.manufacturer,
              (value) => _patch(job.copyWith(manufacturer: value)),
              key: const Key('calibracao-fabricante'),
            ),
            _textField(
              'Modelo',
              job.model,
              (value) => _patch(job.copyWith(model: value)),
              key: const Key('calibracao-modelo'),
            ),
            _textField(
              'Concentradora / displacer',
              job.concentrator,
              (value) => _patch(job.copyWith(concentrator: value)),
              helperText: 'Como no certificado: DISPLACER NC025C1311A.',
            ),
            _textField(
              'Device ID',
              job.deviceId,
              (value) => _patch(job.copyWith(deviceId: value)),
            ),
            _textField(
              'Tipo de tanque',
              job.tankType,
              (value) => _patch(job.copyWith(tankType: value)),
              helperText: 'Ex.: Tanque tipo domo de teto fixo.',
            ),
            _textField('Local / base', job.site, (value) => _patch(job.copyWith(site: value))),
            _textField(
              'Técnico de campo',
              job.fieldTechnicianName,
              (value) => _patch(job.copyWith(fieldTechnicianName: value)),
              helperText: 'Quem mediu no tanque. No certificado assina ao lado do signatário.',
            ),
          ] else ...[
            if (_equipmentForKindAnywhere.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('calibracao-buscar-todo-cadastro'),
                    onPressed: () => _pickEquipmentTag(anywhere: true),
                    icon: const Icon(Icons.manage_search),
                    label: Text(
                      'Trocar instrumento (todo o cadastro · '
                      '${_equipmentForKindAnywhere.length})',
                    ),
                  ),
                ),
              ),
            _textField(
              'TAG',
              job.equipmentTag,
              (value) => _patch(
                job.copyWith(equipmentTag: value, equipmentId: ''),
              ),
              key: const Key('calibracao-tag-medidor'),
              helperText: 'Ex.: FT 1. É a TAG que sai no certificado e no livro.',
            ),
            _textField(
              'Nº de série',
              job.serialNumber,
              (value) =>
                  _patch(job.copyWith(serialNumber: value, equipmentId: '')),
              key: const Key('calibracao-serie'),
              helperText: 'N/S do medidor deste certificado. Não use o de outra plataforma.',
            ),
            _textField(
              'Fabricante',
              job.manufacturer,
              (value) => _patch(job.copyWith(manufacturer: value)),
              key: const Key('calibracao-fabricante-medidor'),
            ),
            _textField(
              'Modelo',
              job.model,
              (value) => _patch(job.copyWith(model: value)),
              key: const Key('calibracao-modelo-medidor'),
            ),
            _textField(
              'Preset (TAG)',
              job.presetTag,
              (value) => _patch(job.copyWith(presetTag: value, systemId: '')),
              key: const Key('calibracao-preset-tag'),
              helperText: 'Ex.: FIQ 1. Define a plataforma que sai no PDF.',
            ),
            if (!job.isConductivity) ..._cadastroProductFields(job),
            _dateField(
              'Data da calibração',
              job.calibrationDate.trim().isNotEmpty
                  ? job.calibrationDate.trim()
                  : DateFormat('dd/MM/yyyy').format(job.createdAt),
              (value) => _patch(job.copyWith(calibrationDate: value)),
              key: const Key('calibracao-data-execucao'),
              helperText:
                  'Data que sairá no cabeçalho e nos dados do certificado.',
            ),
            _textField('Local / base', job.site, (value) => _patch(job.copyWith(site: value))),
            _textField(
              'Temperatura ambiente',
              job.ambientTemp,
              (value) => _patch(job.copyWith(ambientTemp: value)),
            ),
            _textField('Umidade', job.humidity, (value) => _patch(job.copyWith(humidity: value))),
          ],
          if (job.isVolumetric) ...[
            const SizedBox(height: 16),
            _section('Vazões'),
            const Text(
              'Verificação primeiro. Se repetibilidade e erro estiverem dentro, a conferência fica dispensada — '
              'mas você pode abrir conferência opcional para ajustar o fator manualmente (ex.: erro negativo). '
              'Se estourar, o app sugere o fator novo e abre a conferência. Se a conferência falhar, repita na mesma quantidade de corridas.',
              style: TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 8),
            Text(
              job.invertedVolumetric
                  ? 'Cálculo invertido: fator Fc = objeto ÷ padrão. Erro(%) = (1 − Fc) × 100.'
                  : 'Cálculo: fator Fc = padrão ÷ objeto. Erro(%) = (1 − Fc) × 100.',
              style: const TextStyle(
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Casas decimais do Mf (fator)',
              style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escolha 4 ou 5, ou digite o fator com as casas desejadas — o app identifica.',
              style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final digits in const [4, 5])
                  ChoiceChip(
                    key: Key('calibracao-mf-casas-$digits'),
                    label: Text('$digits casas'),
                    selected: job.mfDigits == digits,
                    onSelected: (_) => _setMeterFactorDigits(digits),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < job.points.length; i++) _flowCard(i),
            const SizedBox(height: 8),
            Text(
              job.linearityApplicable
                  ? 'Linearidade: ${formatPercent(job.linearity)} · ${job.linearityOk ? 'dentro' : 'fora'}'
                  : 'Linearidade: dispensada (precisa de 2 ou mais vazões)',
              style: const TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
          ] else if (job.isTelemetry) ...[
            const SizedBox(height: 16),
            _section('Dados encontrados'),
            const Text(
              'Três tomadas de nível e a temperatura, como no certificado de tanque. Erro = |instrumento − padrão|.',
              style: TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < job.telemetryChannels.length; i++)
              _telemetryChannelCard(i, found: true),
            const SizedBox(height: 8),
            _section('Dados deixados'),
            const Text(
              'Preencha se ajustar o instrumento. Se a verificação já ficou boa, pode deixar em branco.',
              style: TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < job.telemetryChannels.length; i++)
              _telemetryChannelCard(i, found: false),
          ] else ...[
            const SizedBox(height: 16),
            _section('Critério de aceitação'),
            _numberField(
              key: const Key('calibracao-limite-erro-generico'),
              label: 'Erro máximo admissível (${resolvedMeasurementUnit(job).isEmpty ? 'unidade de medição' : resolvedMeasurementUnit(job)})',
              value: job.limits.maxGenericError,
              onChanged: (value) => _patch(
                job.copyWith(
                  limits: value == null
                      ? job.limits.copyWith(clearMaxGenericError: true)
                      : job.limits.copyWith(maxGenericError: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              job.kind == CalibrationKind.temperature ||
                      job.kind == CalibrationKind.temperatureMesh
                  ? 'Ciclos e pontos'
                  : 'Pontos',
            ),
            Text(
              job.kind == CalibrationKind.temperature ||
                      job.kind == CalibrationKind.temperatureMesh
                  ? 'Cada ciclo é uma passagem. Dentro do ciclo, cada ponto é uma temperatura diferente '
                      '(ex.: 26 °C e 34 °C no mesmo ciclo). Em cada ciclo escolha Verificação ou '
                      'Conferência: PT100 (sem ajuste) deixa todos em Verificação — a média do '
                      'certificado usa todos. Com ajuste, marque Conferência nos ciclos após o '
                      'ajuste — a média do resultado usa só esses. O tipo não aparece como rótulo '
                      'nas tabelas do PDF.'
                  : 'Preencha só o que medir. Ciclos vazios não entram no certificado. '
                      'Informe o fator antigo e o valor novo / fator novo manualmente em cada ponto se necessário. '
                      'Você também pode realizar conferência opcional.',
              style: const TextStyle(height: 1.4, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 8),
            Text(
              job.kind == CalibrationKind.temperature ||
                      job.kind == CalibrationKind.temperatureMesh
                  ? 'Quantidade de ciclos'
                  : (job.kind == CalibrationKind.density
                      ? 'Quantidade de pontos (um ponto por produto)'
                      : 'Quantidade de pontos'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var count = 1; count <= 8; count++)
                  ChoiceChip(
                    key: Key('calibracao-pontos-$count'),
                    label: Text(
                      job.kind == CalibrationKind.temperature ||
                              job.kind == CalibrationKind.temperatureMesh
                          ? '$countº ${count == 1 ? 'ciclo' : 'ciclos'}'
                          : '$count ${count == 1 ? 'ponto' : 'pontos'}',
                    ),
                    selected: job.genericPoints.length == count,
                    onSelected: (_) {
                      final current = [...job.genericPoints];
                      if (count > current.length) {
                        while (current.length < count) {
                          final prev = current.isEmpty ? null : current.last;
                          current.add(
                            GenericPoint(
                              id: DateTime.now().microsecondsSinceEpoch.toString() + current.length.toString(),
                              oldFactor: prev?.newValue,
                              cycles: [
                                for (var c = 0; c < job.cycleCount; c++)
                                  const GenericCycle(),
                              ],
                            ),
                          );
                        }
                      } else if (count < current.length) {
                        current.removeRange(count, current.length);
                      }
                      _patch(
                        job.copyWith(
                          genericPoints: padGenericPoints(
                            current,
                            count,
                            job.cycleCount,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              job.kind == CalibrationKind.temperature ||
                      job.kind == CalibrationKind.temperatureMesh
                  ? 'Pontos (temperaturas) por ciclo'
                  : (job.kind == CalibrationKind.density
                      ? 'Leituras por ponto (repetições do MESMO produto)'
                      : 'Verificações por ponto'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            if (job.kind == CalibrationKind.temperature ||
                job.kind == CalibrationKind.temperatureMesh)
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  'Ex.: 2 pontos = duas temperaturas diferentes dentro de cada ciclo.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var count = 1; count <= 8; count++)
                  ChoiceChip(
                    key: Key('calibracao-ciclos-$count'),
                    label: Text(
                      job.kind == CalibrationKind.temperature ||
                              job.kind == CalibrationKind.temperatureMesh
                          ? '$count ${count == 1 ? 'ponto' : 'pontos'}'
                          : '$count',
                    ),
                    selected: job.cycleCount == count,
                    onSelected: (_) => _setCycleCount(count),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _unitPicker(
              label: 'Unidade de medida (sai no certificado)',
              value: resolvedMeasurementUnit(job),
              suggestions: suggestedMeasurementUnits(job.kind),
              fieldKey: 'calibracao-unidade-medida',
              onChanged: (unit) => _patch(job.copyWith(measurementUnit: unit)),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < job.genericPoints.length; i++) _genericCard(i),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final previous = job.genericPoints.isEmpty
                        ? null
                        : job.genericPoints.last;
                    _patch(
                      job.copyWith(
                        genericPoints: padGenericPoints(
                          [
                            ...job.genericPoints,
                            GenericPoint(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              oldFactor: previous?.newValue,
                            ),
                          ],
                          job.genericPoints.length + 1,
                          job.cycleCount,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    job.kind == CalibrationKind.temperature ||
                            job.kind == CalibrationKind.temperatureMesh
                        ? 'Adicionar ciclo'
                        : 'Adicionar ponto',
                  ),
                ),
                if (job.genericPoints.length > 1)
                  TextButton.icon(
                    onPressed: () {
                      final current = [...job.genericPoints]..removeLast();
                      _patch(job.copyWith(genericPoints: current));
                    },
                    icon: const Icon(Icons.remove, color: Colors.red),
                    label: Text(
                      job.kind == CalibrationKind.temperature ||
                              job.kind == CalibrationKind.temperatureMesh
                          ? 'Remover último ciclo'
                          : 'Remover último ponto',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _section(
            job.isConductivity ||
                    job.isTelemetry ||
                    job.kind == CalibrationKind.temperature ||
                    job.kind == CalibrationKind.temperatureMesh ||
                    job.standards.length > 1
                ? 'Padrões utilizados'
                : 'Padrão utilizado',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('calibracao-padrao-biblioteca'),
              onPressed: _pickStandardFromLibrary,
              icon: const Icon(Icons.speed_outlined),
              label: Text(
                job.isConductivity
                    ? 'Usar solução padrão cadastrada'
                    : (job.standards.any((s) => s.isFilled)
                        ? 'Usar outro padrão cadastrado'
                        : 'Usar padrão cadastrado'),
              ),
            ),
          ),
          if (job.kind == CalibrationKind.temperature ||
              job.kind == CalibrationKind.temperatureMesh)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Pode usar 1 ou 2 padrões. Se escolher o segundo na biblioteca, '
                'ele entra como Padrão 2 (não substitui o primeiro).',
                style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF5C6570)),
              ),
            ),
          for (var i = 0; i < job.standards.length; i++) ...[
            if (job.isTelemetry ||
                job.isConductivity ||
                job.kind == CalibrationKind.temperature ||
                job.kind == CalibrationKind.temperatureMesh ||
                job.standards.length > 1)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 8 : 16, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.isConductivity
                            ? (job.standards[i].tag.trim().isNotEmpty
                                ? job.standards[i].tag.trim()
                                : 'Solução padrão ${i + 1}')
                            : 'Padrão ${i + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                        ),
                      ),
                    ),
                    if (job.standards.length > 1 &&
                        !(job.isTelemetry && job.standards.length <= 2))
                      IconButton(
                        tooltip: 'Remover este padrão',
                        onPressed: () {
                          final next = [...job.standards]..removeAt(i);
                          _patch(job.copyWith(standards: next));
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                  ],
                ),
              ),
            Builder(
              builder: (context) {
                final std = job.standards[i];
                final stamp = [
                  std.id,
                  std.tag,
                  std.description,
                  std.certificate,
                  std.validity,
                  std.uncertainty,
                  std.serialNumber,
                  std.nominalValue,
                  std.certifiedValue,
                ].join('|');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            _textField(
              job.isConductivity ? 'Identificação da solução' : 'Identificação / TAG',
              std.tag,
              (value) => _patchStandard(i, tag: value),
              key: ValueKey('std-$i-tag-$stamp'),
            ),
            _textField(
              'Tipo / descrição',
              std.description,
              (value) => _patchStandard(i, description: value),
              key: ValueKey('std-$i-desc-$stamp'),
              helperText: job.isTelemetry
                  ? (i == 0
                        ? 'Ex.: Trena de Profundidade'
                        : i == 1
                            ? 'Ex.: Termômetro de Líquido em Vidro'
                            : 'Tipo do padrão')
                  : (job.isConductivity
                      ? 'Ex.: Solução de condutividade.'
                      : 'Ex.: MEDIDOR CORIOLIS. O N/S fica no campo abaixo.'),
            ),
            if (job.isConductivity) ...[
              _textField(
                'Valor nominal (${resolvedMeasurementUnit(job)})',
                std.nominalValue,
                (value) => _patchStandard(i, nominalValue: value),
                key: ValueKey('std-$i-nominal-$stamp'),
              ),
              _textField(
                'Valor certificado (${resolvedMeasurementUnit(job)})',
                std.certifiedValue,
                (value) => _patchStandard(i, certifiedValue: value),
                key: ValueKey('std-$i-certified-$stamp'),
              ),
              _textField(
                'Certificado nº',
                std.certificate,
                (value) => _patchStandard(i, certificate: value),
                key: ValueKey('std-$i-cert-$stamp'),
              ),
              _textField(
                'Validade',
                std.validity,
                (value) => _patchStandard(i, validity: value),
                key: ValueKey('std-$i-validity-$stamp'),
                helperText: 'Ex.: 15/09/2028.',
              ),
              _textField(
                'Incerteza do padrão',
                std.uncertainty,
                (value) => _patchStandard(i, uncertainty: value),
                key: ValueKey('std-$i-unc-$stamp'),
                helperText:
                    'Digite com a unidade (ex.: 1,5 µS/cm) ou escolha abaixo.',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final u in [
                      ...calibrationConductivityUnits,
                      ...commonUncertaintyUnits.where(
                        (item) => !calibrationConductivityUnits.contains(item),
                      ),
                    ])
                      ActionChip(
                        label: Text(
                          u,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          final current = std.uncertainty;
                          final updated = applyUncertaintyUnit(current, u);
                          _patchStandard(i, uncertainty: updated);
                        },
                      ),
                  ],
                ),
              ),
              _textField(
                'Fator k do padrão',
                std.coverageK,
                (value) => _patchStandard(i, coverageK: value),
                key: ValueKey('std-$i-k-$stamp'),
                helperText: 'Opcional. Ex.: 2,00.',
              ),
            ] else if (job.isTelemetry) ...[
              _textField(
                'Fabricante',
                std.manufacturer,
                (value) => _patchStandard(i, manufacturer: value),
                key: ValueKey('std-$i-manufacturer-$stamp'),
              ),
              _textField(
                'Modelo',
                std.model,
                (value) => _patchStandard(i, model: value),
                key: ValueKey('std-$i-model-$stamp'),
              ),
              _textField(
                'N.º de série',
                std.serialNumber,
                (value) => _patchStandard(i, serialNumber: value),
                key: ValueKey('std-$i-serial-$stamp'),
              ),
              _textField(
                'Certificado de calibração',
                std.certificate,
                (value) => _patchStandard(i, certificate: value),
                key: ValueKey('std-$i-cert-$stamp'),
              ),
              _textField(
                'Executante',
                std.executant,
                (value) => _patchStandard(i, executant: value),
                key: ValueKey('std-$i-exec-$stamp'),
              ),
              _textField(
                'Data de calibração',
                std.calibrationDate,
                (value) => _patchStandard(i, calibrationDate: value),
                key: ValueKey('std-$i-caldate-$stamp'),
                helperText: 'Do certificado do padrão, como 08/08/2025.',
              ),
            ] else ...[
              _textField(
                'N.º de série',
                std.serialNumber,
                (value) => _patchStandard(i, serialNumber: value),
                key: ValueKey('std-$i-serial-$stamp'),
                helperText: 'N/S do padrão, separado da descrição.',
              ),
              _textField(
                'Incerteza do padrão',
                std.uncertainty,
                (value) => _patchStandard(i, uncertainty: value),
                key: ValueKey('std-$i-unc-$stamp'),
                helperText:
                    'Digite com a unidade (ex.: 0,2 °C, 0,05%, 0,08 bar) '
                    'ou escolha uma opção abaixo. O valor vai para a coluna Incerteza do certificado.',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final u in commonUncertaintyUnits)
                      ActionChip(
                        label: Text(
                          u,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          final current = std.uncertainty;
                          final updated = applyUncertaintyUnit(current, u);
                          _patchStandard(i, uncertainty: updated);
                        },
                      ),
                  ],
                ),
              ),
              _textField(
                'Fator de abrangência (k)',
                std.coverageK,
                (value) => _patchStandard(i, coverageK: value),
                key: ValueKey('std-$i-k-$stamp'),
                helperText:
                    'Fator de abrangência (k) do certificado do padrão. Se vazio, usa 2.',
              ),
              _textField(
                'Resolução do padrão (${job.volumeUnit.trim().isEmpty ? 'L' : job.volumeUnit.trim()})',
                std.resolution,
                (value) => _patchStandard(i, resolution: value),
                key: ValueKey('std-$i-res-$stamp'),
                helperText: 'Opcional. Na planilha entra no cálculo de U.',
              ),
              _textField(
                'Estabilidade do padrão (%)',
                std.stability,
                (value) => _patchStandard(i, stability: value),
                key: ValueKey('std-$i-stab-$stamp'),
                helperText: 'Opcional. Ex.: 0,025 — coluna Estabilidade da planilha.',
              ),
              _textField(
                'Nº do certificado',
                std.certificate,
                (value) => _patchStandard(i, certificate: value),
                key: ValueKey('std-$i-cert-$stamp'),
              ),
              _textField(
                'Validade',
                std.validity,
                (value) => _patchStandard(i, validity: value),
                key: ValueKey('std-$i-validity-$stamp'),
                helperText: 'Ex.: 15/09/2028.',
              ),
            ],
                  ],
                );
              },
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: job.standards.length >= 4
                  ? null
                  : () => _patch(
                        job.copyWith(
                          standards: [
                            ...job.standards,
                            CalibrationStandard(
                              id: DateTime.now().microsecondsSinceEpoch.toString(),
                              tag: job.isConductivity
                                  ? 'Solução padrão ${job.standards.length + 1}'
                                  : '',
                              description: job.isConductivity
                                  ? 'Solução de condutividade'
                                  : '',
                            ),
                          ],
                        ),
                      ),
              child: Text(
                job.isConductivity
                    ? 'Adicionar solução padrão'
                    : 'Adicionar padrão',
              ),
            ),
          ),
          if (job.isVolumetric) ...[
            _textField(
              'Resolução do instrumento (L)',
              job.instrumentResolution,
              (value) => _patch(job.copyWith(instrumentResolution: value)),
              helperText: 'Opcional. Valor de uma divisão, como 0,01.',
            ),
            const SizedBox(height: 8),
            const Text(
              'U, k e Veff o sistema calcula sozinho, como na planilha, com as medições e a incerteza do padrão.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF5C6570),
              ),
            ),
            const SizedBox(height: 12),
            _section('Fator K do medidor'),
            const Text(
              'Do medidor sob calibração (não do padrão). Encontrado vai em Valores Encontrados; Deixado em Valores Deixados. Vazio não imprime.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF5C6570),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _textField(
                    'Fator K encontrado',
                    job.meterKFactorFound,
                    (value) =>
                        _patch(job.copyWith(meterKFactorFound: value)),
                    helperText: 'Ex.: 13,000',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    'Fator K deixado',
                    job.meterKFactorLeft,
                    (value) => _patch(job.copyWith(meterKFactorLeft: value)),
                    helperText: 'Após ajuste, se houver.',
                  ),
                ),
              ],
            ),
          ],
          _textField(
            'Observação',
            job.notes,
            (value) => _patch(job.copyWith(notes: value)),
            helperText:
                'Texto livre no certificado (seção Observação). As notas fixas do resultado já saem sozinhas.',
          ),
          const SizedBox(height: 16),
          _section('Signatário Autorizado'),
          const Text(
            'Selecione o técnico responsável que assina o certificado:',
            style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final signer in _availableSigners)
                ChoiceChip(
                  label: Text(signer),
                  selected: job.technicianName.trim().toLowerCase() ==
                      signer.trim().toLowerCase(),
                  onSelected: (selected) {
                    if (selected) {
                      _patch(job.copyWith(technicianName: signer));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (AuthSession.instance.user?.canIssueCertificate == true)
            FilledButton.icon(
              key: const Key('calibracao-gerar-certificado'),
              onPressed: _busy ? null : _certificate,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Gerar certificado (só o preenchido)'),
            )
          else if (AuthSession.instance.user?.canFillCalibration == true) ...[
            FilledButton.icon(
              key: const Key('calibracao-enviar-analise'),
              onPressed: _busy ? null : _sendForReview,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Enviar para análise'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Técnico preenche e envia. O certificado só sai com autorização do Cleber.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF5C6570),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('calibracao-salvar-nuvem-btn'),
                  onPressed: _busy ? null : _saveToCloud,
                  icon: Icon(
                    CalibrationStore.instance.isRemote(job.id)
                        ? Icons.cloud_done
                        : Icons.cloud_upload_outlined,
                    color: CalibrationStore.instance.isRemote(job.id)
                        ? const Color(0xFF2E7D32)
                        : GsTheme.navy,
                    size: 18,
                  ),
                  label: Text(
                    CalibrationStore.instance.isRemote(job.id)
                        ? 'Nuvem (Planilha)'
                        : 'Salvar na Nuvem',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('calibracao-salvar-drive-btn'),
                  style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                  onPressed: _busy ? null : _saveToDrive,
                  icon: const Icon(Icons.drive_folder_upload, size: 18),
                  label: const Text(
                    'Drive (OS)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _coriolisFactorSection() {
    final selected = {
      for (final item in job.coriolisCoefficients) item.label.trim().toLowerCase(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Fator do Medidor (Coriolis)'),
        Text(
          job.isCoriolis
              ? 'Marque os coeficientes e preencha. Encontrado → Valores Encontrados; Deixado → Valores Deixados. Campo vazio não imprime.'
              : 'Pode cadastrar aqui os fatores do medidor (encontrado/deixado). Só saem no certificado se o princípio/tipo for Coriolis.',
          style: const TextStyle(height: 1.4, color: Color(0xFF5C6570)),
        ),
        const SizedBox(height: 8),
        Wrap(
          key: const Key('calibracao-fator-medidor'),
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final label in coriolisCoefficientLabels)
              FilterChip(
                key: Key('calibracao-coriolis-$label'),
                label: Text(label),
                selected: selected.contains(label.toLowerCase()),
                onSelected: (on) => _toggleCoriolisLabel(label, on),
              ),
            ActionChip(
              key: const Key('calibracao-coriolis-outro'),
              label: const Text('Outro'),
              onPressed: _addCustomCoriolisLabel,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in job.coriolisCoefficients) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GsTheme.navy,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _textField(
                  'Encontrado',
                  item.found,
                  (value) => _patchCoriolis(item.id, found: value),
                  key: ValueKey('${item.id}-found'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField(
                  'Deixado',
                  item.left,
                  (value) => _patchCoriolis(item.id, left: value),
                  key: ValueKey('${item.id}-left'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _toggleCoriolisLabel(String label, bool on) {
    final next = [...job.coriolisCoefficients];
    final index = next.indexWhere(
      (item) => item.label.trim().toLowerCase() == label.trim().toLowerCase(),
    );
    if (on && index < 0) {
      next.add(
        CoriolisCoefficient(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: label,
        ),
      );
    } else if (!on && index >= 0) {
      next.removeAt(index);
    }
    _patch(job.copyWith(coriolisCoefficients: next));
  }

  Future<void> _addCustomCoriolisLabel() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coeficiente do modelo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome (ex.: CF, DT)',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Incluir'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    _toggleCoriolisLabel(trimmed, true);
  }

  void _patchCoriolis(String id, {String? found, String? left}) {
    _patch(
      job.copyWith(
        coriolisCoefficients: [
          for (final item in job.coriolisCoefficients)
            if (item.id == id)
              item.copyWith(found: found, left: left)
            else
              item,
        ],
      ),
    );
  }

  void _patchStandard(
    int index, {
    String? tag,
    String? description,
    String? certificate,
    String? validity,
    String? uncertainty,
    String? coverageK,
    String? resolution,
    String? stability,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? executant,
    String? calibrationDate,
    String? nominalValue,
    String? certifiedValue,
  }) {
    final next = [...job.standards];
    next[index] = next[index].copyWith(
      tag: tag,
      description: description,
      certificate: certificate,
      validity: validity,
      uncertainty: uncertainty,
      coverageK: coverageK,
      resolution: resolution,
      stability: stability,
      manufacturer: manufacturer,
      model: model,
      serialNumber: serialNumber,
      executant: executant,
      calibrationDate: calibrationDate,
      nominalValue: nominalValue,
      certifiedValue: certifiedValue,
    );
    _patch(job.copyWith(standards: next));
  }

  Widget _flowCard(int index) {
    final point = job.points[index];
    final inverted = job.invertedVolumetric;
    final check = point.verificationResult(job.limits, inverted: inverted);
    final needConference = point.conferenceRequired(job.limits, inverted: inverted);
    final approved = point.isApproved(job.limits, inverted: inverted);
    final verificationOk = check.complete && check.passed;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vazão ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: GsTheme.navy),
            ),
            _numberField(
              label: 'Vazão (${point.flowUnit})',
              value: point.flowRate,
              onChanged: (value) {
                final points = [...job.points];
                points[index] = point.copyWith(flowRate: value);
                _patch(job.copyWith(points: points));
              },
            ),
            _factorNumberField(
              label: 'Fator antigo (Mf)',
              value: point.oldMeterFactor,
              onChanged: (value) {
                final points = [...job.points];
                // Corrige o Mf antigo → recalcula o Mf aplicado nas conferências
                // (antes só atualizava se apagasse a conferência).
                points[index] = point
                    .copyWith(oldMeterFactor: value ?? 1)
                    .recalculateAppliedFactors(
                      job.limits,
                      inverted: inverted,
                      meterFactorDigits: job.mfDigits,
                    );
                _patch(job.copyWith(points: points));
              },
            ),
            if (point.conferences.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('calibracao-atualizar-fatores-$index'),
                  onPressed: () {
                    final points = [...job.points];
                    points[index] = point.recalculateAppliedFactors(
                      job.limits,
                      inverted: inverted,
                      meterFactorDigits: job.mfDigits,
                    );
                    _patch(job.copyWith(points: points));
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Atualizar fatores das conferências'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Verificação', style: TextStyle(fontWeight: FontWeight.w700)),
            for (var r = 0; r < point.verification.length; r++)
              _runRow(point.verification[r], (run) {
                final runs = [...point.verification];
                runs[r] = run;
                final points = [...job.points];
                points[index] = point.copyWith(verification: runs);
                _patch(job.copyWith(points: points));
              }, inverted: inverted),
            _resultBanner(
              check,
              okLabel: point.conferences.isEmpty
                  ? 'Verificação aprovada'
                  : 'Verificação aprovada — conferência dispensada',
            ),
            if (needConference && !approved) ...[
              Text(
                'Fator sugerido: ${formatCalibNumber(point.suggestedNewFactor(job.limits, inverted: inverted, meterFactorDigits: job.mfDigits), digits: job.mfDigits)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              FilledButton(
                onPressed: () => _startConference(index),
                child: Text(
                  point.conferences.isEmpty
                      ? 'Corrigir fator e abrir conferência'
                      : 'Repetir conferência',
                ),
              ),
            ] else if (verificationOk) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _startConference(index),
                child: Text(
                  point.conferences.isEmpty
                      ? 'Fazer conferência (opcional)'
                      : 'Nova conferência',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mesmo com o erro dentro do critério, use para ajustar o fator manualmente '
                '(ex.: deixar erro negativo conforme pedido do cliente).',
                style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF5C6570)),
              ),
            ],
            for (var c = 0; c < point.conferences.length; c++) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _factorNumberField(
                      label: 'Mf Aplicado na Conferência ${c + 1}',
                      value: point.conferences[c].meterFactorApplied,
                      onChanged: (val) {
                        final attempts = [...point.conferences];
                        attempts[c] = attempts[c].copyWith(
                          meterFactorApplied: val == null
                              ? null
                              : roundMeterFactor(val, job.mfDigits),
                        );
                        final points = [...job.points];
                        points[index] = point.copyWith(conferences: attempts);
                        _patch(job.copyWith(points: points));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                    tooltip: 'Excluir conferência',
                    onPressed: () => _removeConference(index, c),
                  ),
                ],
              ),
              for (var r = 0; r < point.conferences[c].runs.length; r++)
                _runRow(point.conferences[c].runs[r], (run) {
                  final attempts = [...point.conferences];
                  final runs = [...attempts[c].runs];
                  runs[r] = run;
                  attempts[c] = attempts[c].copyWith(runs: runs);
                  final points = [...job.points];
                  points[index] = point.copyWith(conferences: attempts);
                  _patch(job.copyWith(points: points));
                }, inverted: inverted),
              _resultBanner(
                point.conferenceResult(
                  point.conferences[c],
                  job.limits,
                  inverted: inverted,
                ),
              ),
            ],
            if (point.leftConference != null) ...[
              const SizedBox(height: 8),
              Text(
                'Fator deixado no medidor (vai no certificado): '
                '${formatCalibNumber(point.leftMeterFactor(job.limits, inverted: inverted, meterFactorDigits: job.mfDigits), digits: job.mfDigits)}',
                key: Key('calibracao-fator-deixado-$index'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _runRow(
    VolumeRun run,
    ValueChanged<VolumeRun> onChanged, {
    required bool inverted,
  }) {
    final volumeUnit = job.volumeUnit.trim().isEmpty ? 'L' : job.volumeUnit.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _numberField(
              key: ValueKey('${run.id}-std'),
              label: 'Padrão ($volumeUnit)',
              value: run.standardVolume,
              onChanged: (value) =>
                  onChanged(run.copyWith(standardVolume: value, clearStandard: value == null)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numberField(
              key: ValueKey('${run.id}-obj'),
              label: 'Objeto ($volumeUnit)',
              value: run.objectVolume,
              onChanged: (value) => onChanged(run.copyWith(objectVolume: value, clearObject: value == null)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              run.isFilled
                  ? 'E ${formatPercent(run.errorPercentFor(inverted: inverted), digits: 3)}\nMf ${formatCalibNumber(run.factorFor(inverted: inverted), digits: job.mfDigits)}'
                  : '—',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryChannelCard(int index, {required bool found}) {
    if (index >= job.telemetryChannels.length) return const SizedBox.shrink();
    final channel = job.telemetryChannels[index];
    final takes = channel.takes(found: found);
    final unit = channel.unit.trim().isEmpty ? '' : ' (${channel.unit})';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${channel.label}$unit',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            if (found)
              _unitPicker(
                label: 'Unidade de ${channel.label.toLowerCase()}',
                value: channel.unit,
                suggestions: suggestedTelemetryUnits(channel.key),
                fieldKey: 'calibracao-telemetria-unidade-${channel.key}',
                onChanged: (value) {
                  final channels = [...job.telemetryChannels];
                  channels[index] = channel.copyWith(unit: value);
                  _patch(job.copyWith(telemetryChannels: channels));
                },
              ),
            for (var t = 0; t < takes.length; t++)
              _telemetryTakeRow(index, t, takes[t], found: found),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Erro médio: ${formatCalibNumber(channel.meanError(found: found), digits: 1)} ${channel.unit}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telemetryTakeRow(
    int channelIndex,
    int takeIndex,
    TelemetryTake take, {
    required bool found,
  }) {
    final channel = job.telemetryChannels[channelIndex];
    final unit = channel.unit.trim().isEmpty ? '' : ' (${channel.unit})';
    final numbered = channel.isLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _numberField(
              key: ValueKey('${channel.id}-${found ? 'f' : 'l'}-$takeIndex-std'),
              label: numbered ? 'Padrão ${takeIndex + 1}$unit' : 'Padrão$unit',
              value: take.standard,
              onChanged: (value) => _patchTelemetryTake(
                channelIndex,
                takeIndex,
                take.copyWith(standard: value, clearStandard: value == null),
                found: found,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numberField(
              key: ValueKey('${channel.id}-${found ? 'f' : 'l'}-$takeIndex-obj'),
              label: numbered
                  ? 'Instrumento ${takeIndex + 1}$unit'
                  : 'Instrumento$unit',
              value: take.instrument,
              onChanged: (value) => _patchTelemetryTake(
                channelIndex,
                takeIndex,
                take.copyWith(
                  instrument: value,
                  clearInstrument: value == null,
                ),
                found: found,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              take.isFilled
                  ? 'E ${formatCalibNumber(take.error, digits: 1)}'
                  : '—',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _patchTelemetryTake(
    int channelIndex,
    int takeIndex,
    TelemetryTake take, {
    required bool found,
  }) {
    final channels = [...job.telemetryChannels];
    final channel = channels[channelIndex];
    final list = [...channel.takes(found: found)];
    list[takeIndex] = take;
    channels[channelIndex] = found
        ? channel.copyWith(found: list)
        : channel.copyWith(left: list);
    _patch(job.copyWith(telemetryChannels: channels));
  }

  Widget _genericCard(int index) {
    final point = job.genericPoints[index];
    final unit = resolvedMeasurementUnit(job);
    final unitSuffix = unit.trim().isEmpty ? '' : ' ($unit)';
    final isDensity = job.kind == CalibrationKind.density;
    final isConductivity = job.isConductivity;
    final isTemp = job.kind == CalibrationKind.temperature ||
        job.kind == CalibrationKind.temperatureMesh;
    final standardLabel = isConductivity ? 'Valor de referência' : 'Padrão';
    final instrumentLabel = isConductivity ? 'Indicação' : 'Instrumento';
    final cardTitle = isTemp ? '${index + 1}º Ciclo' : 'Ponto ${index + 1}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cardTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            if (isTemp) ...[
              const SizedBox(height: 8),
              const Text(
                'Tipo deste ciclo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Verificação'),
                    icon: Icon(Icons.fact_check_outlined, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Conferência'),
                    icon: Icon(Icons.tune, size: 18),
                  ),
                ],
                selected: {point.isConference},
                onSelectionChanged: (selected) {
                  final points = [...job.genericPoints];
                  points[index] = point.copyWith(isConference: selected.first);
                  _patch(job.copyWith(genericPoints: points));
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  point.isConference
                      ? 'Entra na média do resultado (após ajuste).'
                      : (job.hasTemperatureConferenceCycles
                          ? 'Não entra na média do resultado enquanto houver ciclo(s) de conferência.'
                          : 'Sem conferência marcada, todos os ciclos entram na média.'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                ),
              ),
            ],
            if (!isTemp)
              _textField(
                'Ponto / TAG / valor nominal',
                point.label,
                (value) {
                  final points = [...job.genericPoints];
                  points[index] = point.copyWith(label: value);
                  _patch(job.copyWith(genericPoints: points));
                },
                key: ValueKey('generic-$index-label'),
              ),
            if (isTemp)
              _textField(
                'Identificação do ciclo (opcional)',
                point.label,
                (value) {
                  final points = [...job.genericPoints];
                  points[index] = point.copyWith(label: value);
                  _patch(job.copyWith(genericPoints: points));
                },
                key: ValueKey('generic-$index-label'),
              ),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    key: ValueKey('generic-$index-oldFactor'),
                    label: 'Fator antigo',
                    value: point.oldFactor,
                    onChanged: (value) {
                      final points = [...job.genericPoints];
                      points[index] = value == null
                          ? point.copyWith(clearOldFactor: true)
                          : point.copyWith(oldFactor: value);
                      _patch(job.copyWith(genericPoints: points));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    key: ValueKey('generic-$index-newValue'),
                    label: 'Valor novo',
                    value: point.newValue,
                    onChanged: (value) {
                      final points = [...job.genericPoints];
                      points[index] = value == null
                          ? point.copyWith(clearNewValue: true)
                          : point.copyWith(newValue: value);
                      _patch(job.copyWith(genericPoints: points));
                    },
                  ),
                ),
              ],
            ),
            if (point.newValue != null && index + 1 < job.genericPoints.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final points = [...job.genericPoints];
                    final next = points[index + 1];
                    points[index + 1] = next.copyWith(oldFactor: point.newValue);
                    _patch(job.copyWith(genericPoints: points));
                  },
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: Text(
                    isTemp
                        ? 'Passar valor novo para o próximo ciclo'
                        : 'Passar valor novo para o próximo ponto',
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              isTemp
                  ? 'Pontos (${point.cycles.length})$unitSuffix'
                  : 'Verificações (${point.cycles.length})$unitSuffix',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (var c = 0; c < point.cycles.length; c++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTemp)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${c + 1}º Ponto',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: GsTheme.navy,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        if (isDensity) ...[
                          Expanded(
                            child: _numberField(
                              key: ValueKey('generic-$index-temp-$c'),
                              label: 'Temp. Padrão ${c + 1} (°C)',
                              value: point.cycles[c].temperature,
                              onChanged: (value) {
                                final cycles = [...point.cycles];
                                cycles[c] = value == null
                                    ? cycles[c].copyWith(clearTemperature: true)
                                    : cycles[c].copyWith(temperature: value);
                                final points = [...job.genericPoints];
                                points[index] = point.copyWith(cycles: cycles);
                                _patch(job.copyWith(genericPoints: points));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _numberField(
                            key: ValueKey('generic-$index-std-$c'),
                            label: isTemp
                                ? '$standardLabel$unitSuffix'
                                : '$standardLabel ${c + 1}$unitSuffix',
                            value: point.cycles[c].standard,
                            onChanged: (value) {
                              final cycles = [...point.cycles];
                              cycles[c] = cycles[c].copyWith(standard: value);
                              final points = [...job.genericPoints];
                              points[index] = point.copyWith(cycles: cycles);
                              _patch(job.copyWith(genericPoints: points));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _numberField(
                            key: ValueKey('generic-$index-inst-$c'),
                            label: isTemp
                                ? '$instrumentLabel$unitSuffix'
                                : '$instrumentLabel ${c + 1}$unitSuffix',
                            value: point.cycles[c].instrument,
                            onChanged: (value) {
                              final cycles = [...point.cycles];
                              cycles[c] = cycles[c].copyWith(instrument: value);
                              final points = [...job.genericPoints];
                              points[index] = point.copyWith(cycles: cycles);
                              _patch(job.copyWith(genericPoints: points));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Erro médio: ${formatCalibNumber(point.meanError, digits: 3)}'
                '${unit.trim().isEmpty ? '' : ' $unit'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            // Conferência aninhada (densidade / pressão / etc.). Em temperatura
            // usa-se o seletor Verificação/Conferência no ciclo.
            if (!isTemp && point.conferences.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conferência (${point.conferences.length})$unitSuffix',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: GsTheme.navy),
                        tooltip: 'Adicionar linha de conferência',
                        onPressed: () {
                          final confs = [...point.conferences, const GenericCycle()];
                          final points = [...job.genericPoints];
                          points[index] = point.copyWith(conferences: confs);
                          _patch(job.copyWith(genericPoints: points));
                        },
                      ),
                      if (point.conferences.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.orange),
                          tooltip: 'Remover última linha',
                          onPressed: () {
                            final confs = [...point.conferences]..removeLast();
                            final points = [...job.genericPoints];
                            points[index] = point.copyWith(conferences: confs);
                            _patch(job.copyWith(genericPoints: points));
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: 'Remover conferência',
                        onPressed: () {
                          final points = [...job.genericPoints];
                          points[index] = point.copyWith(conferences: const []);
                          _patch(job.copyWith(genericPoints: points));
                        },
                      ),
                    ],
                  ),
                ],
              ),
              for (var c = 0; c < point.conferences.length; c++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      if (isDensity) ...[
                        Expanded(
                          child: _numberField(
                            key: ValueKey('generic-$index-conf-temp-$c'),
                            label: 'Temp. Padrão ${c + 1} (°C) (Conf.)',
                            value: point.conferences[c].temperature,
                            onChanged: (value) {
                              final confs = [...point.conferences];
                              confs[c] = value == null
                                  ? confs[c].copyWith(clearTemperature: true)
                                  : confs[c].copyWith(temperature: value);
                              final points = [...job.genericPoints];
                              points[index] = point.copyWith(conferences: confs);
                              _patch(job.copyWith(genericPoints: points));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _numberField(
                          key: ValueKey('generic-$index-conf-std-$c'),
                          label: '$standardLabel ${c + 1}$unitSuffix (Conf.)',
                          value: point.conferences[c].standard,
                          onChanged: (value) {
                            final confs = [...point.conferences];
                            confs[c] = confs[c].copyWith(standard: value);
                            final points = [...job.genericPoints];
                            points[index] = point.copyWith(conferences: confs);
                            _patch(job.copyWith(genericPoints: points));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          key: ValueKey('generic-$index-conf-inst-$c'),
                          label: '$instrumentLabel ${c + 1}$unitSuffix (Conf.)',
                          value: point.conferences[c].instrument,
                          onChanged: (value) {
                            final confs = [...point.conferences];
                            confs[c] = confs[c].copyWith(instrument: value);
                            final points = [...job.genericPoints];
                            points[index] = point.copyWith(conferences: confs);
                            _patch(job.copyWith(genericPoints: points));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Erro médio após conferência: ${formatCalibNumber(point.meanConferenceError, digits: 3)}'
                  '${unit.trim().isEmpty ? '' : ' $unit'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ] else if (!isTemp)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final points = [...job.genericPoints];
                    points[index] = point.copyWith(
                      conferences: [
                        for (var c = 0; c < point.cycles.length; c++)
                          const GenericCycle(),
                      ],
                    );
                    _patch(job.copyWith(genericPoints: points));
                  },
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Adicionar conferência a este ponto'),
                ),
              ),
            // Compliance check banner
            if (job.limits.maxGenericError != null && job.limits.maxGenericError! > 0 && point.meanError != null) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final approved = point.isApproved(job.limits.maxGenericError);
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: approved ? const Color(0xFFDCEFDC) : const Color(0xFFF8D7DA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      approved
                          ? 'Dentro do critério aceitável (máx. ±${job.limits.maxGenericError} $unit)'
                          : 'FORA DO CRITÉRIO ACEITÁVEL (máx. ±${job.limits.maxGenericError} $unit)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: approved ? const Color(0xFF2E6930) : const Color(0xFF842029),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultBanner(RunSetResult? result, {String okLabel = 'Dentro do critério'}) {
    if (result == null || !result.complete) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Preencha as corridas para o sistema calcular.'),
      );
    }
    final ok = result.passed;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      color: ok ? const Color(0xFFDCEFDC) : const Color(0xFFF8D7DA),
      child: Text(
        [
          ok ? okLabel : 'Fora do critério — conferência necessária',
          'Repetibilidade ${formatPercent(result.repeatability)} (${result.repeatabilityOk ? 'ok' : 'estourou'})',
          'Erro médio ${formatPercent(result.meanError)}',
          'Pior corrida ${formatPercent(result.worstError)} (${result.errorOk ? 'ok' : 'estourou'})',
          if (!result.errorOk)
            'Critério: cada corrida (não a média) ≤ ±${formatPercent(job.limits.maxVolumetricErrorPct, digits: 3)}',
        ].join('\n'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
        ),
      ),
    );
  }

  Widget _unitPicker({
    required String label,
    required String value,
    required List<String> suggestions,
    required ValueChanged<String> onChanged,
    String? fieldKey,
  }) {
    final current = value.trim();
    final options = <String>[
      for (final item in suggestions)
        if (item.trim().isNotEmpty) item.trim(),
    ];
    if (current.isNotEmpty && !options.contains(current)) {
      options.insert(0, current);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in options)
                ChoiceChip(
                  key: fieldKey == null ? null : Key('$fieldKey-$item'),
                  label: Text(item),
                  selected: current == item,
                  onSelected: (_) => onChanged(item),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: Key('${fieldKey ?? label}-custom-$current'),
            initialValue: current,
            decoration: InputDecoration(
              labelText: 'Outra unidade',
              helperText: job.isConductivity
                  ? 'Digite se não estiver na lista (ex.: nS/cm, µS/m).'
                  : 'Digite se não estiver na lista (ex.: µm, mbar).',
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? helperText,
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          DateTime initial;
          try {
            initial = DateFormat('dd/MM/yyyy').parseStrict(value);
          } catch (_) {
            initial = job.createdAt;
          }
          final picked = await pickAppDate(
            context,
            initialDate: initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );
          if (picked == null) return;
          onChanged(DateFormat('dd/MM/yyyy').format(picked));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            value.isEmpty ? 'Toque para selecionar a data' : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: GsTheme.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    Key? key,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SyncedTextFormField(
        fieldKey: key,
        label: label,
        value: value,
        helperText: helperText,
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField({
    Key? key,
    required String label,
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SyncedTextFormField(
        fieldKey: key,
        label: label,
        value: value == null ? '' : value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (raw) => onChanged(parseCalibNumber(raw)),
      ),
    );
  }

  /// Campo de Mf: mostra com as casas da calibração e detecta 4/5 ao digitar.
  Widget _factorNumberField({
    Key? key,
    required String label,
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    final digits = job.mfDigits;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SyncedTextFormField(
        fieldKey: key,
        label: label,
        value: value == null
            ? ''
            : formatCalibNumber(value, digits: digits),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (raw) {
          _maybeAdoptTypedFactorDigits(raw);
          onChanged(parseCalibNumber(raw));
        },
      ),
    );
  }
}

/// TextFormField que acompanha mudanças externas (ex.: biblioteca de fluidos).
/// Com `initialValue` + key fixa o nome sumia e só a densidade aparecia.
class _SyncedTextFormField extends StatefulWidget {
  const _SyncedTextFormField({
    this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.keyboardType,
  });

  final Key? fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final TextInputType? keyboardType;

  @override
  State<_SyncedTextFormField> createState() => _SyncedTextFormFieldState();
}

class _SyncedTextFormFieldState extends State<_SyncedTextFormField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SyncedTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _controller.text) return;
    // Só aplica valor externo quando o usuário não está digitando.
    if (!_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
      ),
      onChanged: widget.onChanged,
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
