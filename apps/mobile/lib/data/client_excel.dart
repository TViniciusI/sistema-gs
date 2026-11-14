import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';

const clientExcelFileName = 'GS_Calibracao_cadastro.xlsx';

class ClientWorkbookResult {
  const ClientWorkbookResult({
    required this.created,
    required this.updated,
    required this.instruments,
    required this.message,
  });

  final int created;
  final int updated;
  final int instruments;
  final String message;
}

class ParsedInstrument {
  const ParsedInstrument({
    required this.clientName,
    required this.cnpj,
    required this.equipment,
  });

  final String clientName;
  final String cnpj;
  final ClientEquipment equipment;
}

class ParsedWorkbook {
  const ParsedWorkbook({required this.clients, required this.instruments});

  final List<SavedClient> clients;
  final List<ParsedInstrument> instruments;
}

List<int> buildClientExcelTemplate({
  List<SavedClient> clients = const [],
  bool withExample = false,
}) {
  final excel = Excel.createExcel();
  final guide = excel['Leia-me'];
  for (final line in const [
    'Planilha padrão GS Campo · Calibração',
    '',
    'Aba Clientes: um cliente por linha. Endereço (CEP, rua, número, complemento, bairro, cidade, estado) e responsável da base.',
    'Não preencha serviço, tipo de serviço nem local do serviço no cliente — isso entra na OS, na hora do trabalho.',
    'Aba Instrumentos: um instrumento sob calibração por linha, ligado ao cliente pelo CNPJ (melhor) ou pelo nome.',
    'Ao importar, os instrumentos da planilha SUBSTITUEM o cadastro daquele cliente (linha apagada no Excel some do app).',
    'Não altere os cabeçalhos. No app, abra Calibração (escritório) e toque em Importar.',
    'Fluxo recomendado: baixar → conferir/corrigir → importar de novo.',
    'Padrão Cleber (Phoenix): 46 colunas na aba Instrumentos — não altere os nomes.',
    'Ordem: Cliente/CNPJ → sistema → local → preset → transmissor → medidor → sensor de temperatura → densímetro → malha → telemetria → pressão.',
    'Removidos: Tag do sistema, Princípio do preset, Função, Tipo de equipamento, Quantidade, Princípio do transmissor, Tipo da malha e Princípio da pressão.',
    'Medidor: princípio, dimensões, fabricante, modelo, N/S, tag e produto utilizado.',
    'Telemetria inclui “Produto do tanque - Telemetria”.',
    'Na calibração: Cliente → Tipo de sistema → Local → Produto (se houver) → TAG do medidor.',
    'Tipos no app: Preset, Transmissor, Preset e transmissor, PT100/sensor, Densímetro e Malha.',
  ]) {
    guide.appendRow([TextCellValue(line)]);
  }

  final clientSheet = excel['Clientes'];
  clientSheet.appendRow([
    for (final header in const [
      'Solicitante do serviço',
      'Cliente',
      'CNPJ',
      'CEP',
      'Endereco',
      'Numero',
      'Complemento',
      'Bairro',
      'Cidade',
      'Estado',
      'Responsavel',
      'Cargo',
      'Email',
      'Telefone',
    ])
      TextCellValue(header),
  ]);

  final instrumentSheet = excel['Instrumentos'];
  instrumentSheet.appendRow([
    for (final header in const [
      'Cliente',
      'CNPJ',
      'Tipo de sistema',
      'local de Instalação do sistema',
      'Preset ou transmissor',
      'Fabricante do preset',
      'Modelo do preset',
      'Numero de serie do preset',
      'Tag do preset',
      'Fabricante do transmissor',
      'Modelo do transmissor',
      'N/S do transmissor',
      'Tag do transmissor',
      'Principio do Medidor',
      'Dimensoes do medidor',
      'Fabricante do medidor',
      'Modelo do medidor',
      'Numero de serie do medidor',
      'Tag do medidor',
      'Produto utilizado no medidor',
      'Principio do Sensor de temperatura',
      'Fabricante do sensor de temperatura',
      'Modelo do sensor de temperatura',
      'N/S do sensor de temperatura',
      'Tag do sensor de temperatura',
      'Principio do Sensor do densimetro',
      'Fabricante do densimetro',
      'Modelo do densimetro',
      'N/S do densimetro',
      'Tag do densimetro',
      'Principio da malha',
      'Fabricante da malha',
      'Modelo da malha',
      'N/S da malha',
      'Tag da malha',
      'Principio da telemetria',
      'Fabricante da telemetria',
      'Modelo da telemetria',
      'N/S da telemetria',
      'Tag da telemetria',
      'Produto do tanque - Telemetria',
      'Tipo do Instrumento de pressao',
      'Fabricante da pressao',
      'Modelo da pressao',
      'N/S da pressao',
      'Tag da pressao',
    ])
      TextCellValue(header),
  ]);

  final source = [
    ...clients,
    if (clients.isEmpty && withExample) _sampleClient(),
  ];
  for (final client in source) {
    clientSheet.appendRow(_clientValues(client));
    final systems = client.resolvedSystems;
    if (systems.isEmpty) {
      for (final item in client.equipment) {
        instrumentSheet.appendRow(_instrumentValues(client, item));
      }
    } else {
      for (final system in systems) {
        for (final row in _systemRowValues(client, system)) {
          instrumentSheet.appendRow(row);
        }
      }
    }
  }

  for (final name in List<String>.from(excel.sheets.keys)) {
    if (name != 'Clientes' && name != 'Instrumentos' && name != 'Leia-me') {
      excel.delete(name);
    }
  }

  // save() no navegador já baixa um "FlutterExcel.xlsx" sozinho.
  return excel.encode() ?? const [];
}

Future<ClientWorkbookResult> importClientWorkbook(
  List<int> bytes, {
  SavedClient? onlyClient,
}) async {
  final parsed = parseClientWorkbook(bytes);
  final store = ClientStore.instance;
  var created = 0;
  var updated = 0;
  var instruments = 0;
  final touched = <String>{};

  SavedClient? matchOf(String name, String cnpj) {
    if (onlyClient != null) return store.byId(onlyClient.id) ?? onlyClient;
    return store.findMatch(cnpj: cnpj, name: name);
  }

  for (final incoming in parsed.clients) {
    if (onlyClient != null &&
        !_isSameClient(onlyClient, incoming.name, incoming.cnpj)) {
      continue;
    }
    final existing = matchOf(incoming.name, incoming.cnpj);
    if (existing == null) {
      touched.add((await store.save(incoming, syncRemote: false)).id);
      created++;
      continue;
    }
    touched.add(
      (await store.save(
        existing.copyWith(
          name: incoming.name.isEmpty ? existing.name : incoming.name,
          requester: incoming.requester.isEmpty
              ? existing.requester
              : incoming.requester,
          cnpj: incoming.cnpj.isEmpty ? existing.cnpj : incoming.cnpj,
          cep: incoming.cep.isEmpty ? existing.cep : incoming.cep,
          street: incoming.street.isEmpty ? existing.street : incoming.street,
          number: incoming.number.isEmpty ? existing.number : incoming.number,
          complement: incoming.complement.isEmpty
              ? existing.complement
              : incoming.complement,
          neighborhood: incoming.neighborhood.isEmpty
              ? existing.neighborhood
              : incoming.neighborhood,
          city: incoming.city.isEmpty ? existing.city : incoming.city,
          state: incoming.state.isEmpty ? existing.state : incoming.state,
          service: incoming.service.isEmpty
              ? existing.service
              : incoming.service,
          systemType: incoming.systemType.isEmpty
              ? existing.systemType
              : incoming.systemType,
          baseName: incoming.baseName.isEmpty
              ? existing.baseName
              : incoming.baseName,
          baseCargo: incoming.baseCargo.isEmpty
              ? existing.baseCargo
              : incoming.baseCargo,
          baseEmail: incoming.baseEmail.isEmpty
              ? existing.baseEmail
              : incoming.baseEmail,
          basePhone: incoming.basePhone.isEmpty
              ? existing.basePhone
              : incoming.basePhone,
          baseContacts:
              incoming.resolvedBaseContacts.length >
                  existing.resolvedBaseContacts.length
              ? incoming.resolvedBaseContacts
              : existing.resolvedBaseContacts,
          sites: [...existing.sites, ...incoming.sites],
        ),
        syncRemote: false,
      )).id,
    );
    updated++;
  }

  final instrumentsByClient = <String, List<ClientEquipment>>{};
  final clientMeta = <String, ({String name, String cnpj})>{};

  for (final row in parsed.instruments) {
    if (onlyClient != null &&
        !_isSameClient(onlyClient, row.clientName, row.cnpj)) {
      continue;
    }
    final key =
        onlyClient?.id ??
        (row.cnpj.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
            ? row.cnpj.replaceAll(RegExp(r'[^0-9]'), '')
            : row.clientName.trim().toLowerCase());
    if (key.isEmpty) continue;
    instrumentsByClient.putIfAbsent(key, () => []).add(row.equipment);
    clientMeta.putIfAbsent(
      key,
      () => (name: row.clientName.trim(), cnpj: row.cnpj.trim()),
    );
    instruments++;
  }

  for (final entry in instrumentsByClient.entries) {
    final meta = clientMeta[entry.key]!;
    var client = matchOf(meta.name, meta.cnpj);
    if (client == null) {
      final name = meta.name.isEmpty ? meta.cnpj : meta.name;
      if (name.isEmpty) continue;
      client = await store.save(
        SavedClient(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          cnpj: meta.cnpj,
          updatedAt: DateTime.now(),
        ),
        syncRemote: false,
      );
      created++;
    }
    final incomingSystems = keepCatalogIds(
      client.resolvedSystems,
      systemsFromEquipment(entry.value),
    );
    // A planilha é a fonte da verdade para os instrumentos deste cliente:
    // linhas apagadas no Excel saem do cadastro (não faz merge com o antigo).
    client = await store.save(
      client.copyWith(
        systems: incomingSystems,
        equipment: flattenClientSystems(incomingSystems),
      ),
      syncRemote: false,
    );
    touched.add(client.id);
    updated++;
  }

  for (final id in touched) {
    final client = store.byId(id);
    if (client != null) await store.save(client);
  }

  final parts = [
    if (created > 0) '$created cliente(s) novo(s)',
    if (updated > 0) '$updated atualização(ões)',
    if (instruments > 0) '$instruments instrumento(s) na planilha',
  ];
  return ClientWorkbookResult(
    created: created,
    updated: updated,
    instruments: instruments,
    message: parts.isEmpty
        ? 'Nenhuma linha válida na planilha.'
        : 'Importado (instrumentos do Excel substituem o cadastro daquele cliente): '
              '${parts.join(' · ')}.'
              '${store.localCacheFull ? ' Foi para a nuvem, mas o navegador está sem espaço para guardar offline.' : ''}',
  );
}

