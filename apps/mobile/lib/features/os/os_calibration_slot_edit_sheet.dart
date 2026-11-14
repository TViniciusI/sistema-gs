import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/features/calibration/fluid_pick_page.dart';

/// Lista completa do certificado (mesmos campos da planilha de cadastro).
Future<OsCalibrationSlot?> showOsCalibrationSlotEditSheet({
  required BuildContext context,
  required OsCalibrationSlot slot,
  bool allowEdit = true,
}) {
  return Navigator.of(context).push<OsCalibrationSlot>(
    MaterialPageRoute(
      builder: (context) => OsCalibrationSlotEditPage(
        slot: slot,
        allowEdit: allowEdit,
      ),
    ),
  );
}

class OsCalibrationSlotEditPage extends StatefulWidget {
  const OsCalibrationSlotEditPage({
    super.key,
    required this.slot,
    this.allowEdit = true,
  });

  final OsCalibrationSlot slot;
  final bool allowEdit;

  @override
  State<OsCalibrationSlotEditPage> createState() =>
      _OsCalibrationSlotEditPageState();
}

class _OsCalibrationSlotEditPageState extends State<OsCalibrationSlotEditPage> {
  // Sistema
  late final TextEditingController _systemType;
  late final TextEditingController _equipmentType;
  late final TextEditingController _installLocation;
  late final TextEditingController _quantity;
  // Medidor
  late final TextEditingController _workingPrinciple;
  late final TextEditingController _dimensions;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _tag;
  late final TextEditingController _product;
  // Preset ou transmissor
  late final TextEditingController _presetPrinciple;
  late final TextEditingController _presetManufacturer;
  late final TextEditingController _presetModel;
  late final TextEditingController _presetSerial;
  late final TextEditingController _presetTag;
  // Densímetro
  late final TextEditingController _densPrinciple;
  late final TextEditingController _densManufacturer;
  late final TextEditingController _densModel;
  late final TextEditingController _densSerial;
  late final TextEditingController _densTag;
  // Sensor de temperatura / PT100
  late final TextEditingController _ptPrinciple;
  late final TextEditingController _ptManufacturer;
  late final TextEditingController _ptModel;
  late final TextEditingController _ptSerial;
  late final TextEditingController _ptTag;
  // Transmissor de pressão
  late final TextEditingController _pressureType;
  late final TextEditingController _pressurePrinciple;
  late final TextEditingController _pressureManufacturer;
  late final TextEditingController _pressureModel;
  late final TextEditingController _pressureSerial;
  late final TextEditingController _pressureTag;
  // Telemetria
  late final TextEditingController _telemetryPrinciple;
  late final TextEditingController _telemetryManufacturer;
  late final TextEditingController _telemetryModel;
  late final TextEditingController _telemetrySerial;
  late final TextEditingController _telemetryTag;

  late final List<TextEditingController> _all;

