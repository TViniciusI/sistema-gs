import 'package:flutter/material.dart';
import 'package:gs_mobile/core/keyboard_page_scroll.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/features/calibration/fluid_pick_page.dart';

class ClientSystemSheet extends StatefulWidget {
  const ClientSystemSheet({
    super.key,
    this.existing,
    this.systemTemplate,
  });

  final ClientSystem? existing;
  final ClientSystem? systemTemplate;

  @override
  State<ClientSystemSheet> createState() => _ClientSystemSheetState();
}

class _InstrumentEditors {
  _InstrumentEditors(ClientInstrument item)
    : id = item.id,
      role = item.role,
      tag = TextEditingController(text: item.tag),
      serial = TextEditingController(text: item.serialNumber),
      manufacturer = TextEditingController(text: item.manufacturer),
      model = TextEditingController(text: item.model),
      type = TextEditingController(text: item.equipmentType),
      principle = TextEditingController(text: item.workingPrinciple),
      products = [
        for (final p in splitClientProducts(item.product))
          TextEditingController(text: p),
        if (splitClientProducts(item.product).isEmpty) TextEditingController(),
      ],
      meshTag = TextEditingController(text: item.meshTag),
      meshSerial = TextEditingController(text: item.meshSerialNumber),
      meshManufacturer = TextEditingController(text: item.meshManufacturer),
      meshModel = TextEditingController(text: item.meshModel),
      meshType = TextEditingController(text: item.meshEquipmentType),
      meshPrinciple = TextEditingController(text: item.meshWorkingPrinciple);

  final String id;
  final ClientInstrumentRole role;
  final TextEditingController tag;
  final TextEditingController serial;
  final TextEditingController manufacturer;
  final TextEditingController model;
  final TextEditingController type;
  final TextEditingController principle;

  /// Um campo por produto; no cadastro vira "A, B, C".
  final List<TextEditingController> products;
  final TextEditingController meshTag;
  final TextEditingController meshSerial;
  final TextEditingController meshManufacturer;
  final TextEditingController meshModel;
  final TextEditingController meshType;
  final TextEditingController meshPrinciple;

  ClientInstrument toInstrument() {
    return ClientInstrument(
      id: id,
      role: role,
      tag: tag.text.trim(),
      serialNumber: serial.text.trim(),
      manufacturer: manufacturer.text.trim(),
      model: model.text.trim(),
      equipmentType: type.text.trim(),
      workingPrinciple: principle.text.trim(),
      product: productNames.join(', '),
      meshTag: meshTag.text.trim(),
      meshSerialNumber: meshSerial.text.trim(),
      meshManufacturer: meshManufacturer.text.trim(),
      meshModel: meshModel.text.trim(),
      meshEquipmentType: meshType.text.trim(),
      meshWorkingPrinciple: meshPrinciple.text.trim(),
    );
  }

  List<String> get productNames =>
      splitClientProducts([for (final c in products) c.text].join(','));

  void setProductCount(int count) {
    final n = count.clamp(1, 8);
    while (products.length < n) {
      products.add(TextEditingController());
    }
    while (products.length > n) {
      products.removeLast().dispose();
    }
  }

  void dispose() {
    tag.dispose();
    serial.dispose();
    manufacturer.dispose();
    model.dispose();
    type.dispose();
    principle.dispose();
    for (final c in products) {
      c.dispose();
    }
    meshTag.dispose();
    meshSerial.dispose();
    meshManufacturer.dispose();
    meshModel.dispose();
    meshType.dispose();
    meshPrinciple.dispose();
  }
}