ParsedWorkbook parseClientWorkbook(List<int> bytes) {
  final excel = Excel.decodeBytes(
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
  );
  final clients = <SavedClient>[];
  final instruments = <ParsedInstrument>[];

  for (final name in excel.tables.keys) {
    final sheet = excel.tables[name];
    if (sheet == null || sheet.rows.isEmpty) continue;
    final folded = _fold(name);
    if (folded.contains('leia')) continue;

    if (folded.contains('instrumento') && _isCleberInstrumentSheet(sheet)) {
      instruments.addAll(_parseCleberInstrumentRows(sheet));
      continue;
    }

    final headerIndex = _headerRowIndex(sheet);
    if (headerIndex < 0) continue;
    final headerRow = sheet.rows[headerIndex];
    final keys = [for (final cell in headerRow) _key(_cell(cell))];
    if (keys.every((item) => item.isEmpty)) continue;

    final asInstrument =
        folded.contains('instrumento') ||
        folded.contains('equipamento') ||
        keys.contains('equipmentType') ||
        keys.contains('serialNumber') ||
        keys.contains('tag') ||
        keys.contains('assemblyKind') ||
        keys.contains('presetTag');
    final asClient =
        (folded.contains('cliente') && !asInstrument) ||
        ((keys.contains('street') || keys.contains('cep')) &&
            !keys.contains('equipmentType'));

    for (var i = headerIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final map = <String, String>{};
      for (var c = 0; c < keys.length && c < row.length; c++) {
        if (keys[c].isEmpty) continue;
        map[keys[c]] = _cell(row[c]);
      }
      if (map.values.every((value) => value.trim().isEmpty)) continue;

      if (asClient && !asInstrument) {
        final client = _clientOf(map);
        if (client.name.trim().isNotEmpty || client.cnpj.trim().isNotEmpty) {
          clients.add(client);
        }
        continue;
      }

      instruments.addAll(_expandInstrumentMap(map));
      if ((map['street'] ?? '').trim().isNotEmpty ||
          (map['cep'] ?? '').trim().isNotEmpty) {
        final client = _clientOf(map);
        if (client.name.trim().isNotEmpty || client.cnpj.trim().isNotEmpty) {
          clients.add(client);
        }
      }
    }
  }
  return ParsedWorkbook(clients: clients, instruments: instruments);
}

int _headerRowIndex(Sheet sheet) {
  final limit = sheet.rows.length < 6 ? sheet.rows.length : 6;
  for (var i = 0; i < limit; i++) {
    final keys = [for (final cell in sheet.rows[i]) _key(_cell(cell))];
    final score = keys.where((item) => item.isNotEmpty).length;
    if (score >= 3 &&
        (keys.contains('name') ||
            keys.contains('cnpj') ||
            keys.contains('tag') ||
            keys.contains('equipmentType'))) {
      return i;
    }
  }
  return sheet.rows.isEmpty ? -1 : 0;
}

bool _isCleberInstrumentSheet(Sheet sheet) {
  if (sheet.rows.length < 4) return false;
  final top = _fold(
    _cell(sheet.rows.first.isEmpty ? null : sheet.rows.first.first),
  );
  if (!top.contains('dados do cliente')) return false;
  final header = sheet.rows[2];
  if (header.length < 12) return false;
  final labels = [for (final cell in header) _fold(_cell(cell))];
  return labels.contains('cliente') &&
      labels.contains('tag') &&
      labels.contains('fabricante');
}

String _rowCell(List<Data?> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return _cell(row[index]);
}

List<ParsedInstrument> _parseCleberInstrumentRows(Sheet sheet) {
  final out = <ParsedInstrument>[];
  for (var i = 3; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    final map = <String, String>{
      'name': _rowCell(row, 0),
      'cnpj': _rowCell(row, 1),
      'systemType': _rowCell(row, 2),
      'equipmentType': _rowCell(row, 3),
      'quantity': _rowCell(row, 4),
      'workingPrinciple': _rowCell(row, 5),
      'dimensions': _rowCell(row, 6),
      'manufacturer': _rowCell(row, 7),
      'model': _rowCell(row, 8),
      'serialNumber': _rowCell(row, 9),
      'tag': _rowCell(row, 10),
      'installLocation': _rowCell(row, 11),
      'presetManufacturer': _rowCell(row, 12),
      'presetModel': _rowCell(row, 13),
      'presetSerial': _rowCell(row, 14),
      'presetTag': _rowCell(row, 15),
      'transmitterManufacturer': _rowCell(row, 16),
      'transmitterModel': _rowCell(row, 17),
      'transmitterSerial': _rowCell(row, 18),
      'transmitterTag': _rowCell(row, 19),
      'densimeterManufacturer': _rowCell(row, 20),
      'densimeterModel': _rowCell(row, 21),
      'densimeterSerial': _rowCell(row, 22),
      'densimeterTag': _rowCell(row, 23),
      'pt100Manufacturer': _rowCell(row, 24),
      'pt100Model': _rowCell(row, 25),
      'pt100Serial': _rowCell(row, 26),
      'pt100Tag': _rowCell(row, 27),
      // Malha de temperatura (REV.01): Produto | local | N/S | Tag
      'product': _rowCell(row, 28),
      'meshSerialNumber': _rowCell(row, 30),
      'meshTag': _rowCell(row, 31),
    };
    if (map.values.every((value) => value.trim().isEmpty)) continue;
    out.addAll(_expandInstrumentMap(map));
  }
  return out;
}

bool _filled(String? a, String? b, String? c, String? d) {
  return (a ?? '').trim().isNotEmpty ||
      (b ?? '').trim().isNotEmpty ||
      (c ?? '').trim().isNotEmpty ||
      (d ?? '').trim().isNotEmpty;
}

bool _looksLikeTempTag(String raw) {
  final value = raw.trim().toUpperCase();
  if (value.isEmpty) return false;
  return RegExp(r'^TE[\s\-_]?\d', caseSensitive: false).hasMatch(value) ||
      RegExp(r'^TT[\s\-_]?\d', caseSensitive: false).hasMatch(value);
}

bool _looksLikePrincipleWord(String raw) {
  final value = _fold(raw);
  return value.contains('termorresist') ||
      value.contains('principio') ||
      value == 'sensor' ||
      value.contains('tubo vibrat');
}

bool _looksLikeDensBrand(String raw) {
  final value = _fold(raw);
  if (value.isEmpty) return false;
  // Marcas / textos que caíram na coluna de princípio do sensor na Phoenix.
  return value == 'alutal' ||
      value.contains('micro motion') ||
      value.contains('endomness') ||
      (value.contains('dens') && !value.contains('termorresist'));
}

/// Cleber Phoenix: colunas do sensor/densímetro costumam vir deslocadas.
/// Ex.: princípio do sensor = ALUTAL, tag = Termorresistência, N/S = TE1.
({
  String principle,
  String manufacturer,
  String model,
  String serial,
  String tag,
  String densPrincipleFromShift,
})
_normalizeCleberTempSensor({
  required String principle,
  required String manufacturer,
  required String model,
  required String serial,
  required String tag,
}) {
  var p = principle.trim();
  var mfg = manufacturer.trim();
  var mod = model.trim();
  var ser = serial.trim();
  var t = tag.trim();
  var densMoved = '';

  // ALUTAL (etc.) no princípio do sensor → na verdade é densímetro.
  if (_looksLikeDensBrand(p)) {
    densMoved = p;
    p = '';
  }

  final tagIsPrinciple =
      t.toLowerCase().contains('termorresist') ||
      (_looksLikePrincipleWord(t) && !_looksLikeTempTag(t));
  final serialIsTag = _looksLikeTempTag(ser);
  final principleIsRoleName =
      _fold(p) == 'pt100' || _fold(p) == 'medidor' || p.isEmpty;

  // Tag trouxe o princípio (Termorresistência) e N/S trouxe a TAG (TE1).
  if (serialIsTag && tagIsPrinciple) {
    final realPrinciple = t.toLowerCase().contains('termorresist')
        ? t
        : (t.isNotEmpty ? t : 'Termorresistência');
    t = ser;
    ser = mod;
    mod = '';
    p = realPrinciple;
  } else if (t.toLowerCase().contains('termorresist') && principleIsRoleName) {
    p = t;
    if (serialIsTag) {
      t = ser;
      ser = mod;
      mod = '';
    } else {
      t = '';
    }
  }

  if (p.isEmpty || _fold(p) == 'pt100' || _fold(p) == 'medidor') {
    p = 'Termorresistência';
  }

  return (
    principle: p,
    manufacturer: mfg,
    model: mod,
    serial: ser,
    tag: t,
    densPrincipleFromShift: densMoved,
  );
}