  @override
  void initState() {
    super.initState();
    final s = widget.slot;
    _systemType = TextEditingController(text: s.systemType);
    _equipmentType = TextEditingController(text: s.equipmentType);
    _installLocation = TextEditingController(text: s.installLocation);
    _quantity = TextEditingController(text: s.quantity);
    _workingPrinciple = TextEditingController(text: s.workingPrinciple);
    _dimensions = TextEditingController(text: s.dimensions);
    _manufacturer = TextEditingController(text: s.manufacturer);
    _model = TextEditingController(text: s.model);
    _serial = TextEditingController(text: s.serialNumber);
    _tag = TextEditingController(text: s.equipmentTag);
    _product = TextEditingController(text: s.product);
    _presetPrinciple = TextEditingController(text: s.presetWorkingPrinciple);
    _presetManufacturer = TextEditingController(text: s.presetManufacturer);
    _presetModel = TextEditingController(text: s.presetModel);
    _presetSerial = TextEditingController(text: s.presetSerial);
    _presetTag = TextEditingController(text: s.presetTag);
    _densPrinciple =
        TextEditingController(text: s.densimeterWorkingPrinciple);
    _densManufacturer =
        TextEditingController(text: s.densimeterManufacturer);
    _densModel = TextEditingController(text: s.densimeterModel);
    _densSerial = TextEditingController(text: s.densimeterSerial);
    _densTag = TextEditingController(text: s.densimeterTag);
    _ptPrinciple = TextEditingController(text: s.pt100WorkingPrinciple);
    _ptManufacturer = TextEditingController(text: s.pt100Manufacturer);
    _ptModel = TextEditingController(text: s.pt100Model);
    _ptSerial = TextEditingController(text: s.pt100Serial);
    _ptTag = TextEditingController(text: s.pt100Tag);
    _pressureType = TextEditingController(text: s.pressureType);
    _pressurePrinciple =
        TextEditingController(text: s.pressureWorkingPrinciple);
    _pressureManufacturer =
        TextEditingController(text: s.pressureManufacturer);
    _pressureModel = TextEditingController(text: s.pressureModel);
    _pressureSerial = TextEditingController(text: s.pressureSerial);
    _pressureTag = TextEditingController(text: s.pressureTag);
    _telemetryPrinciple =
        TextEditingController(text: s.telemetryWorkingPrinciple);
    _telemetryManufacturer =
        TextEditingController(text: s.telemetryManufacturer);
    _telemetryModel = TextEditingController(text: s.telemetryModel);
    _telemetrySerial = TextEditingController(text: s.telemetrySerial);
    _telemetryTag = TextEditingController(text: s.telemetryTag);
    _all = [
      _systemType,
      _equipmentType,
      _installLocation,
      _quantity,
      _workingPrinciple,
      _dimensions,
      _manufacturer,
      _model,
      _serial,
      _tag,
      _product,
      _presetPrinciple,
      _presetManufacturer,
      _presetModel,
      _presetSerial,
      _presetTag,
      _densPrinciple,
      _densManufacturer,
      _densModel,
      _densSerial,
      _densTag,
      _ptPrinciple,
      _ptManufacturer,
      _ptModel,
      _ptSerial,
      _ptTag,
      _pressureType,
      _pressurePrinciple,
      _pressureManufacturer,
      _pressureModel,
      _pressureSerial,
      _pressureTag,
      _telemetryPrinciple,
      _telemetryManufacturer,
      _telemetryModel,
      _telemetrySerial,
      _telemetryTag,
    ];
    CalibrationCatalog.instance.load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  OsCalibrationSlot _build() {
    final kind = calibrationKindFrom(widget.slot.kind);
    final isTempMesh = kind == CalibrationKind.temperatureMesh;
    final principle = _workingPrinciple.text.trim();
    final mfg = _manufacturer.text.trim();
    final model = _model.text.trim();
    final serial = _serial.text.trim();
    final tag = _tag.text.trim();
    final ptPrinciple = _ptPrinciple.text.trim();
    final ptMfg = _ptManufacturer.text.trim();
    final ptModel = _ptModel.text.trim();
    final ptSerial = _ptSerial.text.trim();
    final ptTag = _ptTag.text.trim();
    return widget.slot.copyWith(
      systemType: _systemType.text.trim(),
      equipmentType: _equipmentType.text.trim(),
      installLocation: _installLocation.text.trim(),
      quantity: _quantity.text.trim(),
      workingPrinciple: principle,
      dimensions: _dimensions.text.trim(),
      manufacturer: mfg,
      model: model,
      serialNumber: serial,
      equipmentTag: tag,
      product: _product.text.trim(),
      presetWorkingPrinciple: _presetPrinciple.text.trim(),
      presetManufacturer: _presetManufacturer.text.trim(),
      presetModel: _presetModel.text.trim(),
      presetSerial: _presetSerial.text.trim(),
      presetTag: _presetTag.text.trim(),
      densimeterWorkingPrinciple: _densPrinciple.text.trim(),
      densimeterManufacturer: _densManufacturer.text.trim(),
      densimeterModel: _densModel.text.trim(),
      densimeterSerial: _densSerial.text.trim(),
      densimeterTag: _densTag.text.trim(),
      pt100WorkingPrinciple: ptPrinciple,
      pt100Manufacturer: ptMfg,
      pt100Model: ptModel,
      pt100Serial: ptSerial,
      pt100Tag: ptTag,
      pressureType: _pressureType.text.trim(),
      pressureWorkingPrinciple: _pressurePrinciple.text.trim(),
      pressureManufacturer: _pressureManufacturer.text.trim(),
      pressureModel: _pressureModel.text.trim(),
      pressureSerial: _pressureSerial.text.trim(),
      pressureTag: _pressureTag.text.trim(),
      telemetryWorkingPrinciple: _telemetryPrinciple.text.trim(),
      telemetryManufacturer: _telemetryManufacturer.text.trim(),
      telemetryModel: _telemetryModel.text.trim(),
      telemetrySerial: _telemetrySerial.text.trim(),
      telemetryTag: _telemetryTag.text.trim(),
      // Malha de temperatura: bloco "Malha" (campos principais) ou PT100.
      meshWorkingPrinciple: isTempMesh ? principle : ptPrinciple,
      meshManufacturer: isTempMesh ? mfg : ptMfg,
      meshModel: isTempMesh ? model : ptModel,
      meshSerialNumber: isTempMesh ? serial : ptSerial,
      meshTag: isTempMesh ? tag : ptTag,
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _row(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        readOnly: !widget.allowEdit,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _productRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RegisteredFluidField(
        key: const Key('os-slot-produto'),
        label: 'Produto',
        value: _product.text,
        enabled: widget.allowEdit,
        onChanged: (fluid) => setState(() => _product.text = fluid.name),
        onClear: () => setState(_product.clear),
      ),
    );
  }

  void _save() {
    final product = _product.text.trim();
    if (product.isNotEmpty && registeredFluidNamed(product) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Produto sem cadastro: $product. '
            'Escolha um produto da lista ou cadastre o produto novo.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, _build());
  }

  @override
  Widget build(BuildContext context) {
    final kind = calibrationKindFrom(widget.slot.kind);
    final isTelemetry = kind == CalibrationKind.telemetry;
    final isTempMesh = kind == CalibrationKind.temperatureMesh;
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: Text(widget.slot.certificateNumber),
        actions: [
          if (widget.allowEdit)
            TextButton(
              onPressed: _save,
              child: const Text(
                'Salvar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            '${calibrationKindLabel(kind)} · dados do instrumento',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.allowEdit
                ? (isTelemetry
                    ? 'Preencha sistema e os dados do instrumento de telemetria.'
                    : isTempMesh
                        ? 'Preencha preset/transmissor, malha de temperatura e sensor PT100.'
                        : 'Preencha por bloco, como na planilha: sistema, medidor, '
                            'preset/transmissor, densímetro, PT100, pressão e telemetria. '
                            'Ao salvar, os dados entram no cadastro do cliente.')
                : 'Dados do instrumento (somente leitura).',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF5C6570),
            ),
          ),
          if (isTempMesh) ...[
            _header('Preset ou transmissor'),
            _row('Princípio de funcionamento', _presetPrinciple),
            _row('Quantidade', _quantity),
            _row('Fabricante', _presetManufacturer),
            _row('Modelo', _presetModel),
            _row('Nº de série', _presetSerial),
            _row('Tag', _presetTag),
            _header('Malha de temperatura'),
            _row('Princípio de funcionamento', _workingPrinciple),
            _row('Fabricante', _manufacturer),
            _row('Modelo', _model),
            _row('Nº de série', _serial),
            _row('Tag', _tag),
            _header('Sensor de temperatura / PT100'),
            _row('Princípio de funcionamento', _ptPrinciple),
            _row('Fabricante', _ptManufacturer),
            _row('Modelo', _ptModel),
            _row('Nº de série', _ptSerial),
            _row('Tag', _ptTag),
          ] else if (isTelemetry) ...[
            _header('Sistema'),
            _row('Tipo de sistema', _systemType),
            _row('Tipo de equipamento', _equipmentType),
            _row('Local da instalação', _installLocation),
            _row('Quantidade', _quantity),
            _header('Instrumento'),
            _row('Princípio de funcionamento', _workingPrinciple),
            _row('Fabricante', _manufacturer),
            _row('Modelo', _model),
            _row('Nº de série', _serial),
            _row('Tag', _tag),
            _productRow(),
          ] else ...[
            _header('Sistema'),
            _row('Tipo de sistema', _systemType),
            _row('Tipo de equipamento', _equipmentType),
            _row('Local da instalação', _installLocation),
            _row('Quantidade', _quantity),
            _header('Medidor'),
            _row('Princípio de funcionamento', _workingPrinciple),
            _row('Dimensão', _dimensions),
            _row('Fabricante', _manufacturer),
            _row('Modelo', _model),
            _row('Nº de série', _serial),
            _row('Tag', _tag),
            _productRow(),
            _header('Preset ou transmissor'),
            _row('Princípio de funcionamento', _presetPrinciple),
            _row('Fabricante', _presetManufacturer),
            _row('Modelo', _presetModel),
            _row('Nº de série', _presetSerial),
            _row('Tag', _presetTag),
            _header('Densímetro'),
            _row('Princípio de funcionamento', _densPrinciple),
            _row('Fabricante', _densManufacturer),
            _row('Modelo', _densModel),
            _row('Nº de série', _densSerial),
            _row('Tag', _densTag),
            _header('Sensor de temperatura / PT100'),
            _row('Princípio de funcionamento', _ptPrinciple),
            _row('Fabricante', _ptManufacturer),
            _row('Modelo', _ptModel),
            _row('Nº de série', _ptSerial),
            _row('Tag', _ptTag),
            _header('Transmissor de pressão'),
            _row('Tipo do instrumento', _pressureType),
            _row('Princípio de funcionamento', _pressurePrinciple),
            _row('Fabricante', _pressureManufacturer),
            _row('Modelo', _pressureModel),
            _row('Nº de série', _pressureSerial),
            _row('Tag', _pressureTag),
            _header('Telemetria'),
            _row('Princípio de funcionamento', _telemetryPrinciple),
            _row('Fabricante', _telemetryManufacturer),
            _row('Modelo', _telemetryModel),
            _row('Nº de série', _telemetrySerial),
            _row('Tag', _telemetryTag),
          ],
          const SizedBox(height: 12),
          if (widget.allowEdit)
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar dados do certificado'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
        ],
      ),
    );
  }
}