class _ClientSystemSheetState extends State<ClientSystemSheet> {
  late final TextEditingController _systemType;
  late final TextEditingController _location;
  late final TextEditingController _systemTag;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _assemblyTag;
  late final TextEditingController _meters;
  late final TextEditingController _pt100;
  late final TextEditingController _densimeters;
  ClientAssemblyKind? _kind;
  late List<_InstrumentEditors> _editors;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing?.syncedCounts();
    final template = widget.systemTemplate;
    _systemType = TextEditingController(
      text: existing?.systemType ?? template?.systemType ?? '',
    );
    _location = TextEditingController(
      text: existing?.installLocation ?? template?.installLocation ?? '',
    );
    _systemTag = TextEditingController(
      text: existing?.tag ?? template?.tag ?? '',
    );
    _manufacturer = TextEditingController(
      text: existing?.manufacturer ?? '',
    );
    _model = TextEditingController(text: existing?.model ?? '');
    _serial = TextEditingController(text: existing?.serialNumber ?? '');
    _assemblyTag = TextEditingController(text: existing?.assemblyTag ?? '');
    _kind = existing?.kind;
    _meters = TextEditingController(text: '${existing?.meterCount ?? 0}');
    _pt100 = TextEditingController(text: '${existing?.pt100Count ?? 0}');
    _densimeters = TextEditingController(
      text: '${existing?.densimeterCount ?? 0}',
    );
    _editors = [
      for (final item in existing?.instruments ?? const <ClientInstrument>[])
        _InstrumentEditors(item),
    ];
    _syncEditors();
    CalibrationCatalog.instance.load();
  }

  @override
  void dispose() {
    _systemType.dispose();
    _location.dispose();
    _systemTag.dispose();
    _manufacturer.dispose();
    _model.dispose();
    _serial.dispose();
    _assemblyTag.dispose();
    _meters.dispose();
    _pt100.dispose();
    _densimeters.dispose();
    for (final editor in _editors) {
      editor.dispose();
    }
    super.dispose();
  }

  int _countOf(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  bool get _showsAssemblyHeader =>
      _kind == ClientAssemblyKind.preset ||
      _kind == ClientAssemblyKind.transmitter ||
      _kind == ClientAssemblyKind.presetAndTransmitter;

  bool get _showsCompanionCounts =>
      _kind == ClientAssemblyKind.preset ||
      _kind == ClientAssemblyKind.transmitter ||
      _kind == ClientAssemblyKind.presetAndTransmitter;

  bool get _showsMeterCount =>
      _kind == ClientAssemblyKind.preset ||
      _kind == ClientAssemblyKind.presetAndTransmitter;

  void _setKind(ClientAssemblyKind kind) {
    setState(() {
      _kind = kind;
      if (_showsMeterCount && _countOf(_meters) == 0) {
        _meters.text = '1';
      }
      if (kind == ClientAssemblyKind.pt100 && _countOf(_pt100) == 0) {
        _pt100.text = '1';
      }
      if (kind == ClientAssemblyKind.densimeter &&
          _countOf(_densimeters) == 0) {
        _densimeters.text = '1';
      }
      _syncEditors();
    });
  }

  void _syncEditors() {
    final kind = _kind;
    if (kind == null) {
      for (final editor in _editors) {
        editor.dispose();
      }
      _editors = [];
      return;
    }

    final wanted = <(ClientInstrumentRole, int)>[];
    switch (kind) {
      case ClientAssemblyKind.transmitter:
        wanted.add((ClientInstrumentRole.transmitter, 1));
        wanted.add((ClientInstrumentRole.meter, _countOf(_meters)));
        wanted.add((ClientInstrumentRole.pt100, _countOf(_pt100)));
        wanted.add((ClientInstrumentRole.densimeter, _countOf(_densimeters)));
      case ClientAssemblyKind.preset:
        wanted.add((ClientInstrumentRole.meter, _countOf(_meters)));
        wanted.add((ClientInstrumentRole.pt100, _countOf(_pt100)));
        wanted.add((ClientInstrumentRole.densimeter, _countOf(_densimeters)));
      case ClientAssemblyKind.presetAndTransmitter:
        wanted.add((ClientInstrumentRole.meter, _countOf(_meters)));
        wanted.add((ClientInstrumentRole.transmitter, 1));
        wanted.add((ClientInstrumentRole.pt100, _countOf(_pt100)));
        wanted.add((ClientInstrumentRole.densimeter, _countOf(_densimeters)));
      case ClientAssemblyKind.pt100:
        wanted.add((
          ClientInstrumentRole.pt100,
          _countOf(_pt100) < 1 ? 1 : _countOf(_pt100),
        ));
      case ClientAssemblyKind.densimeter:
        wanted.add((
          ClientInstrumentRole.densimeter,
          _countOf(_densimeters) < 1 ? 1 : _countOf(_densimeters),
        ));
      case ClientAssemblyKind.mesh:
        wanted.add((ClientInstrumentRole.mesh, 1));
    }

    final next = <_InstrumentEditors>[];
    for (final pair in wanted) {
      final current = [
        for (final editor in _editors)
          if (editor.role == pair.$1) editor,
      ];
      for (var i = 0; i < pair.$2; i++) {
        if (i < current.length) {
          next.add(current[i]);
        } else {
          String defaultPrinciple = '';
          String defaultMeshPrinciple = '';
          switch (pair.$1) {
            case ClientInstrumentRole.meter:
              defaultPrinciple = 'Medição Volumétrica';
              break;
            case ClientInstrumentRole.densimeter:
              defaultPrinciple = 'Tubo Vibratório';
              break;
            case ClientInstrumentRole.pt100:
              defaultPrinciple = 'Termorresistência';
              defaultMeshPrinciple = '';
              break;
            case ClientInstrumentRole.mesh:
              defaultPrinciple = 'Malha de temperatura';
              break;
            case ClientInstrumentRole.transmitter:
              defaultPrinciple = 'Transmissor';
              break;
          }
          next.add(
            _InstrumentEditors(
              ClientInstrument(
                id: '${DateTime.now().microsecondsSinceEpoch}-$i-${pair.$1.name}',
                role: pair.$1,
                workingPrinciple: defaultPrinciple,
                meshWorkingPrinciple: defaultMeshPrinciple,
                tag: pair.$1 == ClientInstrumentRole.transmitter
                    ? _assemblyTag.text.trim()
                    : '',
                serialNumber: pair.$1 == ClientInstrumentRole.transmitter &&
                        kind == ClientAssemblyKind.transmitter
                    ? _serial.text.trim()
                    : '',
                manufacturer:
                    pair.$1 == ClientInstrumentRole.transmitter &&
                        kind == ClientAssemblyKind.transmitter
                    ? _manufacturer.text.trim()
                    : '',
                model: pair.$1 == ClientInstrumentRole.transmitter &&
                        kind == ClientAssemblyKind.transmitter
                    ? _model.text.trim()
                    : '',
              ),
            ),
          );
        }
      }
      for (var i = pair.$2; i < current.length; i++) {
        current[i].dispose();
      }
    }
    for (final editor in _editors) {
      if (!next.contains(editor)) editor.dispose();
    }
    _editors = next;
  }

  ClientSystem _build() {
    final kind = _kind ?? ClientAssemblyKind.transmitter;
    final instruments = [for (final editor in _editors) editor.toInstrument()];
    var manufacturer = _manufacturer.text.trim();
    var model = _model.text.trim();
    var serial = _serial.text.trim();
    var assemblyTag = _assemblyTag.text.trim();
    if (kind == ClientAssemblyKind.transmitter) {
      ClientInstrument? tx;
      for (final item in instruments) {
        if (item.role == ClientInstrumentRole.transmitter) {
          tx = item;
          break;
        }
      }
      if (tx != null) {
        if (manufacturer.isEmpty) manufacturer = tx.manufacturer;
        if (model.isEmpty) model = tx.model;
        if (serial.isEmpty) serial = tx.serialNumber;
        if (assemblyTag.isEmpty) assemblyTag = tx.tag;
      }
    }
    return ClientSystem(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      systemType: _systemType.text.trim(),
      installLocation: _location.text.trim(),
      tag: _systemTag.text.trim(),
      kind: kind,
      manufacturer: manufacturer,
      model: model,
      serialNumber: serial,
      assemblyTag: assemblyTag,
      meterCount: _showsMeterCount ? _countOf(_meters) : 0,
      pt100Count: kind == ClientAssemblyKind.pt100
          ? (_countOf(_pt100) < 1 ? 1 : _countOf(_pt100))
          : (_showsCompanionCounts ? _countOf(_pt100) : 0),
      densimeterCount: kind == ClientAssemblyKind.densimeter
          ? (_countOf(_densimeters) < 1 ? 1 : _countOf(_densimeters))
          : (_showsCompanionCounts ? _countOf(_densimeters) : 0),
      instruments: instruments,
    ).syncedCounts();
  }

  void _trySave() {
    final outside = <String>{
      for (final editor in _editors)
        for (final name in editor.productNames)
          if (registeredFluidNamed(name) == null) name,
    };
    if (outside.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Produto sem cadastro: ${outside.join(', ')}. '
            'Escolha um produto da lista ou cadastre o produto novo.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, _build());
  }

  Widget _productField(_InstrumentEditors editor, int productIndex, int n) {
    final controller = editor.products[productIndex];
    return RegisteredFluidField(
      key: Key('sistema-inst-${editor.role.name}-$n-produto-$productIndex'),
      label: editor.products.length == 1
          ? 'Produto'
          : 'Produto ${productIndex + 1}',
      value: controller.text,
      onChanged: (fluid) => setState(() => controller.text = fluid.name),
      onClear: () => setState(controller.clear),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? (widget.systemTemplate == null
            ? 'Novo sistema'
            : 'Incluir equipamento neste sistema')
        : 'Editar equipamento';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: KeyboardPageScroll(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Primeiro os dados do sistema. Depois escolha o tipo: preset, transmissor, os dois, PT100, densímetro ou malha.',
              style: TextStyle(height: 1.35, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dados do sistema',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('sistema-tipo'),
              controller: _systemType,
              decoration: const InputDecoration(
                labelText: 'Tipo de sistema',
                helperText:
                    'Ex.: SISTEMA DE CARREGAMENTO, SISTEMA DE DESCARREGAMENTO, Telemetria. '
                    'Na calibração, tipos iguais aparecem juntos.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('sistema-local'),
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Local da instalação',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('sistema-tag'),
              controller: _systemTag,
              decoration: const InputDecoration(labelText: 'Tag do sistema'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tipo de equipamento',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Em Coriolis costuma haver preset e/ou transmissor; PT100 e densímetro entram quando o sistema tiver.',
              style: TextStyle(color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  (ClientAssemblyKind.preset, 'Preset', 'sistema-kind-preset'),
                  (
                    ClientAssemblyKind.transmitter,
                    'Transmissor',
                    'sistema-kind-transmissor',
                  ),
                  (
                    ClientAssemblyKind.presetAndTransmitter,
                    'Preset e transmissor',
                    'sistema-kind-ambos',
                  ),
                  (ClientAssemblyKind.pt100, 'PT100', 'sistema-kind-pt100'),
                  (
                    ClientAssemblyKind.densimeter,
                    'Densímetro',
                    'sistema-kind-densimetro',
                  ),
                  (ClientAssemblyKind.mesh, 'Malha', 'sistema-kind-malha'),
                ])
                  ChoiceChip(
                    key: Key(entry.$3),
                    label: Text(entry.$2),
                    selected: _kind == entry.$1,
                    onSelected: (_) => _setKind(entry.$1),
                  ),
              ],
            ),
            if (_kind != null) ...[
              if (_showsAssemblyHeader) ...[
                const SizedBox(height: 12),
                Text(
                  _kind == ClientAssemblyKind.transmitter
                      ? 'Transmissor'
                      : _kind == ClientAssemblyKind.presetAndTransmitter
                          ? 'Preset'
                          : 'Preset',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                if (_kind == ClientAssemblyKind.transmitter) ...[
                  // Campos do transmissor ficam no card do instrumento.
                ]                 else ...[
                  TextField(
                    key: const Key('sistema-preset-fabricante'),
                    controller: _manufacturer,
                    decoration: const InputDecoration(labelText: 'Fabricante'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('sistema-preset-modelo'),
                    controller: _model,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('sistema-preset-serie'),
                    controller: _serial,
                    decoration: const InputDecoration(
                      labelText: 'Número de série',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('sistema-preset-tag'),
                    controller: _assemblyTag,
                    decoration: const InputDecoration(labelText: 'Tag do preset'),
                  ),
                ],
              ],
              if (_showsCompanionCounts) ...[
                const SizedBox(height: 16),
                const Text(
                  'Quantidade de instrumentos no sistema',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                if (_showsMeterCount) ...[
                  TextField(
                    key: const Key('sistema-qtd-medidor'),
                    controller: _meters,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de medidor',
                    ),
                    onChanged: (_) => setState(_syncEditors),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  key: const Key('sistema-qtd-pt100'),
                  controller: _pt100,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de PT100',
                  ),
                  onChanged: (_) => setState(_syncEditors),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('sistema-qtd-densimetro'),
                  controller: _densimeters,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de densímetro',
                  ),
                  onChanged: (_) => setState(_syncEditors),
                ),
              ],
              if (_kind == ClientAssemblyKind.pt100) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('sistema-qtd-pt100'),
                  controller: _pt100,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de PT100',
                  ),
                  onChanged: (_) => setState(_syncEditors),
                ),
              ],
              if (_kind == ClientAssemblyKind.densimeter) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('sistema-qtd-densimetro'),
                  controller: _densimeters,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de densímetro',
                  ),
                  onChanged: (_) => setState(_syncEditors),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Cadastro de cada instrumento',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _kind == ClientAssemblyKind.mesh
                    ? 'Informe a malha deste sistema.'
                    : 'Abre um bloco para cada item. Em PT100 a malha correspondente já vem junto.',
                style: const TextStyle(color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _editors.length; i++)
                _instrumentCard(_editors[i], index: i),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('salvar-sistema'),
              onPressed: _kind == null ? null : _trySave,
              style: FilledButton.styleFrom(
                backgroundColor: GsTheme.brass,
                foregroundColor: Colors.black,
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instrumentCard(_InstrumentEditors editor, {required int index}) {
    final n = _editors
            .take(index)
            .where((item) => item.role == editor.role)
            .length +
        1;
    final isMeshOnly = editor.role == ClientInstrumentRole.mesh;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${clientInstrumentRoleLabel(editor.role)} $n',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 8),
            if (!isMeshOnly) ...[
              TextField(
                key: Key('sistema-inst-${editor.role.name}-$n-tag'),
                controller: editor.tag,
                decoration: const InputDecoration(labelText: 'Tag'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quantidade de produtos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                      ),
                    ),
                  ),
                  DropdownButton<int>(
                    key: Key('sistema-inst-${editor.role.name}-$n-qtd-produtos'),
                    value: editor.products.length,
                    items: [
                      for (var q = 1; q <= 8; q++)
                        DropdownMenuItem(value: q, child: Text('$q')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => editor.setProductCount(value));
                    },
                  ),
                ],
              ),
              if (editor.role == ClientInstrumentRole.meter &&
                  editor.products.length > 1)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Cada produto terá uma calibração (um certificado) na OS. '
                    'Na emissão só entra a densidade e a temperatura medidas.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                  ),
                ),
              AnimatedBuilder(
                animation: CalibrationCatalog.instance,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var p = 0; p < editor.products.length; p++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _productField(editor, p, n),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editor.serial,
                decoration: const InputDecoration(labelText: 'Número de série'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editor.manufacturer,
                decoration: const InputDecoration(labelText: 'Fabricante'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editor.model,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editor.type,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  helperText:
                      'Se vazio, usa ${clientInstrumentRoleLabel(editor.role)}.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editor.principle,
                decoration: const InputDecoration(
                  labelText: 'Princípio de funcionamento',
                ),
              ),
            ],
            if (editor.role == ClientInstrumentRole.pt100 || isMeshOnly) ...[
              if (!isMeshOnly) ...[
                const SizedBox(height: 14),
                Text(
                  'Malha $n',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cadastro da malha deste PT100.',
                  style: TextStyle(color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: Key(
                  isMeshOnly
                      ? 'sistema-inst-mesh-$n-tag'
                      : 'sistema-inst-${editor.role.name}-$n-malha-tag',
                ),
                controller: isMeshOnly ? editor.tag : editor.meshTag,
                decoration: InputDecoration(
                  labelText: isMeshOnly ? 'Tag da malha' : 'Tag da malha',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: isMeshOnly ? editor.serial : editor.meshSerial,
                decoration: const InputDecoration(
                  labelText: 'Número de série da malha',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller:
                    isMeshOnly ? editor.manufacturer : editor.meshManufacturer,
                decoration: const InputDecoration(
                  labelText: 'Fabricante da malha',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: isMeshOnly ? editor.model : editor.meshModel,
                decoration: const InputDecoration(labelText: 'Modelo da malha'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: isMeshOnly ? editor.type : editor.meshType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  helperText: 'Se vazio, usa Malha de temperatura.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller:
                    isMeshOnly ? editor.principle : editor.meshPrinciple,
                decoration: const InputDecoration(
                  labelText: 'Princípio de funcionamento',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