List<ParsedInstrument> _expandInstrumentMap(Map<String, String> map) {
  final explicitSysId = (map['systemId'] ?? '').trim();
  final rowSystemId = explicitSysId.isNotEmpty
      ? explicitSysId
      : 'sys-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(999999)}';

  final hasPreset = _filled(
    map['presetTag'],
    map['presetManufacturer'],
    map['presetModel'],
    map['presetSerial'],
  );
  final hasTx = _filled(
    map['transmitterTag'],
    map['transmitterManufacturer'],
    map['transmitterModel'],
    map['transmitterSerial'],
  );
  final rawPtPrinciple = (map['pt100Principle'] ?? '').trim();
  final normalizedPt = _normalizeCleberTempSensor(
    principle: rawPtPrinciple,
    manufacturer: map['pt100Manufacturer'] ?? '',
    model: map['pt100Model'] ?? '',
    serial: map['pt100Serial'] ?? '',
    tag: map['pt100Tag'] ?? '',
  );
  final densPrinciple = (map['densimeterPrinciple'] ?? '').trim().isNotEmpty
      ? (map['densimeterPrinciple'] ?? '').trim()
      : normalizedPt.densPrincipleFromShift.trim();
  final hasDens =
      _filled(
        map['densimeterTag'],
        map['densimeterManufacturer'],
        map['densimeterModel'],
        map['densimeterSerial'],
      ) ||
      densPrinciple.isNotEmpty;
  // Não cria PT100 só porque ALUTAL (densímetro) caiu na coluna de princípio.
  final hasPt =
      _filled(
        normalizedPt.tag,
        normalizedPt.manufacturer,
        normalizedPt.model,
        normalizedPt.serial,
      ) ||
      (rawPtPrinciple.isNotEmpty &&
          !_looksLikeDensBrand(rawPtPrinciple) &&
          _fold(rawPtPrinciple) != 'pt100');
  final hasTelemetry =
      _filled(
        map['telemetryTag'],
        map['telemetryManufacturer'],
        map['telemetryModel'],
        map['telemetrySerial'],
      ) ||
      (map['telemetryPrinciple'] ?? '').trim().isNotEmpty ||
      (map['telemetryProduct'] ?? '').trim().isNotEmpty;
  final hasPressure =
      _filled(
        map['pressureTag'],
        map['pressureManufacturer'],
        map['pressureModel'],
        map['pressureSerial'],
      ) ||
      (map['pressurePrinciple'] ?? '').trim().isNotEmpty ||
      (map['pressureType'] ?? '').trim().isNotEmpty;

  var assemblyKind = map['assemblyKind'] ?? '';
  if (assemblyKind.trim().isEmpty) {
    if (hasPreset && hasTx) {
      assemblyKind = clientAssemblyKindLabel(
        ClientAssemblyKind.presetAndTransmitter,
      );
    } else if (hasPreset) {
      assemblyKind = 'Preset';
    } else if (hasTx) {
      assemblyKind = 'Transmissor';
    }
  }
  map = {...map, 'assemblyKind': assemblyKind, 'systemId': rowSystemId};

  final out = <ParsedInstrument>[];
  void add(ClientEquipment equipment) {
    final empty =
        equipment.equipmentType.trim().isEmpty &&
        equipment.tag.trim().isEmpty &&
        equipment.serialNumber.trim().isEmpty &&
        equipment.model.trim().isEmpty &&
        equipment.presetTag.trim().isEmpty &&
        equipment.presetSerial.trim().isEmpty;
    if (empty) return;
    out.add(
      ParsedInstrument(
        clientName: map['name'] ?? '',
        cnpj: map['cnpj'] ?? '',
        equipment: equipment,
      ),
    );
  }

  final main = _equipmentOf(map, systemId: rowSystemId);
  final mainEmpty =
      main.tag.trim().isEmpty &&
      main.serialNumber.trim().isEmpty &&
      main.model.trim().isEmpty &&
      main.manufacturer.trim().isEmpty;
  final mainType = '${main.equipmentType} ${map['instrumentRole'] ?? ''}'
      .toLowerCase();
  final mainIsDens = mainType.contains('dens');
  final mainIsTx = mainType.contains('transmiss');
  final mainIsPt =
      mainType.contains('pt100') ||
      mainType.contains('pt 100') ||
      mainType.contains('termorresist');
  final mainIsTelemetry = mainType.contains('telemetr');
  final mainIsPressure =
      mainType.contains('manom') ||
      mainType.contains('press') ||
      mainType.contains('psv');

  if (!mainEmpty) {
    add(
      main.copyWith(
        instrumentRole: (map['instrumentRole'] ?? '').trim().isEmpty
            ? clientInstrumentRoleLabel(ClientInstrumentRole.meter)
            : map['instrumentRole'],
        assemblyKind: assemblyKind,
      ),
    );
  }

  // Colunas laterais só geram instrumento extra se o principal NÃO for
  // desse tipo (evita duplicar densímetro/PT100/TX no baixar→importar).
  if (hasTx && !mainIsTx) {
    add(
      ClientEquipment(
        id: '$rowSystemId-tx',
        systemId: rowSystemId,
        systemType: map['systemType'] ?? '',
        equipmentType: 'Transmissor',
        workingPrinciple: (map['transmitterPrinciple'] ?? '').trim().isNotEmpty
            ? map['transmitterPrinciple']!
            : 'Transmissor',
        manufacturer: map['transmitterManufacturer'] ?? '',
        model: map['transmitterModel'] ?? '',
        serialNumber: map['transmitterSerial'] ?? '',
        tag: map['transmitterTag'] ?? '',
        installLocation: map['installLocation'] ?? '',
        systemTag: map['systemTag'] ?? '',
        assemblyKind: assemblyKind.isEmpty ? 'Transmissor' : assemblyKind,
        presetTag: map['presetTag'] ?? '',
        presetManufacturer: map['presetManufacturer'] ?? '',
        presetModel: map['presetModel'] ?? '',
        presetSerial: map['presetSerial'] ?? '',
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
  }
  if (hasDens && !mainIsDens) {
    add(
      ClientEquipment(
        id: '$rowSystemId-dens',
        systemId: rowSystemId,
        systemType: map['systemType'] ?? '',
        equipmentType: 'Densímetro',
        workingPrinciple: densPrinciple.isNotEmpty
            ? densPrinciple
            : 'Tubo Vibratório',
        manufacturer: map['densimeterManufacturer'] ?? '',
        model: map['densimeterModel'] ?? '',
        serialNumber: map['densimeterSerial'] ?? '',
        tag: map['densimeterTag'] ?? '',
        installLocation: map['installLocation'] ?? '',
        systemTag: map['systemTag'] ?? '',
        assemblyKind: assemblyKind.isEmpty ? 'Densímetro' : assemblyKind,
        presetTag: map['presetTag'] ?? '',
        presetManufacturer: map['presetManufacturer'] ?? '',
        presetModel: map['presetModel'] ?? '',
        presetSerial: map['presetSerial'] ?? '',
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.densimeter,
        ),
      ),
    );
  }
  if (hasPt && !mainIsPt) {
    add(
      ClientEquipment(
        id: '$rowSystemId-pt',
        systemId: rowSystemId,
        systemType: map['systemType'] ?? '',
        equipmentType: 'PT100',
        workingPrinciple: normalizedPt.principle.trim().isNotEmpty
            ? normalizedPt.principle
            : 'Termorresistência',
        meshWorkingPrinciple:
            (map['meshWorkingPrinciple'] ?? '').trim().isNotEmpty
            ? map['meshWorkingPrinciple']!
            : 'Malha de temperatura',
        meshTag: map['meshTag'] ?? '',
        meshSerialNumber: map['meshSerialNumber'] ?? '',
        meshManufacturer: map['meshManufacturer'] ?? '',
        meshModel: map['meshModel'] ?? '',
        meshEquipmentType: map['meshEquipmentType'] ?? '',
        manufacturer: normalizedPt.manufacturer,
        model: normalizedPt.model,
        serialNumber: normalizedPt.serial,
        tag: normalizedPt.tag,
        installLocation: map['installLocation'] ?? '',
        systemTag: map['systemTag'] ?? '',
        assemblyKind: assemblyKind.isEmpty ? 'PT100' : assemblyKind,
        presetTag: map['presetTag'] ?? '',
        presetManufacturer: map['presetManufacturer'] ?? '',
        presetModel: map['presetModel'] ?? '',
        presetSerial: map['presetSerial'] ?? '',
        instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.pt100),
      ),
    );
  }
  if (hasTelemetry && !mainIsTelemetry) {
    add(
      ClientEquipment(
        id: '$rowSystemId-tel',
        systemId: rowSystemId,
        systemType: (map['systemType'] ?? '').trim().isNotEmpty
            ? map['systemType']!
            : 'Telemetria',
        equipmentType: 'Telemetria',
        workingPrinciple: (map['telemetryPrinciple'] ?? '').trim().isNotEmpty
            ? map['telemetryPrinciple']!
            : ((map['workingPrinciple'] ?? '').trim().isNotEmpty
                  ? map['workingPrinciple']!
                  : 'Servo Operado'),
        manufacturer: map['telemetryManufacturer'] ?? '',
        model: map['telemetryModel'] ?? '',
        serialNumber: map['telemetrySerial'] ?? '',
        tag: map['telemetryTag'] ?? '',
        product: map['telemetryProduct'] ?? '',
        installLocation: map['installLocation'] ?? '',
        systemTag: map['systemTag'] ?? '',
        assemblyKind: assemblyKind.isEmpty ? 'Transmissor' : assemblyKind,
        presetTag: map['presetTag'] ?? '',
        presetManufacturer: map['presetManufacturer'] ?? '',
        presetModel: map['presetModel'] ?? '',
        presetSerial: map['presetSerial'] ?? '',
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
  }
  if (hasPressure && !mainIsPressure) {
    final pType = (map['pressureType'] ?? '').trim().isNotEmpty
        ? map['pressureType']!
        : 'Manômetro';
    add(
      ClientEquipment(
        id: '$rowSystemId-press',
        systemId: rowSystemId,
        systemType: (map['systemType'] ?? '').trim().isNotEmpty
            ? map['systemType']!
            : 'Pressão',
        equipmentType: pType,
        workingPrinciple: (map['pressurePrinciple'] ?? '').trim().isNotEmpty
            ? map['pressurePrinciple']!
            : (pType.toLowerCase().contains('pressost')
                  ? 'Eletromecânico'
                  : (pType.toLowerCase().contains('psv')
                        ? 'Mola calibrada'
                        : (pType.toLowerCase().contains('transm')
                              ? 'Piezorresistivo'
                              : 'Deformação elástica (Bourdon)'))),
        manufacturer: map['pressureManufacturer'] ?? '',
        model: map['pressureModel'] ?? '',
        serialNumber: map['pressureSerial'] ?? '',
        tag: map['pressureTag'] ?? '',
        installLocation: map['installLocation'] ?? '',
        systemTag: map['systemTag'] ?? '',
        assemblyKind: assemblyKind.isEmpty ? 'Manômetro' : assemblyKind,
        presetTag: map['presetTag'] ?? '',
        presetManufacturer: map['presetManufacturer'] ?? '',
        presetModel: map['presetModel'] ?? '',
        presetSerial: map['presetSerial'] ?? '',
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
  }

  if (out.isEmpty && (hasPreset || !mainEmpty)) {
    add(main.copyWith(assemblyKind: assemblyKind));
  }
  return out;
}

List<ClientEquipment> mergeEquipment(
  List<ClientEquipment> current,
  List<ClientEquipment> incoming,
) {
  final out = [...current];
  for (final item in incoming) {
    final index = out.indexWhere((existing) {
      final serial = item.serialNumber.trim().toLowerCase();
      final existingSerial = existing.serialNumber.trim().toLowerCase();
      final tag = item.tag.trim().toLowerCase();
      final existingTag = existing.tag.trim().toLowerCase();
      final role = clientInstrumentRoleFrom(item.instrumentRole);
      final existingRole = clientInstrumentRoleFrom(existing.instrumentRole);
      // N/S igual = mesmo instrumento (mesmo papel).
      if (serial.isNotEmpty &&
          serial == existingSerial &&
          role == existingRole) {
        return true;
      }
      // Tag só une se N/S não conflita e for o mesmo conjunto (preset/system).
      if (tag.isNotEmpty && tag == existingTag && role == existingRole) {
        if (serial.isNotEmpty &&
            existingSerial.isNotEmpty &&
            serial != existingSerial) {
          return false;
        }
        final preset = item.presetTag.trim().toLowerCase();
        final existingPreset = existing.presetTag.trim().toLowerCase();
        if (preset.isNotEmpty &&
            existingPreset.isNotEmpty &&
            preset != existingPreset) {
          return false;
        }
        final sys = item.systemId.trim();
        final existingSys = existing.systemId.trim();
        if (sys.isNotEmpty && existingSys.isNotEmpty && sys != existingSys) {
          return false;
        }
        return true;
      }
      return false;
    });
    if (index < 0) {
      out.add(item);
      continue;
    }
    final previous = out[index];
    out[index] = ClientEquipment(
      id: previous.id,
      systemType: item.systemType.trim().isEmpty
          ? previous.systemType
          : item.systemType,
      equipmentType: item.equipmentType.trim().isEmpty
          ? previous.equipmentType
          : item.equipmentType,
      quantity: item.quantity,
      workingPrinciple: item.workingPrinciple.trim().isEmpty
          ? previous.workingPrinciple
          : item.workingPrinciple,
      dimensions: item.dimensions.trim().isEmpty
          ? previous.dimensions
          : item.dimensions,
      manufacturer: item.manufacturer.trim().isEmpty
          ? previous.manufacturer
          : item.manufacturer,
      model: item.model.trim().isEmpty ? previous.model : item.model,
      serialNumber: item.serialNumber.trim().isEmpty
          ? previous.serialNumber
          : item.serialNumber,
      tag: item.tag.trim().isEmpty ? previous.tag : item.tag,
      product: item.product.trim().isEmpty ? previous.product : item.product,
      installLocation: item.installLocation.trim().isEmpty
          ? previous.installLocation
          : item.installLocation,
      systemId: item.systemId.trim().isEmpty
          ? previous.systemId
          : item.systemId,
      systemTag: item.systemTag.trim().isEmpty
          ? previous.systemTag
          : item.systemTag,
      assemblyKind: item.assemblyKind.trim().isEmpty
          ? previous.assemblyKind
          : item.assemblyKind,
      presetTag: item.presetTag.trim().isEmpty
          ? previous.presetTag
          : item.presetTag,
      presetManufacturer: item.presetManufacturer.trim().isEmpty
          ? previous.presetManufacturer
          : item.presetManufacturer,
      presetModel: item.presetModel.trim().isEmpty
          ? previous.presetModel
          : item.presetModel,
      presetSerial: item.presetSerial.trim().isEmpty
          ? previous.presetSerial
          : item.presetSerial,
      presetWorkingPrinciple: item.presetWorkingPrinciple.trim().isEmpty
          ? previous.presetWorkingPrinciple
          : item.presetWorkingPrinciple,
      instrumentRole: item.instrumentRole.trim().isEmpty
          ? previous.instrumentRole
          : item.instrumentRole,
      meshTag: item.meshTag.trim().isEmpty ? previous.meshTag : item.meshTag,
      meshEquipmentType: item.meshEquipmentType.trim().isEmpty
          ? previous.meshEquipmentType
          : item.meshEquipmentType,
      meshManufacturer: item.meshManufacturer.trim().isEmpty
          ? previous.meshManufacturer
          : item.meshManufacturer,
      meshModel: item.meshModel.trim().isEmpty
          ? previous.meshModel
          : item.meshModel,
      meshSerialNumber: item.meshSerialNumber.trim().isEmpty
          ? previous.meshSerialNumber
          : item.meshSerialNumber,
      meshWorkingPrinciple: item.meshWorkingPrinciple.trim().isEmpty
          ? previous.meshWorkingPrinciple
          : item.meshWorkingPrinciple,
    );
  }
  return out;
}

List<CellValue> _clientValues(SavedClient client) => [
  TextCellValue(client.requester),
  TextCellValue(client.name),
  TextCellValue(client.cnpj),
  TextCellValue(client.cep),
  TextCellValue(client.street),
  TextCellValue(client.number),
  TextCellValue(client.complement),
  TextCellValue(client.neighborhood),
  TextCellValue(client.city),
  TextCellValue(client.state),
  TextCellValue(client.baseName),
  TextCellValue(client.baseCargo),
  TextCellValue(client.baseEmail),
  TextCellValue(client.basePhone),
];

List<List<CellValue>> _systemRowValues(
  SavedClient client,
  ClientSystem system,
) {
  final meters = system.meters;
  final densimeters = system.densimeters;
  final pt100s = system.pt100s;
  final transmitters = system.transmitters;

  final rowCount = math.max(
    1,
    math.max(
      meters.length,
      math.max(
        densimeters.length,
        math.max(pt100s.length, transmitters.length),
      ),
    ),
  );

  final isPreset = system.isPreset;
  final presetTag = system.assemblyTag.isNotEmpty ? system.assemblyTag : '';
  final presetMfg = isPreset ? system.manufacturer : '';
  final presetModel = isPreset ? system.model : '';
  final presetSerial = isPreset ? system.serialNumber : '';

  final isTxSystem = system.kind == ClientAssemblyKind.transmitter;

  T? companionAt<T>(List<T> list, int i) {
    if (list.isEmpty) return null;
    if (i < list.length) return list[i];
    // Um densímetro/PT100 compartilhado: repete em todas as linhas do medidor
    // (padrão Cleber / Phoenix).
    if (list.length == 1) return list.first;
    return null;
  }

  final rows = <List<CellValue>>[];

  for (var i = 0; i < rowCount; i++) {
    final meter = i < meters.length ? meters[i] : null;
    final dens = companionAt(densimeters, i);
    final pt = companionAt(pt100s, i);
    final tx = companionAt(transmitters, i);

    final telemetries = system.instruments
        .where(
          (inst) =>
              inst.equipmentType.toLowerCase().contains('telemetr') ||
              inst.typeLabel.toLowerCase().contains('telemetr'),
        )
        .toList();
    final telemetry = companionAt(telemetries, i);
    final isTelemetrySys = system.systemType.toLowerCase().contains('telemetr');

    final pressures = system.instruments
        .where(
          (inst) =>
              inst.equipmentType.toLowerCase().contains('manom') ||
              inst.equipmentType.toLowerCase().contains('press') ||
              inst.equipmentType.toLowerCase().contains('psv') ||
              inst.typeLabel.toLowerCase().contains('press'),
        )
        .toList();
    final pressure = companionAt(pressures, i);
    final isPressureSys = system.systemType.toLowerCase().contains('press');

    // Transmissor (complemento do medidor / sistema TX)
    String txMfg = '';
    String txModel = '';
    String txSerial = '';
    String txTag = '';
    if (tx != null) {
      txMfg = tx.manufacturer;
      txModel = tx.model;
      txSerial = tx.serialNumber;
      txTag = tx.tag;
    } else if (isTxSystem && i == 0) {
      txMfg = system.manufacturer;
      txModel = system.model;
      txSerial = system.serialNumber;
      txTag = system.assemblyTag.isNotEmpty ? system.assemblyTag : system.tag;
    }

    // Colunas do medidor (padrão Cleber v2 — sem tipo/quantidade)
    String principle = '';
    String dims = '';
    String mfg = '';
    String model = '';
    String serial = '';
    String tag = '';
    String product = '';

    if (meter != null) {
      principle = meter.workingPrinciple;
      dims = meter.dimensions;
      mfg = meter.manufacturer;
      model = meter.model;
      serial = meter.serialNumber;
      tag = meter.tag;
      product = meter.product;
    } else if (dens != null && !isTxSystem) {
      // Densímetro avulso: preenche bloco do densímetro, não o medidor.
    } else if (pt != null && !isTxSystem) {
      // PT100 avulso: bloco de temperatura.
    } else if (tx != null && meter == null) {
      // TX sem medidor: dados ficam só nas colunas de transmissor.
    }

    final fillMeterCompanions = meter != null;
    final densOnRow = fillMeterCompanions
        ? dens
        : (meter == null ? dens : null);
    final ptOnRow = fillMeterCompanions ? pt : (meter == null ? pt : null);

    // Padrão Cleber v2 (46 cols): preset → TX → medidor → temp → dens → …
    rows.add([
      TextCellValue(client.name),
      TextCellValue(client.cnpj),
      TextCellValue(system.systemType),
      TextCellValue(system.installLocation),
      TextCellValue(clientAssemblyKindLabel(system.kind)),
      TextCellValue(presetMfg),
      TextCellValue(presetModel),
      TextCellValue(presetSerial),
      TextCellValue(presetTag),
      // Transmissor
      TextCellValue(txMfg),
      TextCellValue(txModel),
      TextCellValue(txSerial),
      TextCellValue(txTag),
      // Medidor
      TextCellValue(principle),
      TextCellValue(dims),
      TextCellValue(mfg),
      TextCellValue(model),
      TextCellValue(serial),
      TextCellValue(tag),
      TextCellValue(product),
      // Sensor de temperatura (PT100)
      TextCellValue(ptOnRow?.workingPrinciple ?? ''),
      TextCellValue(ptOnRow?.manufacturer ?? ''),
      TextCellValue(ptOnRow?.model ?? ''),
      TextCellValue(ptOnRow?.serialNumber ?? ''),
      TextCellValue(ptOnRow?.tag ?? ''),
      // Densímetro
      TextCellValue(densOnRow?.workingPrinciple ?? ''),
      TextCellValue(densOnRow?.manufacturer ?? ''),
      TextCellValue(densOnRow?.model ?? ''),
      TextCellValue(densOnRow?.serialNumber ?? ''),
      TextCellValue(densOnRow?.tag ?? ''),
      // Malha
      TextCellValue(ptOnRow?.meshWorkingPrinciple ?? ''),
      TextCellValue(ptOnRow?.meshManufacturer ?? ''),
      TextCellValue(ptOnRow?.meshModel ?? ''),
      TextCellValue(ptOnRow?.meshSerialNumber ?? ''),
      TextCellValue(ptOnRow?.meshTag ?? ''),
      // Telemetria
      TextCellValue(
        telemetry?.workingPrinciple ??
            (isTelemetrySys && i == 0 ? 'Servo Operado' : ''),
      ),
      TextCellValue(
        telemetry?.manufacturer ??
            (isTelemetrySys && i == 0 ? system.manufacturer : ''),
      ),
      TextCellValue(
        telemetry?.model ?? (isTelemetrySys && i == 0 ? system.model : ''),
      ),
      TextCellValue(
        telemetry?.serialNumber ??
            (isTelemetrySys && i == 0 ? system.serialNumber : ''),
      ),
      TextCellValue(
        telemetry?.tag ??
            (isTelemetrySys && i == 0
                ? (system.assemblyTag.isNotEmpty
                      ? system.assemblyTag
                      : system.tag)
                : ''),
      ),
      TextCellValue(telemetry?.product ?? ''),
      // Pressão
      TextCellValue(
        pressure?.equipmentType ?? (isPressureSys && i == 0 ? 'Manômetro' : ''),
      ),
      TextCellValue(
        pressure?.manufacturer ??
            (isPressureSys && i == 0 ? system.manufacturer : ''),
      ),
      TextCellValue(
        pressure?.model ?? (isPressureSys && i == 0 ? system.model : ''),
      ),
      TextCellValue(
        pressure?.serialNumber ??
            (isPressureSys && i == 0 ? system.serialNumber : ''),
      ),
      TextCellValue(
        pressure?.tag ??
            (isPressureSys && i == 0
                ? (system.assemblyTag.isNotEmpty
                      ? system.assemblyTag
                      : system.tag)
                : ''),
      ),
    ]);
  }

  return rows;
}

List<CellValue> _instrumentValues(SavedClient client, ClientEquipment item) {
  final role = clientInstrumentRoleFrom(item.instrumentRole);
  final isTx = role == ClientInstrumentRole.transmitter;
  final isDens = role == ClientInstrumentRole.densimeter;
  final isPt = role == ClientInstrumentRole.pt100;
  final isMeter =
      role == ClientInstrumentRole.meter || (!isTx && !isDens && !isPt);
  final isTelemetry =
      item.equipmentType.toLowerCase().contains('telemetr') ||
      item.systemType.toLowerCase().contains('telemetr');
  final isPressure =
      item.equipmentType.toLowerCase().contains('manom') ||
      item.equipmentType.toLowerCase().contains('press') ||
      item.equipmentType.toLowerCase().contains('psv') ||
      item.systemType.toLowerCase().contains('press');

  final mainInMeterCols = isMeter && !isTelemetry && !isPressure;

  return [
    TextCellValue(client.name),
    TextCellValue(client.cnpj),
    TextCellValue(item.systemType),
    TextCellValue(item.installLocation),
    TextCellValue(
      item.assemblyKind.trim().isEmpty
          ? ''
          : clientAssemblyKindLabel(clientAssemblyKindFrom(item.assemblyKind)),
    ),
    TextCellValue(item.presetManufacturer),
    TextCellValue(item.presetModel),
    TextCellValue(item.presetSerial),
    TextCellValue(item.presetTag),
    // Transmissor
    TextCellValue(isTx ? item.manufacturer : ''),
    TextCellValue(isTx ? item.model : ''),
    TextCellValue(isTx ? item.serialNumber : ''),
    TextCellValue(isTx ? item.tag : ''),
    // Medidor
    TextCellValue(mainInMeterCols ? item.workingPrinciple : ''),
    TextCellValue(mainInMeterCols ? item.dimensions : ''),
    TextCellValue(mainInMeterCols ? item.manufacturer : ''),
    TextCellValue(mainInMeterCols ? item.model : ''),
    TextCellValue(mainInMeterCols ? item.serialNumber : ''),
    TextCellValue(mainInMeterCols ? item.tag : ''),
    TextCellValue(mainInMeterCols ? item.product : ''),
    // Sensor de temperatura
    TextCellValue(isPt ? item.workingPrinciple : ''),
    TextCellValue(isPt ? item.manufacturer : ''),
    TextCellValue(isPt ? item.model : ''),
    TextCellValue(isPt ? item.serialNumber : ''),
    TextCellValue(isPt ? item.tag : ''),
    // Densímetro
    TextCellValue(isDens ? item.workingPrinciple : ''),
    TextCellValue(isDens ? item.manufacturer : ''),
    TextCellValue(isDens ? item.model : ''),
    TextCellValue(isDens ? item.serialNumber : ''),
    TextCellValue(isDens ? item.tag : ''),
    // Malha
    TextCellValue(item.meshWorkingPrinciple),
    TextCellValue(item.meshManufacturer),
    TextCellValue(item.meshModel),
    TextCellValue(item.meshSerialNumber),
    TextCellValue(item.meshTag),
    // Telemetria
    TextCellValue(isTelemetry ? item.workingPrinciple : ''),
    TextCellValue(isTelemetry ? item.manufacturer : ''),
    TextCellValue(isTelemetry ? item.model : ''),
    TextCellValue(isTelemetry ? item.serialNumber : ''),
    TextCellValue(isTelemetry ? item.tag : ''),
    TextCellValue(isTelemetry ? item.product : ''),
    // Pressão
    TextCellValue(isPressure ? item.equipmentType : ''),
    TextCellValue(isPressure ? item.manufacturer : ''),
    TextCellValue(isPressure ? item.model : ''),
    TextCellValue(isPressure ? item.serialNumber : ''),
    TextCellValue(isPressure ? item.tag : ''),
  ];
}

SavedClient _clientOf(Map<String, String> map) {
  return SavedClient(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: map['name'] ?? '',
    requester: map['requester'] ?? '',
    cnpj: map['cnpj'] ?? '',
    cep: map['cep'] ?? '',
    street: map['street'] ?? '',
    number: map['number'] ?? '',
    complement: map['complement'] ?? '',
    neighborhood: map['neighborhood'] ?? '',
    city: map['city'] ?? '',
    state: (map['state'] ?? '').toUpperCase(),
    service: map['service'] ?? '',
    systemType: map['systemType'] ?? '',
    baseName: map['baseName'] ?? '',
    baseCargo: map['baseCargo'] ?? '',
    baseEmail: map['baseEmail'] ?? '',
    basePhone: map['basePhone'] ?? '',
    sites: [
      for (final part in (map['sites'] ?? '').split(RegExp(r'[|/;]')))
        if (part.trim().isNotEmpty) part.trim(),
    ],
    updatedAt: DateTime.now(),
  );
}

ClientEquipment _equipmentOf(Map<String, String> map, {String? systemId}) {
  final sid = systemId ?? map['systemId'] ?? '';
  return ClientEquipment(
    id: sid.isNotEmpty
        ? '$sid-main'
        : DateTime.now().microsecondsSinceEpoch.toString(),
    systemType: map['systemType'] ?? '',
    equipmentType: map['equipmentType'] ?? '',
    quantity: int.tryParse(map['quantity'] ?? '') ?? 1,
    workingPrinciple: map['workingPrinciple'] ?? '',
    dimensions: map['dimensions'] ?? '',
    manufacturer: map['manufacturer'] ?? '',
    model: map['model'] ?? '',
    serialNumber: map['serialNumber'] ?? '',
    tag: map['tag'] ?? '',
    product: map['product'] ?? '',
    installLocation: map['installLocation'] ?? '',
    systemId: sid,
    systemTag: map['systemTag'] ?? '',
    assemblyKind: map['assemblyKind'] ?? '',
    presetTag: map['presetTag'] ?? '',
    presetManufacturer: map['presetManufacturer'] ?? '',
    presetModel: map['presetModel'] ?? '',
    presetSerial: map['presetSerial'] ?? '',
    presetWorkingPrinciple: map['presetPrinciple'] ?? '',
    instrumentRole: map['instrumentRole'] ?? '',
    meshTag: map['meshTag'] ?? '',
    meshEquipmentType: map['meshEquipmentType'] ?? '',
    meshManufacturer: map['meshManufacturer'] ?? '',
    meshModel: map['meshModel'] ?? '',
    meshSerialNumber: map['meshSerialNumber'] ?? '',
    meshWorkingPrinciple: map['meshWorkingPrinciple'] ?? '',
  );
}

SavedClient _sampleClient() {
  return SavedClient(
    id: 'exemplo',
    name: 'CLIENTE EXEMPLO LTDA',
    requester: 'TESCAN',
    cnpj: '00.000.000/0001-00',
    cep: '01001-000',
    street: 'Rua da Calibração',
    number: '100',
    complement: 'Galpão 2',
    neighborhood: 'Centro',
    city: 'São Paulo',
    state: 'SP',
    baseName: 'Maria Silva',
    baseCargo: 'Supervisora',
    baseEmail: 'maria@cliente.com',
    basePhone: '11999999999',
    systems: [
      ClientSystem(
        id: 'sys-ex',
        systemType: 'Sistema de Carregamento',
        installLocation: 'Plataforma 1',
        kind: ClientAssemblyKind.preset,
        manufacturer: 'ZYLIX',
        model: 'ZLX-9000',
        serialNumber: '001-01-445',
        assemblyTag: 'FIQ 1',
        meterCount: 1,
        densimeterCount: 1,
        pt100Count: 1,
        instruments: const [
          ClientInstrument(
            id: 'ex1',
            role: ClientInstrumentRole.meter,
            equipmentType: 'Medidor Tipo Turbina',
            workingPrinciple: 'Medição de Vazão',
            dimensions: '3"',
            manufacturer: 'ZYLIX',
            model: 'TRB-9000',
            serialNumber: '002-01-604',
            tag: 'FT 1',
            product: 'Hidratado',
          ),
          ClientInstrument(
            id: 'ex-dens',
            role: ClientInstrumentRole.densimeter,
            equipmentType: 'Densímetro',
            workingPrinciple: 'ALUTAL',
          ),
          ClientInstrument(
            id: 'ex3',
            role: ClientInstrumentRole.pt100,
            equipmentType: 'PT100',
            workingPrinciple: 'Termorresistência',
            manufacturer: 'CEX-A-00002',
            model: '',
            serialNumber: '43134/1',
            tag: 'TE1',
          ),
        ],
      ),
    ],
    updatedAt: DateTime.now(),
  );
}

bool _isSameClient(SavedClient client, String name, String cnpj) {
  final d1 = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
  final d2 = client.cnpjDigits;
  if (d1.isNotEmpty && d2.isNotEmpty) {
    if (d1 == d2 || d1.padLeft(14, '0') == d2.padLeft(14, '0')) return true;
  }
  final n1 = _fold(name);
  final n2 = _fold(client.name);
  if (n1.isNotEmpty && n2.isNotEmpty) {
    if (n1 == n2) return true;
    if (n1.contains(n2) || n2.contains(n1)) return true;
  }
  return false;
}

String _cell(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is TextCellValue) return (value.value.text ?? '').trim();
  if (value is IntCellValue) return '${value.value}';
  if (value is DoubleCellValue) {
    final number = value.value;
    if (number == number.roundToDouble()) return '${number.toInt()}';
    return '$number';
  }
  return '$value'.trim();
}

String _fold(String raw) {
  var value = raw.trim().toLowerCase();
  const from = 'áàãâäéèêëíìîïóòõôöúùûüçñº°';
  const to = 'aaaaaeeeeiiiiooooouuuucn  ';
  for (var i = 0; i < from.length; i++) {
    value = value.replaceAll(from[i], to[i]);
  }
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _key(String raw) {
  final folded = _fold(raw);
  if (folded.isEmpty) return '';
  if (folded == 'cliente' ||
      folded == 'contratante' ||
      folded == 'razao social' ||
      folded == 'nome') {
    return 'name';
  }
  if (folded == 'cnpj') return 'cnpj';
  if (folded == 'cep') return 'cep';
  if (folded == 'endereco' || folded == 'logradouro' || folded == 'rua') {
    return 'street';
  }
  if (folded == 'numero' || folded == 'n' || folded == 'num') return 'number';
  if (folded == 'complemento') return 'complement';
  if (folded == 'bairro') return 'neighborhood';
  if (folded == 'cidade' || folded == 'municipio') return 'city';
  if (folded == 'estado' || folded == 'uf') return 'state';
  if (folded == 'servico' || folded == 'servico contratado') return 'service';
  if (folded.contains('tipo de sistema') ||
      folded == 'tipo sistema' ||
      folded == 'tipo de servico' ||
      folded == 'tipo servico') {
    return 'systemType';
  }
  // Padrão Cleber (Phoenix): colunas “do medidor” e local do sistema.
  if (folded.contains('local de instalacao do sistema') ||
      folded.contains('local instalacao do sistema') ||
      folded == 'local de instalacao' ||
      folded.contains('local instalado')) {
    return 'installLocation';
  }
  if (folded.contains('principio de funcionamento do medidor') ||
      folded.contains('principio do medidor') ||
      folded.contains('principio funcionamento do medidor')) {
    return 'workingPrinciple';
  }
  if (folded.contains('dimensoes do medidor') ||
      folded.contains('dimensao do medidor')) {
    return 'dimensions';
  }
  if (folded.contains('fabricante do medidor')) return 'manufacturer';
  if (folded.contains('modelo do medidor')) return 'model';
  if (folded.contains('numero de serie do medidor') ||
      folded.contains('n s do medidor') ||
      folded.contains('serie do medidor') ||
      folded == 'ns do medidor') {
    return 'serialNumber';
  }
  if (folded.contains('tag do medidor') || folded == 'tag medidor') {
    return 'tag';
  }
  if (folded.contains('produto utilizado no medidor') ||
      folded.contains('produto do medidor')) {
    return 'product';
  }
  if (folded.contains('produto do tanque') ||
      folded.contains('produto tanque') ||
      (folded.contains('produto') && folded.contains('telemetr'))) {
    return 'telemetryProduct';
  }
  if (folded.contains('fabricante do transmissor')) {
    return 'transmitterManufacturer';
  }
  if (folded.contains('modelo do transmissor')) return 'transmitterModel';
  if (folded.contains('serie do transmissor') ||
      folded.contains('n s do transmissor') ||
      folded == 'ns do transmissor') {
    return 'transmitterSerial';
  }
  if (folded.contains('tag do transmissor') || folded == 'tag transmissor') {
    return 'transmitterTag';
  }
  if (folded.contains('principio do transmissor') ||
      folded.contains('principio transmissor')) {
    return 'transmitterPrinciple';
  }
  if (folded.contains('fabricante da telemetria') ||
      folded.contains('fabricante telemetria')) {
    return 'telemetryManufacturer';
  }
  if (folded.contains('modelo da telemetria') ||
      folded.contains('modelo telemetria')) {
    return 'telemetryModel';
  }
  if (folded.contains('serie da telemetria') ||
      folded.contains('n s da telemetria') ||
      folded.contains('ns da telemetria') ||
      folded.contains('serial telemetria')) {
    return 'telemetrySerial';
  }
  if (folded.contains('tag da telemetria') ||
      folded.contains('tag telemetria')) {
    return 'telemetryTag';
  }
  if (folded.contains('principio da telemetria') ||
      folded.contains('principio telemetria')) {
    return 'telemetryPrinciple';
  }
  if (folded.contains('fabricante') && folded.contains('densimetro')) {
    return 'densimeterManufacturer';
  }
  if (folded.contains('modelo') && folded.contains('densimetro')) {
    return 'densimeterModel';
  }
  if ((folded.contains('serie') ||
          folded.contains('n s') ||
          folded.contains('ns ')) &&
      folded.contains('densimetro')) {
    return 'densimeterSerial';
  }
  if (folded.contains('tag') && folded.contains('densimetro')) {
    return 'densimeterTag';
  }
  if (folded.contains('principio') &&
      (folded.contains('densimetro') ||
          folded.contains('densidade') ||
          folded.contains('sensor do densimetro'))) {
    return 'densimeterPrinciple';
  }
  if (folded.contains('fabricante do sensor de temperatura') ||
      folded.contains('fabricante do pt100') ||
      folded.contains('fabricante do pt 100')) {
    return 'pt100Manufacturer';
  }
  if (folded.contains('modelo do sensor de temperatura') ||
      folded.contains('modelo do pt100') ||
      folded.contains('modelo do pt 100')) {
    return 'pt100Model';
  }
  if (folded.contains('serie do sensor de temperatura') ||
      folded.contains('n s do sensor de temperatura') ||
      folded.contains('ns do sensor de temperatura') ||
      folded.contains('serie do pt100') ||
      folded.contains('serie do pt 100') ||
      folded.contains('n s do pt100') ||
      folded == 'ns do pt100') {
    return 'pt100Serial';
  }
  if (folded.contains('tag do sensor de temperatura') ||
      folded.contains('tag do pt100') ||
      folded.contains('tag do pt 100') ||
      folded == 'tag pt100') {
    return 'pt100Tag';
  }
  if (folded.contains('principio do sensor de temperatura') ||
      folded.contains('principio sensor de temperatura') ||
      folded.contains('principio do pt100') ||
      folded.contains('principio do pt 100') ||
      folded.contains('principio pt100') ||
      folded.contains('principio pt 100') ||
      folded.contains('principio da temperatura') ||
      folded.contains('principio temperatura')) {
    return 'pt100Principle';
  }
  if (folded.contains('tipo do instrumento de pressao') ||
      folded.contains('tipo do instruemnto de pressao') ||
      folded.contains('tipo instrumento pressao') ||
      folded.contains('instrumento de pressao') ||
      folded.contains('instruemnto de pressao') ||
      folded.contains('instrumento pressao')) {
    return 'pressureType';
  }
  if (folded.contains('fabricante da pressao') ||
      folded.contains('fabricante do manometro') ||
      folded.contains('fabricante manometro') ||
      folded.contains('fabricante pressao')) {
    return 'pressureManufacturer';
  }
  if (folded.contains('modelo da pressao') ||
      folded.contains('modelo do manometro') ||
      folded.contains('modelo manometro') ||
      folded.contains('modelo pressao')) {
    return 'pressureModel';
  }
  if (folded.contains('serie da pressao') ||
      folded.contains('n s da pressao') ||
      folded.contains('ns da pressao') ||
      folded.contains('serie do manometro') ||
      folded.contains('n s do manometro') ||
      folded.contains('ns do manometro') ||
      folded.contains('serial pressao')) {
    return 'pressureSerial';
  }
  if (folded.contains('tag da pressao') ||
      folded.contains('tag do manometro') ||
      folded.contains('tag manometro') ||
      folded.contains('tag pressao')) {
    return 'pressureTag';
  }
  if (folded.contains('principio da pressao') ||
      folded.contains('principio do manometro') ||
      folded.contains('principio manometro') ||
      folded.contains('principio pressao')) {
    return 'pressurePrinciple';
  }
  if (folded.contains('preset ou transmissor') ||
      folded == 'preset transmissor' ||
      folded == 'tipo de conjunto' ||
      folded == 'conjunto') {
    return 'assemblyKind';
  }
  if (folded.contains('tag do sistema') || folded == 'tag sistema') {
    return 'systemTag';
  }
  if (folded.contains('tag do preset') ||
      folded == 'tag preset' ||
      folded == 'preset tag') {
    return 'presetTag';
  }
  if (folded.contains('fabricante do preset')) return 'presetManufacturer';
  if (folded.contains('modelo do preset')) return 'presetModel';
  if (folded.contains('serie do preset') ||
      folded.contains('n s do preset') ||
      folded == 'ns do preset' ||
      folded.contains('numero de serie do preset')) {
    return 'presetSerial';
  }
  if (folded.contains('principio do preset') ||
      folded.contains('principio preset')) {
    return 'presetPrinciple';
  }
  if (folded.contains('tag da malha') || folded == 'tag malha') {
    return 'meshTag';
  }
  if (folded.contains('tipo da malha') || folded == 'tipo malha') {
    return 'meshEquipmentType';
  }
  if (folded.contains('fabricante da malha')) return 'meshManufacturer';
  if (folded.contains('modelo da malha')) return 'meshModel';
  if (folded.contains('serie da malha') ||
      folded.contains('n s da malha') ||
      folded == 'ns da malha') {
    return 'meshSerialNumber';
  }
  if (folded.contains('principio da malha') ||
      folded.contains('principio malha')) {
    return 'meshWorkingPrinciple';
  }
  if (folded == 'funcao' ||
      folded.contains('papel no preset') ||
      folded == 'tipo no preset') {
    return 'instrumentRole';
  }
  if (folded == 'quantidade' || folded == 'qtd' || folded == 'qtde') {
    return 'quantity';
  }
  if (folded.contains('tipo de equipamento') ||
      folded == 'tipo equipamento' ||
      folded == 'equipamento') {
    return 'equipmentType';
  }
  if (folded.contains('principio')) return 'workingPrinciple';
  if (folded.contains('dimens')) return 'dimensions';
  if (folded == 'fabricante') return 'manufacturer';
  if (folded == 'modelo') return 'model';
  if (folded.contains('serie') || folded == 'serial' || folded == 'ns') {
    return 'serialNumber';
  }
  if (folded == 'tag') return 'tag';
  if (folded == 'produto' || folded.startsWith('produto ')) return 'product';
  if (folded.contains('local instalado') || folded == 'local instalado') {
    return 'installLocation';
  }
  if (folded.contains('local')) return 'installLocation';
  if (folded.contains('solicitante') || folded.contains('fantasia')) {
    return 'requester';
  }
  if (folded.contains('responsavel')) return 'baseName';
  if (folded == 'cargo') return 'baseCargo';
  if (folded.contains('email')) return 'baseEmail';
  if (folded.contains('telefone') || folded == 'fone') return 'basePhone';
  if (folded.contains('locais')) return 'sites';
  return '';
}

bool _slotFieldFilled(String a, [String b = '', String c = '', String d = '']) {
  return a.trim().isNotEmpty ||
      b.trim().isNotEmpty ||
      c.trim().isNotEmpty ||
      d.trim().isNotEmpty;
}

/// Instrumentos derivados do formulário da OS (mesmo formato da planilha).
List<ClientEquipment> equipmentFromOsSlot(OsCalibrationSlot slot) {
  final kind = calibrationKindFrom(slot.kind);
  final sysId = slot.systemId.trim().isNotEmpty
      ? slot.systemId.trim()
      : 'sys-os-${slot.id}';
  final qty =
      int.tryParse(slot.quantity.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final out = <ClientEquipment>[];
  final loc = slot.installLocation;
  final sysType = slot.systemType;
  final sysTag = slot.systemTag;
  final assembly = slot.assemblyKind.trim().isNotEmpty
      ? slot.assemblyKind
      : (_slotFieldFilled(
              slot.presetTag,
              slot.presetManufacturer,
              slot.presetModel,
              slot.presetSerial,
            )
            ? 'Preset'
            : '');

  void add(ClientEquipment item) {
    final empty =
        item.equipmentType.trim().isEmpty &&
        item.tag.trim().isEmpty &&
        item.serialNumber.trim().isEmpty &&
        item.model.trim().isEmpty &&
        item.manufacturer.trim().isEmpty &&
        item.presetTag.trim().isEmpty &&
        item.presetSerial.trim().isEmpty;
    if (!empty) out.add(item);
  }

  if (kind == CalibrationKind.telemetry) {
    add(
      ClientEquipment(
        id: slot.equipmentId.isNotEmpty ? slot.equipmentId : '$stamp-tel',
        systemId: sysId,
        systemType: sysType.isNotEmpty ? sysType : 'Telemetria',
        equipmentType: slot.equipmentType.isNotEmpty
            ? slot.equipmentType
            : 'Telemetria',
        quantity: qty,
        workingPrinciple: slot.workingPrinciple,
        manufacturer: slot.manufacturer,
        model: slot.model,
        serialNumber: slot.serialNumber,
        tag: slot.equipmentTag,
        product: slot.product,
        installLocation: loc,
        systemTag: sysTag,
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
    return out;
  }

  if (kind == CalibrationKind.temperatureMesh) {
    if (_slotFieldFilled(
      slot.presetTag,
      slot.presetManufacturer,
      slot.presetModel,
      slot.presetSerial,
    )) {
      add(
        ClientEquipment(
          id: '$stamp-preset',
          systemId: sysId,
          systemType: sysType,
          equipmentType: 'Preset',
          quantity: qty,
          workingPrinciple: slot.presetWorkingPrinciple,
          manufacturer: slot.presetManufacturer,
          model: slot.presetModel,
          serialNumber: slot.presetSerial,
          tag: slot.presetTag,
          installLocation: loc,
          systemTag: sysTag,
          assemblyKind: assembly.isEmpty ? 'Preset' : assembly,
          presetTag: slot.presetTag,
          presetManufacturer: slot.presetManufacturer,
          presetModel: slot.presetModel,
          presetSerial: slot.presetSerial,
          presetWorkingPrinciple: slot.presetWorkingPrinciple,
          instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.meter),
        ),
      );
    }
    if (_slotFieldFilled(
      slot.serialNumber,
      slot.equipmentTag,
      slot.manufacturer,
      slot.model,
    )) {
      add(
        ClientEquipment(
          id: slot.equipmentId.isNotEmpty ? slot.equipmentId : '$stamp-mesh',
          systemId: sysId,
          systemType: sysType,
          equipmentType: slot.equipmentType.isNotEmpty
              ? slot.equipmentType
              : 'Malha de temperatura',
          quantity: qty,
          workingPrinciple: slot.workingPrinciple,
          manufacturer: slot.manufacturer,
          model: slot.model,
          serialNumber: slot.serialNumber,
          tag: slot.equipmentTag,
          installLocation: loc,
          systemTag: sysTag,
          assemblyKind: assembly,
          presetTag: slot.presetTag,
          presetManufacturer: slot.presetManufacturer,
          presetModel: slot.presetModel,
          presetSerial: slot.presetSerial,
          presetWorkingPrinciple: slot.presetWorkingPrinciple,
          instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.mesh),
        ),
      );
    }
    if (_slotFieldFilled(
      slot.pt100Tag,
      slot.pt100Manufacturer,
      slot.pt100Model,
      slot.pt100Serial,
    )) {
      add(
        ClientEquipment(
          id: '$stamp-pt',
          systemId: sysId,
          systemType: sysType,
          equipmentType: 'PT100',
          quantity: qty,
          workingPrinciple: slot.pt100WorkingPrinciple,
          manufacturer: slot.pt100Manufacturer,
          model: slot.pt100Model,
          serialNumber: slot.pt100Serial,
          tag: slot.pt100Tag,
          installLocation: loc,
          systemTag: sysTag,
          assemblyKind: assembly,
          presetTag: slot.presetTag,
          presetManufacturer: slot.presetManufacturer,
          presetModel: slot.presetModel,
          presetSerial: slot.presetSerial,
          presetWorkingPrinciple: slot.presetWorkingPrinciple,
          instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.pt100),
        ),
      );
    }
    return out;
  }

  final hasMeter = _slotFieldFilled(
    slot.serialNumber,
    slot.equipmentTag,
    slot.manufacturer,
    slot.model,
  );
  final hasPreset = _slotFieldFilled(
    slot.presetTag,
    slot.presetManufacturer,
    slot.presetModel,
    slot.presetSerial,
  );

  if (hasMeter || hasPreset) {
    add(
      ClientEquipment(
        id: slot.equipmentId.isNotEmpty ? slot.equipmentId : '$stamp-meter',
        systemId: sysId,
        systemType: sysType,
        equipmentType: slot.equipmentType.isNotEmpty
            ? slot.equipmentType
            : (hasMeter ? 'Medidor de Vazão' : 'Preset'),
        quantity: qty,
        workingPrinciple: slot.workingPrinciple,
        dimensions: slot.dimensions,
        manufacturer: slot.manufacturer,
        model: slot.model,
        serialNumber: slot.serialNumber,
        tag: slot.equipmentTag,
        product: slot.product,
        installLocation: loc,
        systemTag: sysTag,
        assemblyKind: assembly,
        presetTag: slot.presetTag,
        presetManufacturer: slot.presetManufacturer,
        presetModel: slot.presetModel,
        presetSerial: slot.presetSerial,
        presetWorkingPrinciple: slot.presetWorkingPrinciple,
        instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.meter),
      ),
    );
  }

  if (_slotFieldFilled(
    slot.densimeterTag,
    slot.densimeterManufacturer,
    slot.densimeterModel,
    slot.densimeterSerial,
  )) {
    add(
      ClientEquipment(
        id: '$stamp-dens',
        systemId: sysId,
        systemType: sysType,
        equipmentType: 'Densímetro',
        quantity: qty,
        workingPrinciple: slot.densimeterWorkingPrinciple,
        manufacturer: slot.densimeterManufacturer,
        model: slot.densimeterModel,
        serialNumber: slot.densimeterSerial,
        tag: slot.densimeterTag,
        installLocation: loc,
        systemTag: sysTag,
        assemblyKind: assembly.isEmpty ? 'Densímetro' : assembly,
        presetTag: slot.presetTag,
        presetManufacturer: slot.presetManufacturer,
        presetModel: slot.presetModel,
        presetSerial: slot.presetSerial,
        presetWorkingPrinciple: slot.presetWorkingPrinciple,
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.densimeter,
        ),
      ),
    );
  }

  if (_slotFieldFilled(
    slot.pt100Tag,
    slot.pt100Manufacturer,
    slot.pt100Model,
    slot.pt100Serial,
  )) {
    add(
      ClientEquipment(
        id: '$stamp-pt',
        systemId: sysId,
        systemType: sysType,
        equipmentType: 'PT100',
        quantity: qty,
        workingPrinciple: slot.pt100WorkingPrinciple,
        manufacturer: slot.pt100Manufacturer,
        model: slot.pt100Model,
        serialNumber: slot.pt100Serial,
        tag: slot.pt100Tag,
        installLocation: loc,
        systemTag: sysTag,
        assemblyKind: assembly.isEmpty ? 'PT100' : assembly,
        presetTag: slot.presetTag,
        presetManufacturer: slot.presetManufacturer,
        presetModel: slot.presetModel,
        presetSerial: slot.presetSerial,
        presetWorkingPrinciple: slot.presetWorkingPrinciple,
        meshTag: slot.meshTag,
        meshEquipmentType: slot.meshEquipmentType,
        meshManufacturer: slot.meshManufacturer,
        meshModel: slot.meshModel,
        meshSerialNumber: slot.meshSerialNumber,
        meshWorkingPrinciple: slot.meshWorkingPrinciple,
        instrumentRole: clientInstrumentRoleLabel(ClientInstrumentRole.pt100),
      ),
    );
  }

  if (_slotFieldFilled(
    slot.pressureTag,
    slot.pressureManufacturer,
    slot.pressureModel,
    slot.pressureSerial,
  )) {
    final pType = slot.pressureType.trim().isNotEmpty
        ? slot.pressureType.trim()
        : 'Transmissor de pressão';
    add(
      ClientEquipment(
        id: '$stamp-press',
        systemId: sysId,
        systemType: sysType.isNotEmpty ? sysType : 'Pressão',
        equipmentType: pType,
        quantity: qty,
        workingPrinciple: slot.pressureWorkingPrinciple,
        manufacturer: slot.pressureManufacturer,
        model: slot.pressureModel,
        serialNumber: slot.pressureSerial,
        tag: slot.pressureTag,
        installLocation: loc,
        systemTag: sysTag,
        assemblyKind: assembly.isEmpty ? 'Manômetro' : assembly,
        presetTag: slot.presetTag,
        presetManufacturer: slot.presetManufacturer,
        presetModel: slot.presetModel,
        presetSerial: slot.presetSerial,
        presetWorkingPrinciple: slot.presetWorkingPrinciple,
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
  }

  if (_slotFieldFilled(
    slot.telemetryTag,
    slot.telemetryManufacturer,
    slot.telemetryModel,
    slot.telemetrySerial,
  )) {
    add(
      ClientEquipment(
        id: '$stamp-tel',
        systemId: sysId,
        systemType: sysType.isNotEmpty ? sysType : 'Telemetria',
        equipmentType: 'Telemetria',
        quantity: qty,
        workingPrinciple: slot.telemetryWorkingPrinciple,
        manufacturer: slot.telemetryManufacturer,
        model: slot.telemetryModel,
        serialNumber: slot.telemetrySerial,
        tag: slot.telemetryTag,
        installLocation: loc,
        systemTag: sysTag,
        assemblyKind: assembly.isEmpty ? 'Transmissor' : assembly,
        presetTag: slot.presetTag,
        presetManufacturer: slot.presetManufacturer,
        presetModel: slot.presetModel,
        presetSerial: slot.presetSerial,
        presetWorkingPrinciple: slot.presetWorkingPrinciple,
        instrumentRole: clientInstrumentRoleLabel(
          ClientInstrumentRole.transmitter,
        ),
      ),
    );
  }

  return out;
}

/// Grava no cadastro do cliente o que o técnico preencheu na OS.
Future<SavedClient?> applyOsSlotToClientCatalog({
  required SavedOs os,
  required OsCalibrationSlot slot,
}) {
  return applyOsSlotsToClientCatalog(os: os, slots: [slot]);
}

/// Várias linhas da OS numa gravação só. [onlyNew]: ignora as que vieram de
/// instrumento já cadastrado — o cadastro é a origem delas, e a cópia na OS
/// pode estar velha.
Future<SavedClient?> applyOsSlotsToClientCatalog({
  required SavedOs os,
  required List<OsCalibrationSlot> slots,
  bool onlyNew = false,
}) async {
  final store = ClientStore.instance;
  var client = store.findMatch(cnpj: os.rdo.cnpj, name: os.rdo.client);
  if (client != null) client = await store.ensureFull(client.id) ?? client;
  final known = <String>{
    if (client != null) ...[
      for (final item in client.equipment) item.id,
      for (final system in client.resolvedSystems)
        for (final item in system.instruments) item.id,
    ],
  };
  final incoming = <List<ClientEquipment>>[
    for (final slot in slots)
      if (!onlyNew ||
          slot.equipmentId.trim().isEmpty ||
          !known.contains(slot.equipmentId.trim()))
        equipmentFromOsSlot(slot),
  ].where((items) => items.isNotEmpty).toList();
  if (incoming.isEmpty) return client;
  if (client == null) {
    if (os.rdo.client.trim().isEmpty && os.rdo.cnpj.trim().isEmpty) {
      return null;
    }
    client = await store.upsertFromRdo(os.rdo);
  }
  var mergedEquipment = client.storedEquipment.isNotEmpty
      ? client.storedEquipment
      : client.equipment;
  var mergedSystems = client.resolvedSystems;
  for (final items in incoming) {
    mergedEquipment = mergeEquipment(mergedEquipment, items);
    mergedSystems = mergeClientSystems(
      mergedSystems,
      systemsFromEquipment(items),
    );
  }
  String catalogKey(List<ClientSystem> systems, List<ClientEquipment> items) =>
      jsonEncode([
        for (final s in systems) s.toJson(),
        for (final e in items) e.toJson(),
      ]);
  if (catalogKey(mergedSystems, mergedEquipment) ==
      catalogKey(
        client.resolvedSystems,
        client.storedEquipment.isNotEmpty
            ? client.storedEquipment
            : client.equipment,
      )) {
    return client;
  }
  return store.saveEdited(
    client.copyWith(
      systems: mergedSystems,
      equipment: mergedEquipment,
      updatedAt: DateTime.now(),
    ),
    base: client,
  );
}
