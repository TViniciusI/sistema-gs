import 'dart:convert';

const defaultTechnicianCargo = 'Técnico em Instrumentação Industrial';
const assistantTechnicianCargo =
    'Assistente Técnico em Instrumentação Industrial';

/// Cargos padrão do quadro técnico (RDO, RH e geração de OS).
const technicianCargoOptions = <String>[
  defaultTechnicianCargo,
  assistantTechnicianCargo,
];

/// Normaliza cargo legado / vazio para um cargo válido do quadro.
String normalizeTechnicianCargo(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty ||
      value == 'Técnico' ||
      value.contains(' · ') ||
      RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) {
    return defaultTechnicianCargo;
  }
  return value;
}

const gsCompanyName = 'GS SOLUÇÕES LTDA.';
const gsCompanyLegalName = 'GS SOLUÇÕES LTDA';
const gsCompanyTradeName = 'GS SOLUÇÕES';
const gsCompanyCnpj = '64.949.495/0001-82';
const gsCompanyIe = '75.107.007-6';
const gsCompanyIm = '5275155';
const gsCompanyStreet = 'Av. Genmo Deodoro, 1893';
const gsCompanyNeighborhood = 'Cremação';
const gsCompanyCity = 'Belém';
const gsCompanyUf = 'PA';
const gsCompanyCep = '66.040-140';
const gsCompanyAddress =
    'Av. Genmo Deodoro, 1893, Cremação, Belém/PA. CEP 66.040-140';
const gsCompanyPhone = '(21) 9.9578-8574';
const gsCompanyEmail = 'cleber@gssolucoestec.com.br';
const gsCompanySite = 'https://gssolucoestec.com.br/';
const gsCompanySimples = 'Sim';
const gsCompanyBank = 'Santander';
const gsCompanyBankCode = '33';
const gsCompanyBankAgency = '2106';
const gsCompanyBankAccount = '13.001251-2';
const gsCompanyPix = '64.949.495/0001-82';

enum OsFileKind { certificate, photo, signature, rdo }

enum OsStatus { rascunho, comTecnico, emAndamento, servicoEncerrado, encerrada }

OsFileKind osFileKindFrom(String? raw) {
  switch (raw) {
    case 'photo':
      return OsFileKind.photo;
    case 'signature':
      return OsFileKind.signature;
    case 'rdo':
      return OsFileKind.rdo;
    default:
      return OsFileKind.certificate;
  }
}

OsStatus osStatusFrom(String? raw) {
  switch (raw) {
    case 'comTecnico':
    case 'com_tecnico':
      return OsStatus.comTecnico;
    case 'emAndamento':
    case 'em_andamento':
      return OsStatus.emAndamento;
    case 'servicoEncerrado':
    case 'servico_encerrado':
      return OsStatus.servicoEncerrado;
    case 'encerrada':
      return OsStatus.encerrada;
    default:
      return OsStatus.rascunho;
  }
}

bool isClosedOsStatus(OsStatus status) =>
    status == OsStatus.encerrada || status == OsStatus.servicoEncerrado;

/// Sync OS entre máquinas: reativação na nuvem não pode perder para cache local.
OsStatus preferOsStatus({
  required OsStatus local,
  required OsStatus remote,
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
}) {
  if (remoteUpdatedAt.isAfter(localUpdatedAt)) return remote;
  if (localUpdatedAt.isAfter(remoteUpdatedAt)) return local;
  if (isClosedOsStatus(local) && !isClosedOsStatus(remote)) return remote;
  if (!isClosedOsStatus(local) && isClosedOsStatus(remote)) return remote;
  return remote;
}

String jsonText(dynamic value) {
  if (value == null) return '';
  return '$value'.trim();
}

String osStatusLabel(OsStatus status) {
  switch (status) {
    case OsStatus.rascunho:
      return 'Rascunho';
    case OsStatus.comTecnico:
      return 'Com o técnico';
    case OsStatus.emAndamento:
      return 'Em andamento';
    case OsStatus.servicoEncerrado:
      return 'Serviço encerrado (aguarda Cleber)';
    case OsStatus.encerrada:
      return 'OS encerrada';
  }
}

class DraftFile {
  const DraftFile({
    required this.name,
    required this.kind,
    this.bytes,
    this.path,
    this.label,
  });

  final String name;
  final OsFileKind kind;
  final List<int>? bytes;
  final String? path;
  final String? label;

  DraftFile copyWith({String? name, String? label}) {
    return DraftFile(
      name: name ?? this.name,
      kind: kind,
      bytes: bytes,
      path: path,
      label: label ?? this.label,
    );
  }
}

class SavedFile {
  const SavedFile({
    required this.name,
    required this.path,
    required this.kind,
    this.bytes,
    this.label,
    this.uploadedBy,
  });

  final String name;
  final String path;
  final OsFileKind kind;
  final List<int>? bytes;
  final String? label;

  /// E-mail de quem anexou (anexos da OS ficam só no login dessa pessoa).
  final String? uploadedBy;

  bool get isOsAttachment =>
      kind == OsFileKind.certificate || kind == OsFileKind.photo;

  Map<String, dynamic> toJson({bool withBytes = false}) {
    return {
      'name': name,
      'path': path,
      'kind': kind.name,
      if (label != null && label!.isNotEmpty) 'label': label,
      if (uploadedBy != null && uploadedBy!.isNotEmpty)
        'uploadedBy': uploadedBy,
      if (withBytes && bytes != null && bytes!.isNotEmpty)
        'data': base64Encode(bytes!),
    };
  }

  factory SavedFile.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as String?;
    return SavedFile(
      name: json['name'] as String? ?? 'arquivo',
      path: json['path'] as String? ?? '',
      kind: osFileKindFrom(json['kind'] as String?),
      label: json['label'] as String?,
      uploadedBy: json['uploadedBy'] as String?,
      bytes: data == null || data.isEmpty ? null : base64Decode(data),
    );
  }
}

class SavedRdo {
  const SavedRdo({
    required this.id,
    required this.date,
    required this.clockIn,
    required this.lunchStart,
    required this.lunchEnd,
    required this.clockOut,
    required this.description,
    required this.notes,
    required this.files,
    required this.createdAt,
    this.responsibleName = '',
    this.signedAt,
    this.clientSignedName = '',
    this.clientSignedAt,
    this.signToken = '',
    this.clientStampOnPdf = '',
    this.absentNames = const [],
  });

  final String id;
  final DateTime date;
  final String clockIn;

  /// Técnicos da OS que não foram neste dia (saem do RDO e das horas).
  final List<String> absentNames;
  final String lunchStart;
  final String lunchEnd;
  final String clockOut;
  final String description;
  final String notes;
  final List<SavedFile> files;
  final DateTime createdAt;
  final String responsibleName;
  final DateTime? signedAt;
  final String clientSignedName;
  final DateTime? clientSignedAt;
  final String signToken;
  final String clientStampOnPdf;

  List<SavedFile> get photos => [
    for (final file in files)
      if (file.kind == OsFileKind.photo) file,
  ];

  SavedFile? get signature {
    for (final file in files) {
      if (file.kind == OsFileKind.signature) return file;
    }
    return null;
  }

  SavedFile? get pdf {
    for (final file in files) {
      if (file.kind == OsFileKind.rdo) return file;
    }
    return null;
  }

  bool get isSigned => signature != null || responsibleName.trim().isNotEmpty;

  bool get clientSigned => clientSignedName.trim().isNotEmpty;

  bool get bothSigned => isSigned && clientSigned;

  SavedRdo copyWith({
    DateTime? date,
    List<SavedFile>? files,
    String? description,
    String? notes,
    String? responsibleName,
    DateTime? signedAt,
    String? clientSignedName,
    DateTime? clientSignedAt,
    String? signToken,
    String? clientStampOnPdf,
    List<String>? absentNames,
    String? clockIn,
    String? lunchStart,
    String? lunchEnd,
    String? clockOut,
  }) {
    return SavedRdo(
      id: id,
      date: date ?? this.date,
      absentNames: absentNames ?? this.absentNames,
      clockIn: clockIn ?? this.clockIn,
      lunchStart: lunchStart ?? this.lunchStart,
      lunchEnd: lunchEnd ?? this.lunchEnd,
      clockOut: clockOut ?? this.clockOut,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      files: files ?? this.files,
      createdAt: createdAt,
      responsibleName: responsibleName ?? this.responsibleName,
      signedAt: signedAt ?? this.signedAt,
      clientSignedName: clientSignedName ?? this.clientSignedName,
      clientSignedAt: clientSignedAt ?? this.clientSignedAt,
      signToken: signToken ?? this.signToken,
      clientStampOnPdf: clientStampOnPdf ?? this.clientStampOnPdf,
    );
  }

  Map<String, dynamic> toJson({bool withBytes = false}) => {
    'id': id,
    'date': date.toIso8601String(),
    'clockIn': clockIn,
    'lunchStart': lunchStart,
    'lunchEnd': lunchEnd,
    'clockOut': clockOut,
    'description': description,
    'notes': notes,
    'files': files.map((file) => file.toJson(withBytes: withBytes)).toList(),
    'createdAt': createdAt.toIso8601String(),
    'signed': isSigned,
    if (responsibleName.trim().isNotEmpty)
      'responsibleName': responsibleName.trim(),
    if (signedAt != null) 'signedAt': signedAt!.toIso8601String(),
    if (clientSignedName.trim().isNotEmpty)
      'clientSignedName': clientSignedName.trim(),
    if (clientSignedAt != null)
      'clientSignedAt': clientSignedAt!.toIso8601String(),
    if (signToken.trim().isNotEmpty) 'signToken': signToken.trim(),
    if (clientStampOnPdf.trim().isNotEmpty)
      'clientStampOnPdf': clientStampOnPdf.trim(),
    if (absentNames.isNotEmpty) 'absent': absentNames,
  };

  factory SavedRdo.fromJson(Map<String, dynamic> json) {
    final files = [
      for (final item in (json['files'] as List? ?? const []))
        if (item is Map) SavedFile.fromJson(Map<String, dynamic>.from(item)),
    ];
    if (json['signed'] == true &&
        !files.any((file) => file.kind == OsFileKind.signature)) {
      files.add(
        const SavedFile(
          name: 'assinatura.png',
          path: 'remote:assinatura',
          kind: OsFileKind.signature,
        ),
      );
    }
    return SavedRdo(
      id: jsonText(json['id']).isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : jsonText(json['id']),
      date:
          DateTime.tryParse(jsonText(json['date'])) ??
          DateTime.tryParse(jsonText(json['createdAt'])) ??
          DateTime.now(),
      clockIn: jsonText(json['clockIn']),
      lunchStart: jsonText(json['lunchStart']),
      lunchEnd: jsonText(json['lunchEnd']),
      clockOut: jsonText(json['clockOut']),
      description: jsonText(json['description']),
      notes: jsonText(json['notes']),
      files: files,
      createdAt:
          DateTime.tryParse(jsonText(json['createdAt'])) ?? DateTime.now(),
      responsibleName: jsonText(json['responsibleName']),
      signedAt: DateTime.tryParse(jsonText(json['signedAt'])),
      clientSignedName: jsonText(json['clientSignedName']),
      clientSignedAt: DateTime.tryParse(jsonText(json['clientSignedAt'])),
      signToken: jsonText(json['signToken']),
      clientStampOnPdf: jsonText(json['clientStampOnPdf']),
      absentNames: [
        for (final item in (json['absent'] as List? ?? const []))
          if (jsonText(item).isNotEmpty) jsonText(item),
      ],
    );
  }
}

class OsCalibrationSlot {
  const OsCalibrationSlot({
    required this.id,
    required this.kind,
    required this.certificateNumber,
    this.serialNumber = '',
    this.equipmentId = '',
    this.equipmentTag = '',
    this.equipmentType = '',
    this.manufacturer = '',
    this.model = '',
    this.installLocation = '',
    this.systemType = '',
    this.product = '',
    this.workingPrinciple = '',
    this.quantity = '',
    this.dimensions = '',
    this.systemId = '',
    this.systemTag = '',
    this.assemblyKind = '',
    this.presetTag = '',
    this.presetManufacturer = '',
    this.presetModel = '',
    this.presetSerial = '',
    this.presetWorkingPrinciple = '',
    this.instrumentRole = '',
    this.densimeterWorkingPrinciple = '',
    this.densimeterManufacturer = '',
    this.densimeterModel = '',
    this.densimeterSerial = '',
    this.densimeterTag = '',
    this.pt100WorkingPrinciple = '',
    this.pt100Manufacturer = '',
    this.pt100Model = '',
    this.pt100Serial = '',
    this.pt100Tag = '',
    this.meshTag = '',
    this.meshEquipmentType = '',
    this.meshManufacturer = '',
    this.meshModel = '',
    this.meshSerialNumber = '',
    this.meshWorkingPrinciple = '',
    this.pressureType = '',
    this.pressureWorkingPrinciple = '',
    this.pressureManufacturer = '',
    this.pressureModel = '',
    this.pressureSerial = '',
    this.pressureTag = '',
    this.telemetryWorkingPrinciple = '',
    this.telemetryManufacturer = '',
    this.telemetryModel = '',
    this.telemetrySerial = '',
    this.telemetryTag = '',

    /// vazio | `confirmed` | `divergent`
    this.dataCheck = '',
    this.divergentNote = '',
    this.jobId = '',

    /// dd/MM/yyyy só para o adesivo; vazio = data do certificado.
    this.labelDate = '',

    /// '' | `pending` | `approved` | `rejected` — envio do técnico para o cadastro.
    this.catalogStatus = '',
    this.catalogSubmittedAt = '',
    this.catalogSubmittedBy = '',
    this.catalogReviewNote = '',
    this.catalogReviewedAt = '',
    this.catalogReviewedBy = '',
  });

  final String id;

  /// Nome do [CalibrationKind] (`volumetric`, `temperature`…).
  final String kind;
  final String certificateNumber;
  final String serialNumber;
  final String equipmentId;
  final String equipmentTag;
  final String equipmentType;
  final String manufacturer;
  final String model;
  final String installLocation;
  final String systemType;
  final String product;
  final String workingPrinciple;

  /// Como na planilha (texto livre, ex.: "1").
  final String quantity;
  final String dimensions;
  final String systemId;
  final String systemTag;
  final String assemblyKind;
  final String presetTag;
  final String presetManufacturer;
  final String presetModel;
  final String presetSerial;
  final String presetWorkingPrinciple;
  final String instrumentRole;
  final String densimeterWorkingPrinciple;
  final String densimeterManufacturer;
  final String densimeterModel;
  final String densimeterSerial;
  final String densimeterTag;
  final String pt100WorkingPrinciple;
  final String pt100Manufacturer;
  final String pt100Model;
  final String pt100Serial;
  final String pt100Tag;
  final String meshTag;
  final String meshEquipmentType;
  final String meshManufacturer;
  final String meshModel;
  final String meshSerialNumber;
  final String meshWorkingPrinciple;
  final String pressureType;
  final String pressureWorkingPrinciple;
  final String pressureManufacturer;
  final String pressureModel;
  final String pressureSerial;
  final String pressureTag;
  final String telemetryWorkingPrinciple;
  final String telemetryManufacturer;
  final String telemetryModel;
  final String telemetrySerial;
  final String telemetryTag;
  final String dataCheck;
  final String divergentNote;

  /// Id da calibração gerada a partir deste slot (se já existir).
  final String jobId;
  final String labelDate;
  final String catalogStatus;
  final String catalogSubmittedAt;
  final String catalogSubmittedBy;
  final String catalogReviewNote;
  final String catalogReviewedAt;
  final String catalogReviewedBy;

  bool get needsCadastro {
    if (equipmentId.trim().isNotEmpty) return false;
    if (equipmentTag.trim().isNotEmpty || serialNumber.trim().isNotEmpty) {
      return false;
    }
    final k = kind.trim().toLowerCase();
    if (k.contains('dens')) {
      return densimeterTag.trim().isEmpty && densimeterSerial.trim().isEmpty;
    }
    if (k == 'temperature' ||
        (k.contains('temp') && !k.contains('mesh') && !k.contains('malha'))) {
      return pt100Tag.trim().isEmpty && pt100Serial.trim().isEmpty;
    }
    if (k.contains('mesh') || k.contains('malha')) {
      return meshTag.trim().isEmpty &&
          meshSerialNumber.trim().isEmpty &&
          pt100Tag.trim().isEmpty &&
          pt100Serial.trim().isEmpty;
    }
    if (k.contains('press')) {
      return pressureTag.trim().isEmpty && pressureSerial.trim().isEmpty;
    }
    if (k.contains('telemetr')) {
      return telemetryTag.trim().isEmpty && telemetrySerial.trim().isEmpty;
    }
    return true;
  }

  bool get isDivergent => dataCheck == 'divergent';

  bool get isDataConfirmed => dataCheck == 'confirmed';

  bool get isCatalogPending => catalogStatus == 'pending';

  bool get isCatalogApproved => catalogStatus == 'approved';

  bool get isCatalogRejected => catalogStatus == 'rejected';

  /// Slot sem TAG/N/S continua podendo puxar do cadastro (não trava).
  bool get locksCatalogRefresh {
    if (needsCadastro) return false;
    return isDivergent ||
        isDataConfirmed ||
        isCatalogPending ||
        isCatalogRejected;
  }

  String get catalogStatusLabel {
    switch (catalogStatus) {
      case 'pending':
        return 'Aguardando conferência';
      case 'approved':
        return 'Aprovado no cadastro';
      case 'rejected':
        return 'Recusado — revisar';
      default:
        return '';
    }
  }

  String get title {
    final tag = equipmentTag.trim();
    if (tag.isNotEmpty) return tag;
    final type = equipmentType.trim();
    if (type.isNotEmpty) return type;
    final cert = certificateNumber.trim();
    if (cert.isNotEmpty) return cert;
    return 'Certificado';
  }

  String get subtitle {
    return [
      if (certificateNumber.trim().isNotEmpty) certificateNumber.trim(),
      if (serialNumber.trim().isNotEmpty) 'N/S ${serialNumber.trim()}',
      if (installLocation.trim().isNotEmpty) installLocation.trim(),
    ].join(' · ');
  }

  OsCalibrationSlot copyWith({
    String? kind,
    String? certificateNumber,
    String? serialNumber,
    String? equipmentId,
    String? equipmentTag,
    String? equipmentType,
    String? manufacturer,
    String? model,
    String? installLocation,
    String? systemType,
    String? product,
    String? workingPrinciple,
    String? quantity,
    String? dimensions,
    String? systemId,
    String? systemTag,
    String? assemblyKind,
    String? presetTag,
    String? presetManufacturer,
    String? presetModel,
    String? presetSerial,
    String? presetWorkingPrinciple,
    String? instrumentRole,
    String? densimeterWorkingPrinciple,
    String? densimeterManufacturer,
    String? densimeterModel,
    String? densimeterSerial,
    String? densimeterTag,
    String? pt100WorkingPrinciple,
    String? pt100Manufacturer,
    String? pt100Model,
    String? pt100Serial,
    String? pt100Tag,
    String? meshTag,
    String? meshEquipmentType,
    String? meshManufacturer,
    String? meshModel,
    String? meshSerialNumber,
    String? meshWorkingPrinciple,
    String? pressureType,
    String? pressureWorkingPrinciple,
    String? pressureManufacturer,
    String? pressureModel,
    String? pressureSerial,
    String? pressureTag,
    String? telemetryWorkingPrinciple,
    String? telemetryManufacturer,
    String? telemetryModel,
    String? telemetrySerial,
    String? telemetryTag,
    String? dataCheck,
    String? divergentNote,
    String? jobId,
    String? labelDate,
    String? catalogStatus,
    String? catalogSubmittedAt,
    String? catalogSubmittedBy,
    String? catalogReviewNote,
    String? catalogReviewedAt,
    String? catalogReviewedBy,
  }) {
    return OsCalibrationSlot(
      id: id,
      kind: kind ?? this.kind,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentTag: equipmentTag ?? this.equipmentTag,
      equipmentType: equipmentType ?? this.equipmentType,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      installLocation: installLocation ?? this.installLocation,
      systemType: systemType ?? this.systemType,
      product: product ?? this.product,
      workingPrinciple: workingPrinciple ?? this.workingPrinciple,
      quantity: quantity ?? this.quantity,
      dimensions: dimensions ?? this.dimensions,
      systemId: systemId ?? this.systemId,
      systemTag: systemTag ?? this.systemTag,
      assemblyKind: assemblyKind ?? this.assemblyKind,
      presetTag: presetTag ?? this.presetTag,
      presetManufacturer: presetManufacturer ?? this.presetManufacturer,
      presetModel: presetModel ?? this.presetModel,
      presetSerial: presetSerial ?? this.presetSerial,
      presetWorkingPrinciple:
          presetWorkingPrinciple ?? this.presetWorkingPrinciple,
      instrumentRole: instrumentRole ?? this.instrumentRole,
      densimeterWorkingPrinciple:
          densimeterWorkingPrinciple ?? this.densimeterWorkingPrinciple,
      densimeterManufacturer:
          densimeterManufacturer ?? this.densimeterManufacturer,
      densimeterModel: densimeterModel ?? this.densimeterModel,
      densimeterSerial: densimeterSerial ?? this.densimeterSerial,
      densimeterTag: densimeterTag ?? this.densimeterTag,
      pt100WorkingPrinciple:
          pt100WorkingPrinciple ?? this.pt100WorkingPrinciple,
      pt100Manufacturer: pt100Manufacturer ?? this.pt100Manufacturer,
      pt100Model: pt100Model ?? this.pt100Model,
      pt100Serial: pt100Serial ?? this.pt100Serial,
      pt100Tag: pt100Tag ?? this.pt100Tag,
      meshTag: meshTag ?? this.meshTag,
      meshEquipmentType: meshEquipmentType ?? this.meshEquipmentType,
      meshManufacturer: meshManufacturer ?? this.meshManufacturer,
      meshModel: meshModel ?? this.meshModel,
      meshSerialNumber: meshSerialNumber ?? this.meshSerialNumber,
      meshWorkingPrinciple: meshWorkingPrinciple ?? this.meshWorkingPrinciple,
      pressureType: pressureType ?? this.pressureType,
      pressureWorkingPrinciple:
          pressureWorkingPrinciple ?? this.pressureWorkingPrinciple,
      pressureManufacturer: pressureManufacturer ?? this.pressureManufacturer,
      pressureModel: pressureModel ?? this.pressureModel,
      pressureSerial: pressureSerial ?? this.pressureSerial,
      pressureTag: pressureTag ?? this.pressureTag,
      telemetryWorkingPrinciple:
          telemetryWorkingPrinciple ?? this.telemetryWorkingPrinciple,
      telemetryManufacturer:
          telemetryManufacturer ?? this.telemetryManufacturer,
      telemetryModel: telemetryModel ?? this.telemetryModel,
      telemetrySerial: telemetrySerial ?? this.telemetrySerial,
      telemetryTag: telemetryTag ?? this.telemetryTag,
      dataCheck: dataCheck ?? this.dataCheck,
      divergentNote: divergentNote ?? this.divergentNote,
      jobId: jobId ?? this.jobId,
      labelDate: labelDate ?? this.labelDate,
      catalogStatus: catalogStatus ?? this.catalogStatus,
      catalogSubmittedAt: catalogSubmittedAt ?? this.catalogSubmittedAt,
      catalogSubmittedBy: catalogSubmittedBy ?? this.catalogSubmittedBy,
      catalogReviewNote: catalogReviewNote ?? this.catalogReviewNote,
      catalogReviewedAt: catalogReviewedAt ?? this.catalogReviewedAt,
      catalogReviewedBy: catalogReviewedBy ?? this.catalogReviewedBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'certificateNumber': certificateNumber,
    'serialNumber': serialNumber,
    'equipmentId': equipmentId,
    'equipmentTag': equipmentTag,
    'equipmentType': equipmentType,
    'manufacturer': manufacturer,
    'model': model,
    'installLocation': installLocation,
    'systemType': systemType,
    'product': product,
    'workingPrinciple': workingPrinciple,
    'quantity': quantity,
    'dimensions': dimensions,
    'systemId': systemId,
    'systemTag': systemTag,
    'assemblyKind': assemblyKind,
    'presetTag': presetTag,
    'presetManufacturer': presetManufacturer,
    'presetModel': presetModel,
    'presetSerial': presetSerial,
    'presetWorkingPrinciple': presetWorkingPrinciple,
    'instrumentRole': instrumentRole,
    'densimeterWorkingPrinciple': densimeterWorkingPrinciple,
    'densimeterManufacturer': densimeterManufacturer,
    'densimeterModel': densimeterModel,
    'densimeterSerial': densimeterSerial,
    'densimeterTag': densimeterTag,
    'pt100WorkingPrinciple': pt100WorkingPrinciple,
    'pt100Manufacturer': pt100Manufacturer,
    'pt100Model': pt100Model,
    'pt100Serial': pt100Serial,
    'pt100Tag': pt100Tag,
    'meshTag': meshTag,
    'meshEquipmentType': meshEquipmentType,
    'meshManufacturer': meshManufacturer,
    'meshModel': meshModel,
    'meshSerialNumber': meshSerialNumber,
    'meshWorkingPrinciple': meshWorkingPrinciple,
    'pressureType': pressureType,
    'pressureWorkingPrinciple': pressureWorkingPrinciple,
    'pressureManufacturer': pressureManufacturer,
    'pressureModel': pressureModel,
    'pressureSerial': pressureSerial,
    'pressureTag': pressureTag,
    'telemetryWorkingPrinciple': telemetryWorkingPrinciple,
    'telemetryManufacturer': telemetryManufacturer,
    'telemetryModel': telemetryModel,
    'telemetrySerial': telemetrySerial,
    'telemetryTag': telemetryTag,
    'dataCheck': dataCheck,
    'divergentNote': divergentNote,
    'jobId': jobId,
    if (labelDate.isNotEmpty) 'labelDate': labelDate,
    'catalogStatus': catalogStatus,
    'catalogSubmittedAt': catalogSubmittedAt,
    'catalogSubmittedBy': catalogSubmittedBy,
    'catalogReviewNote': catalogReviewNote,
    'catalogReviewedAt': catalogReviewedAt,
    'catalogReviewedBy': catalogReviewedBy,
  };

  factory OsCalibrationSlot.fromJson(Map<String, dynamic> json) {
    final meshTag = jsonText(json['meshTag']);
    final meshMfg = jsonText(json['meshManufacturer']);
    final meshModel = jsonText(json['meshModel']);
    final meshSerial = jsonText(json['meshSerialNumber']);
    final meshPrinciple = jsonText(json['meshWorkingPrinciple']);
    return OsCalibrationSlot(
      id: jsonText(json['id']).isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : jsonText(json['id']),
      kind: jsonText(json['kind']).isEmpty
          ? 'volumetric'
          : jsonText(json['kind']),
      certificateNumber: jsonText(json['certificateNumber'] ?? json['number']),
      serialNumber: jsonText(json['serialNumber']),
      equipmentId: jsonText(json['equipmentId']),
      equipmentTag: jsonText(json['equipmentTag']),
      equipmentType: jsonText(json['equipmentType']),
      manufacturer: jsonText(json['manufacturer']),
      model: jsonText(json['model']),
      installLocation: jsonText(json['installLocation']),
      systemType: jsonText(json['systemType']),
      product: jsonText(json['product']),
      workingPrinciple: jsonText(json['workingPrinciple']),
      quantity: jsonText(json['quantity'] ?? json['quantidade']),
      dimensions: jsonText(json['dimensions'] ?? json['dimensoes']),
      systemId: jsonText(json['systemId']),
      systemTag: jsonText(json['systemTag']),
      assemblyKind: jsonText(json['assemblyKind']),
      presetTag: jsonText(json['presetTag']),
      presetManufacturer: jsonText(json['presetManufacturer']),
      presetModel: jsonText(json['presetModel']),
      presetSerial: jsonText(json['presetSerial']),
      presetWorkingPrinciple: jsonText(json['presetWorkingPrinciple']),
      instrumentRole: jsonText(json['instrumentRole']),
      densimeterWorkingPrinciple: jsonText(json['densimeterWorkingPrinciple']),
      densimeterManufacturer: jsonText(json['densimeterManufacturer']),
      densimeterModel: jsonText(json['densimeterModel']),
      densimeterSerial: jsonText(json['densimeterSerial']),
      densimeterTag: jsonText(json['densimeterTag']),
      pt100WorkingPrinciple: jsonText(json['pt100WorkingPrinciple']).isNotEmpty
          ? jsonText(json['pt100WorkingPrinciple'])
          : meshPrinciple,
      pt100Manufacturer: jsonText(json['pt100Manufacturer']).isNotEmpty
          ? jsonText(json['pt100Manufacturer'])
          : meshMfg,
      pt100Model: jsonText(json['pt100Model']).isNotEmpty
          ? jsonText(json['pt100Model'])
          : meshModel,
      pt100Serial: jsonText(json['pt100Serial']).isNotEmpty
          ? jsonText(json['pt100Serial'])
          : meshSerial,
      pt100Tag: jsonText(json['pt100Tag']).isNotEmpty
          ? jsonText(json['pt100Tag'])
          : meshTag,
      meshTag: meshTag,
      meshEquipmentType: jsonText(json['meshEquipmentType']),
      meshManufacturer: meshMfg,
      meshModel: meshModel,
      meshSerialNumber: meshSerial,
      meshWorkingPrinciple: meshPrinciple,
      pressureType: jsonText(json['pressureType']),
      pressureWorkingPrinciple: jsonText(json['pressureWorkingPrinciple']),
      pressureManufacturer: jsonText(json['pressureManufacturer']),
      pressureModel: jsonText(json['pressureModel']),
      pressureSerial: jsonText(json['pressureSerial']),
      pressureTag: jsonText(json['pressureTag']),
      telemetryWorkingPrinciple: jsonText(json['telemetryWorkingPrinciple']),
      telemetryManufacturer: jsonText(json['telemetryManufacturer']),
      telemetryModel: jsonText(json['telemetryModel']),
      telemetrySerial: jsonText(json['telemetrySerial']),
      telemetryTag: jsonText(json['telemetryTag']),
      dataCheck: jsonText(json['dataCheck']),
      divergentNote: jsonText(json['divergentNote']),
      jobId: jsonText(json['jobId']),
      labelDate: jsonText(json['labelDate']),
      catalogStatus: jsonText(json['catalogStatus']),
      catalogSubmittedAt: jsonText(json['catalogSubmittedAt']),
      catalogSubmittedBy: jsonText(json['catalogSubmittedBy']),
      catalogReviewNote: jsonText(json['catalogReviewNote']),
      catalogReviewedAt: jsonText(json['catalogReviewedAt']),
      catalogReviewedBy: jsonText(json['catalogReviewedBy']),
    );
  }

  factory OsCalibrationSlot.fromEquipment({
    required String id,
    required String kind,
    required String certificateNumber,
    required ClientEquipment equipment,
    String dataCheck = '',
    String divergentNote = '',
    String jobId = '',
    String catalogStatus = '',
    String catalogSubmittedAt = '',
    String catalogSubmittedBy = '',
    String catalogReviewNote = '',
    String catalogReviewedAt = '',
    String catalogReviewedBy = '',
  }) {
    final role = clientInstrumentRoleFrom(equipment.instrumentRole);
    final type =
        '${equipment.equipmentType} ${equipment.systemType} ${equipment.assemblyKind}'
            .toLowerCase();
    final isDens =
        role == ClientInstrumentRole.densimeter || type.contains('dens');
    final isPt =
        role == ClientInstrumentRole.pt100 ||
        role == ClientInstrumentRole.mesh ||
        type.contains('pt100') ||
        type.contains('pt 100') ||
        type.contains('termorresist') ||
        type.contains('sensor de temperatura') ||
        equipment.workingPrinciple.toLowerCase().contains('termorresist');
    final isMesh =
        role == ClientInstrumentRole.mesh ||
        kind.trim().toLowerCase() == 'temperaturemesh' ||
        kind.trim().toLowerCase().contains('malha');
    return OsCalibrationSlot(
      id: id,
      kind: kind,
      certificateNumber: certificateNumber,
      // N/S do medidor e N/S do preset são campos distintos. Um medidor sem
      // serial continua pendente; nunca use o serial do preset como fallback.
      serialNumber: equipment.serialNumber,
      equipmentId: equipment.id,
      equipmentTag: equipment.tag,
      equipmentType: equipment.equipmentType,
      manufacturer: equipment.manufacturer,
      model: equipment.model,
      installLocation: equipment.installLocation,
      systemType: equipment.systemType,
      product: equipment.product,
      workingPrinciple: equipment.workingPrinciple,
      quantity: equipment.quantity > 0 ? '${equipment.quantity}' : '',
      dimensions: equipment.dimensions,
      systemId: equipment.systemId,
      systemTag: equipment.systemTag,
      assemblyKind: equipment.assemblyKind,
      presetTag: equipment.presetTag,
      presetManufacturer: equipment.presetManufacturer,
      presetModel: equipment.presetModel,
      presetSerial: equipment.presetSerial,
      presetWorkingPrinciple: equipment.presetWorkingPrinciple,
      instrumentRole: equipment.instrumentRole,
      densimeterWorkingPrinciple: isDens ? equipment.workingPrinciple : '',
      densimeterManufacturer: isDens ? equipment.manufacturer : '',
      densimeterModel: isDens ? equipment.model : '',
      densimeterSerial: isDens ? equipment.serialNumber : '',
      densimeterTag: isDens ? equipment.tag : '',
      pt100WorkingPrinciple: isPt
          ? equipment.workingPrinciple
          : equipment.meshWorkingPrinciple,
      pt100Manufacturer: isPt
          ? equipment.manufacturer
          : equipment.meshManufacturer,
      pt100Model: isPt ? equipment.model : equipment.meshModel,
      pt100Serial: isPt ? equipment.serialNumber : equipment.meshSerialNumber,
      pt100Tag: isPt ? equipment.tag : equipment.meshTag,
      meshTag: isMesh && equipment.meshTag.trim().isEmpty
          ? equipment.tag
          : equipment.meshTag,
      meshEquipmentType: isMesh && equipment.meshEquipmentType.trim().isEmpty
          ? equipment.equipmentType
          : equipment.meshEquipmentType,
      meshManufacturer: isMesh && equipment.meshManufacturer.trim().isEmpty
          ? equipment.manufacturer
          : equipment.meshManufacturer,
      meshModel: isMesh && equipment.meshModel.trim().isEmpty
          ? equipment.model
          : equipment.meshModel,
      meshSerialNumber: isMesh && equipment.meshSerialNumber.trim().isEmpty
          ? equipment.serialNumber
          : equipment.meshSerialNumber,
      meshWorkingPrinciple:
          isMesh && equipment.meshWorkingPrinciple.trim().isEmpty
          ? equipment.workingPrinciple
          : equipment.meshWorkingPrinciple,
      dataCheck: dataCheck,
      divergentNote: divergentNote,
      jobId: jobId,
      catalogStatus: catalogStatus,
      catalogSubmittedAt: catalogSubmittedAt,
      catalogSubmittedBy: catalogSubmittedBy,
      catalogReviewNote: catalogReviewNote,
      catalogReviewedAt: catalogReviewedAt,
      catalogReviewedBy: catalogReviewedBy,
    );
  }
}

int _calibrationSlotFillScore(OsCalibrationSlot slot) {
  var score = 0;
  if (slot.jobId.trim().isNotEmpty) score += 8;
  if (slot.equipmentId.trim().isNotEmpty) score += 4;
  if (slot.equipmentTag.trim().isNotEmpty) score += 2;
  if (slot.serialNumber.trim().isNotEmpty) score += 2;
  if (slot.isDataConfirmed) score += 1;
  if (slot.catalogStatus.trim().isNotEmpty) score += 1;
  return score;
}

/// Um número de certificado por OS — mantém o slot mais completo se houver cópia.
List<OsCalibrationSlot> dedupeCalibrationSlotsByCertificateNumber(
  List<OsCalibrationSlot> slots,
) {
  if (slots.length < 2) return slots;
  final byKey = <String, OsCalibrationSlot>{};
  final order = <String>[];
  for (final slot in slots) {
    final number = slot.certificateNumber.trim().toUpperCase();
    final key = number.isEmpty ? 'id:${slot.id}' : 'n:$number';
    final existing = byKey[key];
    if (existing == null) {
      order.add(key);
      byKey[key] = slot;
      continue;
    }
    byKey[key] =
        _calibrationSlotFillScore(slot) >= _calibrationSlotFillScore(existing)
        ? slot
        : existing;
  }
  if (order.length == slots.length) return slots;
  return [for (final key in order) byKey[key]!];
}

class SavedOs {
  const SavedOs({
    required this.id,
    required this.number,
    required this.ownerEmail,
    required this.createdAt,
    required this.files,
    this.emailed = false,
    this.signerName,
    this.rdo = const RdoData(),
    this.technicianEmail = '',
    this.technicianName = '',
    this.technicianEmails = const [],
    this.status = OsStatus.rascunho,
    this.rdos = const [],
    this.startsAt,
    this.calibrationSlots = const [],
    this.updatedAt,
    this.calibrationEditBy = '',
    this.calibrationEditAt,
  });

  final String id;
  final String number;
  final String ownerEmail;
  final DateTime createdAt;
  final List<SavedFile> files;
  final bool emailed;
  final String? signerName;
  final RdoData rdo;
  final String technicianEmail;
  final String technicianName;
  final List<String> technicianEmails;
  final OsStatus status;
  final List<SavedRdo> rdos;
  final DateTime? startsAt;
  final List<OsCalibrationSlot> calibrationSlots;

  /// Última alteração relevante (status, RDO, slots). Usado no sync entre máquinas.
  final DateTime? updatedAt;

  /// Quem está com a OS aberta para calibrar (trava leve, ~45 min).
  final String calibrationEditBy;
  final DateTime? calibrationEditAt;

  DateTime get lastUpdatedAt => updatedAt ?? createdAt;

  bool get hasCalibrationPlan => calibrationSlots.isNotEmpty;

  DateTime get startDay {
    final raw = startsAt ?? createdAt;
    return DateTime(raw.year, raw.month, raw.day);
  }

  List<String> get assigneeEmails {
    if (technicianEmails.isNotEmpty) return technicianEmails;
    final single = technicianEmail.trim();
    return single.isEmpty ? const [] : [single];
  }

  String get technicianLabel {
    final unique = uniquePersonNames(technicianName);
    if (unique.isNotEmpty) return unique;
    return technicianName.trim();
  }

  bool isAssignedTo(String email) {
    return isAssignedToAny(assignmentIdsFor(email: email));
  }

  bool isAssignedToAny(Set<String> viewerIds) {
    if (viewerIds.isEmpty) return false;
    for (final assignee in assigneeEmails) {
      if (personMatchesAnyId(assignee, viewerIds)) return true;
    }
    for (final part in technicianName.split(',')) {
      if (personMatchesAnyId(part, viewerIds)) return true;
    }
    return false;
  }

  List<SavedFile> get certificates => [
    for (final file in files)
      if (file.kind == OsFileKind.certificate) file,
  ];

  List<SavedFile> get photos => [
    for (final entry in rdos) ...entry.photos,
    for (final file in files)
      if (file.kind == OsFileKind.photo) file,
  ];

  SavedFile? get signature {
    for (final entry in rdos.reversed) {
      if (entry.signature != null) return entry.signature;
    }
    for (final file in files) {
      if (file.kind == OsFileKind.signature) return file;
    }
    return null;
  }

  bool get isSigned => signature != null;

  SavedFile? get rdoFile {
    for (final entry in rdos.reversed) {
      if (entry.pdf != null) return entry.pdf;
    }
    for (final file in files) {
      if (file.kind == OsFileKind.rdo) return file;
    }
    return null;
  }

  bool get hasRdo => rdos.isNotEmpty || rdoFile != null;

  bool get isClosed => status == OsStatus.encerrada;

  /// Outro usuário editou calibração há menos de 45 min.
  bool calibrationEditHeldByOther(String email) {
    final by = calibrationEditBy.trim().toLowerCase();
    final me = email.trim().toLowerCase();
    if (by.isEmpty || me.isEmpty || by == me) return false;
    final at = calibrationEditAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 45);
  }

  bool get canFillRdo =>
      status != OsStatus.encerrada && status != OsStatus.rascunho;

  bool get canMarkServiceDone =>
      hasRdo &&
      (status == OsStatus.comTecnico || status == OsStatus.emAndamento);

  bool get canCloseOs => status == OsStatus.servicoEncerrado;

  bool get canReopenOs =>
      status == OsStatus.encerrada || status == OsStatus.servicoEncerrado;

  String? get baseSignerLabel {
    if (rdo.baseName.trim().isNotEmpty) return rdo.baseName.trim();
    final name = signerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  List<SavedFile> get attachments => [
    for (final file in files)
      if (file.isOsAttachment) file,
  ];

  List<SavedFile> get mailFiles => mailFilesFor();

  List<SavedFile> mailFilesFor({
    Iterable<String>? rdoIds,
    bool includeRdo = true,
    bool includeAttachments = true,
  }) {
    final selected = rdoIds == null
        ? rdos
        : [
            for (final entry in rdos)
              if (rdoIds.contains(entry.id)) entry,
          ];
    return [
      if (includeRdo)
        for (final entry in selected)
          if (entry.pdf != null) entry.pdf!,
      if (includeAttachments) ...attachments,
    ];
  }

  SavedRdo? rdoOnDay(DateTime day) {
    for (final entry in rdos) {
      if (entry.date.year == day.year &&
          entry.date.month == day.month &&
          entry.date.day == day.day) {
        return entry;
      }
    }
    return null;
  }

  SavedOs copyWith({
    List<SavedFile>? files,
    bool? emailed,
    String? signerName,
    RdoData? rdo,
    String? technicianEmail,
    String? technicianName,
    List<String>? technicianEmails,
    OsStatus? status,
    List<SavedRdo>? rdos,
    DateTime? startsAt,
    List<OsCalibrationSlot>? calibrationSlots,
    DateTime? updatedAt,
    bool touchUpdatedAt = false,
    String? calibrationEditBy,
    DateTime? calibrationEditAt,
    bool clearCalibrationEdit = false,
  }) {
    return SavedOs(
      id: id,
      number: number,
      ownerEmail: ownerEmail,
      createdAt: createdAt,
      files: files ?? this.files,
      emailed: emailed ?? this.emailed,
      signerName: signerName ?? this.signerName,
      rdo: rdo ?? this.rdo,
      technicianEmail: technicianEmail ?? this.technicianEmail,
      technicianName: technicianName ?? this.technicianName,
      technicianEmails: technicianEmails ?? this.technicianEmails,
      status: status ?? this.status,
      rdos: rdos ?? this.rdos,
      startsAt: startsAt ?? this.startsAt,
      calibrationSlots: calibrationSlots ?? this.calibrationSlots,
      updatedAt: touchUpdatedAt
          ? DateTime.now()
          : (updatedAt ?? this.updatedAt),
      calibrationEditBy: clearCalibrationEdit
          ? ''
          : (calibrationEditBy ?? this.calibrationEditBy),
      calibrationEditAt: clearCalibrationEdit
          ? null
          : (calibrationEditAt ?? this.calibrationEditAt),
    );
  }

  Map<String, dynamic> toJson({bool withBytes = false}) => {
    'id': id,
    'number': number,
    'ownerEmail': ownerEmail,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': lastUpdatedAt.toIso8601String(),
    'files': files.map((file) => file.toJson(withBytes: withBytes)).toList(),
    'emailed': emailed,
    if (signerName != null && signerName!.isNotEmpty) 'signerName': signerName,
    'rdo': rdo.toJson(),
    'technicianEmail': technicianEmail.isNotEmpty
        ? technicianEmail
        : (assigneeEmails.isEmpty ? '' : assigneeEmails.first),
    'technicianName': technicianName,
    'technicianEmails': assigneeEmails,
    'status': status.name,
    'startsAt': startDay.toIso8601String(),
    'rdos': rdos.map((entry) => entry.toJson(withBytes: withBytes)).toList(),
    if (calibrationSlots.isNotEmpty)
      'calibrationSlots': [for (final slot in calibrationSlots) slot.toJson()],
    if (calibrationEditBy.trim().isNotEmpty)
      'calibrationEditBy': calibrationEditBy.trim(),
    if (calibrationEditAt != null)
      'calibrationEditAt': calibrationEditAt!.toIso8601String(),
  };

  factory SavedOs.fromJson(Map<String, dynamic> json) {
    final allFiles = [
      for (final item in (json['files'] as List? ?? const []))
        if (item is Map) SavedFile.fromJson(Map<String, dynamic>.from(item)),
    ];
    final header = RdoData.fromJson(
      json['rdo'] is Map
          ? Map<String, dynamic>.from(json['rdo'] as Map)
          : <String, dynamic>{},
    );
    final createdAt =
        DateTime.tryParse(jsonText(json['createdAt'])) ?? DateTime.now();
    final rawRdos = json['rdos'];
    List<SavedRdo> rdos;
    List<SavedFile> osFiles;
    if (rawRdos is List) {
      rdos = [
        for (final item in rawRdos)
          if (item is Map) SavedRdo.fromJson(Map<String, dynamic>.from(item)),
      ];
      osFiles = allFiles;
    } else {
      final daily = [
        for (final file in allFiles)
          if (file.kind != OsFileKind.certificate) file,
      ];
      osFiles = [
        for (final file in allFiles)
          if (file.kind == OsFileKind.certificate) file,
      ];
      rdos = daily.isEmpty && header.description.trim().isEmpty
          ? const []
          : [
              SavedRdo(
                id: 'legacy',
                date: createdAt,
                clockIn: header.clockIn,
                lunchStart: header.lunchStart,
                lunchEnd: header.lunchEnd,
                clockOut: header.clockOut,
                description: header.description,
                notes: header.notes,
                files: daily,
                createdAt: createdAt,
              ),
            ];
    }
    var status = osStatusFrom(jsonText(json['status']));
    if (json['status'] == null) {
      if (json['emailed'] == true && rdos.isNotEmpty) {
        status = OsStatus.emAndamento;
      } else if (rdos.isNotEmpty) {
        status = OsStatus.emAndamento;
      }
    }
    return SavedOs(
      id: jsonText(json['id']),
      number: jsonText(json['number']),
      ownerEmail: jsonText(json['ownerEmail']),
      createdAt: createdAt,
      startsAt: DateTime.tryParse(jsonText(json['startsAt'])) ?? createdAt,
      files: osFiles,
      emailed: json['emailed'] == true,
      signerName: jsonText(json['signerName']).isEmpty
          ? null
          : jsonText(json['signerName']),
      rdo: header,
      technicianEmail: jsonText(json['technicianEmail']),
      technicianName: jsonText(json['technicianName']),
      technicianEmails: _readStringList(
        json['technicianEmails'],
        jsonText(json['technicianEmail']),
      ),
      status: status,
      rdos: rdos,
      calibrationSlots: [
        for (final item in (json['calibrationSlots'] as List? ?? const []))
          if (item is Map)
            OsCalibrationSlot.fromJson(Map<String, dynamic>.from(item)),
      ],
      updatedAt:
          DateTime.tryParse(jsonText(json['updatedAt'])) ??
          DateTime.tryParse(jsonText(json['atualizado_em'])) ??
          DateTime.tryParse(jsonText(json['atualizadoEm'])),
      calibrationEditBy: jsonText(json['calibrationEditBy']),
      calibrationEditAt: DateTime.tryParse(jsonText(json['calibrationEditAt'])),
    );
  }
}

class RdoData {
  const RdoData({
    this.client = '',
    this.site = '',
    this.cnpj = '',
    this.systemType = '',
    this.service = '',
    this.clockIn = '08:00',
    this.lunchStart = '12:00',
    this.lunchEnd = '13:00',
    this.clockOut = '17:00',
    this.description = '',
    this.status = 'EM ANDAMENTO',
    this.notes = '',
    this.technicianCargo = defaultTechnicianCargo,
    this.baseName = '',
    this.baseCargo = '',
    this.baseEmail = '',
    this.basePhone = '',
    this.technicianFuncoes = const {},
    this.technicianCargos = const {},
    this.baseContacts = const [],
  });

  final String client;
  final String site;
  final String cnpj;
  final String systemType;
  final String service;
  final String clockIn;
  final String lunchStart;
  final String lunchEnd;
  final String clockOut;
  final String description;
  final String status;
  final String notes;
  final String technicianCargo;
  final String baseName;
  final String baseCargo;
  final String baseEmail;
  final String basePhone;
  final Map<String, String> technicianFuncoes;
  final Map<String, String> technicianCargos;
  final List<ClientBaseContact> baseContacts;

  List<ClientBaseContact> get resolvedBaseContacts => resolveBaseContacts(
    contacts: baseContacts,
    baseName: baseName,
    baseCargo: baseCargo,
    baseEmail: baseEmail,
    basePhone: basePhone,
  );

  RdoData withBaseContact(ClientBaseContact contact) {
    final contacts = [
      contact,
      for (final item in resolvedBaseContacts)
        if (item.name.trim().toLowerCase() != contact.name.trim().toLowerCase())
          item,
    ].take(3).toList();
    return copyWith(
      baseName: contact.name,
      baseCargo: contact.cargo,
      baseEmail: contact.email,
      basePhone: contact.phone,
      baseContacts: contacts,
    );
  }

  RdoData copyWith({
    Map<String, String>? technicianFuncoes,
    Map<String, String>? technicianCargos,
    String? baseName,
    String? baseCargo,
    String? baseEmail,
    String? basePhone,
    List<ClientBaseContact>? baseContacts,
  }) {
    return RdoData(
      client: client,
      site: site,
      cnpj: cnpj,
      systemType: systemType,
      service: service,
      clockIn: clockIn,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
      clockOut: clockOut,
      description: description,
      status: status,
      notes: notes,
      technicianCargo: technicianCargo,
      baseName: baseName ?? this.baseName,
      baseCargo: baseCargo ?? this.baseCargo,
      baseEmail: baseEmail ?? this.baseEmail,
      basePhone: basePhone ?? this.basePhone,
      technicianFuncoes: technicianFuncoes ?? this.technicianFuncoes,
      technicianCargos: technicianCargos ?? this.technicianCargos,
      baseContacts: baseContacts ?? this.baseContacts,
    );
  }

  RdoData mergedWithDay(SavedRdo day, {String? status}) {
    return RdoData(
      client: client,
      site: site,
      cnpj: cnpj,
      systemType: systemType,
      service: service,
      clockIn: day.clockIn,
      lunchStart: day.lunchStart,
      lunchEnd: day.lunchEnd,
      clockOut: day.clockOut,
      description: day.description,
      status: status ?? this.status,
      notes: day.notes,
      technicianCargo: technicianCargo,
      baseName: baseName,
      baseCargo: baseCargo,
      baseEmail: baseEmail,
      basePhone: basePhone,
      technicianFuncoes: technicianFuncoes,
      technicianCargos: technicianCargos,
      baseContacts: baseContacts,
    );
  }

  Map<String, dynamic> toJson() {
    final contacts = resolvedBaseContacts;
    final primary = contacts.isEmpty ? null : contacts.first;
    return {
      'client': client,
      'site': site,
      'cnpj': cnpj,
      'systemType': systemType,
      'service': service,
      'clockIn': clockIn,
      'lunchStart': lunchStart,
      'lunchEnd': lunchEnd,
      'clockOut': clockOut,
      'description': description,
      'status': status,
      'notes': notes,
      'technicianCargo': technicianCargo,
      'baseName': primary?.name ?? baseName,
      'baseCargo': primary?.cargo ?? baseCargo,
      'baseEmail': primary?.email ?? baseEmail,
      'basePhone': primary?.phone ?? basePhone,
      if (contacts.isNotEmpty)
        'baseContacts': [for (final item in contacts) item.toJson()],
      if (technicianFuncoes.isNotEmpty) 'technicianFuncoes': technicianFuncoes,
      if (technicianCargos.isNotEmpty) 'technicianCargos': technicianCargos,
    };
  }

  factory RdoData.fromJson(Map<String, dynamic> json) {
    final contacts = resolveBaseContacts(
      contacts: readBaseContacts(json['baseContacts']),
      baseName: json['baseName'] as String? ?? '',
      baseCargo: json['baseCargo'] as String? ?? '',
      baseEmail: json['baseEmail'] as String? ?? '',
      basePhone: json['basePhone'] as String? ?? '',
    );
    final primary = contacts.isEmpty ? null : contacts.first;
    return RdoData(
      client: json['client'] as String? ?? '',
      site: json['site'] as String? ?? '',
      cnpj: json['cnpj'] as String? ?? '',
      systemType: json['systemType'] as String? ?? '',
      service: json['service'] as String? ?? '',
      clockIn: json['clockIn'] as String? ?? '08:00',
      lunchStart: json['lunchStart'] as String? ?? '12:00',
      lunchEnd: json['lunchEnd'] as String? ?? '13:00',
      clockOut: json['clockOut'] as String? ?? '17:00',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'EM ANDAMENTO',
      notes: json['notes'] as String? ?? '',
      technicianCargo:
          json['technicianCargo'] as String? ?? defaultTechnicianCargo,
      baseName: primary?.name ?? (json['baseName'] as String? ?? ''),
      baseCargo: primary?.cargo ?? (json['baseCargo'] as String? ?? ''),
      baseEmail: primary?.email ?? (json['baseEmail'] as String? ?? ''),
      basePhone: primary?.phone ?? (json['basePhone'] as String? ?? ''),
      technicianFuncoes: _readStringMap(json['technicianFuncoes']),
      technicianCargos: _readStringMap(json['technicianCargos']),
      baseContacts: contacts,
    );
  }
}

enum ClientAssemblyKind {
  preset,
  transmitter,
  presetAndTransmitter,
  pt100,
  densimeter,
  mesh,
}

enum ClientInstrumentRole { meter, pt100, mesh, densimeter, transmitter }

ClientAssemblyKind clientAssemblyKindFrom(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.contains('preset') &&
      (value.contains('transm') || value.contains(' e '))) {
    return ClientAssemblyKind.presetAndTransmitter;
  }
  if (value.contains('presetandtransmitter') ||
      value == 'preset_and_transmitter') {
    return ClientAssemblyKind.presetAndTransmitter;
  }
  if (value.contains('preset')) return ClientAssemblyKind.preset;
  if (value.contains('dens')) return ClientAssemblyKind.densimeter;
  if (value.contains('malha') || value.contains('mesh')) {
    return ClientAssemblyKind.mesh;
  }
  if (value.contains('pt100') || value.contains('pt 100') || value == 'pt') {
    return ClientAssemblyKind.pt100;
  }
  if (value.contains('telemetr')) return ClientAssemblyKind.transmitter;
  return ClientAssemblyKind.transmitter;
}

ClientInstrumentRole clientInstrumentRoleFrom(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.contains('malha') || value.contains('mesh')) {
    return ClientInstrumentRole.mesh;
  }
  if (value.contains('pt100') || value.contains('pt 100') || value == 'pt') {
    return ClientInstrumentRole.pt100;
  }
  if (value.contains('dens')) return ClientInstrumentRole.densimeter;
  if (value.contains('transm') || value.contains('telemetr')) {
    return ClientInstrumentRole.transmitter;
  }
  return ClientInstrumentRole.meter;
}

String clientAssemblyKindLabel(ClientAssemblyKind kind) {
  switch (kind) {
    case ClientAssemblyKind.preset:
      return 'Preset';
    case ClientAssemblyKind.transmitter:
      return 'Transmissor';
    case ClientAssemblyKind.presetAndTransmitter:
      return 'Preset e transmissor';
    case ClientAssemblyKind.pt100:
      return 'PT100';
    case ClientAssemblyKind.densimeter:
      return 'Densímetro';
    case ClientAssemblyKind.mesh:
      return 'Malha';
  }
}

String clientInstrumentRoleLabel(ClientInstrumentRole role) {
  switch (role) {
    case ClientInstrumentRole.meter:
      return 'Medidor';
    case ClientInstrumentRole.pt100:
      return 'PT100';
    case ClientInstrumentRole.mesh:
      return 'Malha';
    case ClientInstrumentRole.densimeter:
      return 'Densímetro';
    case ClientInstrumentRole.transmitter:
      return 'Transmissor';
  }
}

class ClientInstrument {
  const ClientInstrument({
    required this.id,
    this.role = ClientInstrumentRole.meter,
    this.equipmentType = '',
    this.workingPrinciple = '',
    this.dimensions = '',
    this.manufacturer = '',
    this.model = '',
    this.serialNumber = '',
    this.tag = '',
    this.product = '',
    this.meshTag = '',
    this.meshEquipmentType = '',
    this.meshManufacturer = '',
    this.meshModel = '',
    this.meshSerialNumber = '',
    this.meshWorkingPrinciple = '',
  });

  final String id;
  final ClientInstrumentRole role;
  final String equipmentType;
  final String workingPrinciple;
  final String dimensions;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String tag;

  /// Produto / fluido da linha (planilha Cleber · Malha → Produto).
  final String product;
  final String meshTag;
  final String meshEquipmentType;
  final String meshManufacturer;
  final String meshModel;
  final String meshSerialNumber;
  final String meshWorkingPrinciple;

  String get typeLabel {
    final type = equipmentType.trim();
    if (type.isNotEmpty) return type;
    return clientInstrumentRoleLabel(role);
  }

  String get title {
    final tagLabel = tag.trim();
    if (tagLabel.isNotEmpty) return tagLabel;
    if (serialNumber.trim().isNotEmpty) return 'N/S $serialNumber';
    return typeLabel;
  }

  String get meshTypeLabel {
    final type = meshEquipmentType.trim();
    if (type.isNotEmpty) return type;
    return 'Malha de temperatura';
  }

  String get meshTitle {
    final tagLabel = meshTag.trim();
    if (tagLabel.isNotEmpty) return tagLabel;
    if (meshSerialNumber.trim().isNotEmpty) return 'N/S $meshSerialNumber';
    if (tag.trim().isNotEmpty) return 'Malha $tag';
    return meshTypeLabel;
  }

  ClientInstrument copyWith({
    String? id,
    ClientInstrumentRole? role,
    String? equipmentType,
    String? workingPrinciple,
    String? dimensions,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? tag,
    String? product,
    String? meshTag,
    String? meshEquipmentType,
    String? meshManufacturer,
    String? meshModel,
    String? meshSerialNumber,
    String? meshWorkingPrinciple,
  }) {
    return ClientInstrument(
      id: id ?? this.id,
      role: role ?? this.role,
      equipmentType: equipmentType ?? this.equipmentType,
      workingPrinciple: workingPrinciple ?? this.workingPrinciple,
      dimensions: dimensions ?? this.dimensions,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      tag: tag ?? this.tag,
      product: product ?? this.product,
      meshTag: meshTag ?? this.meshTag,
      meshEquipmentType: meshEquipmentType ?? this.meshEquipmentType,
      meshManufacturer: meshManufacturer ?? this.meshManufacturer,
      meshModel: meshModel ?? this.meshModel,
      meshSerialNumber: meshSerialNumber ?? this.meshSerialNumber,
      meshWorkingPrinciple: meshWorkingPrinciple ?? this.meshWorkingPrinciple,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'equipmentType': equipmentType,
    'workingPrinciple': workingPrinciple,
    'dimensions': dimensions,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'tag': tag,
    'product': product,
    'meshTag': meshTag,
    'meshEquipmentType': meshEquipmentType,
    'meshManufacturer': meshManufacturer,
    'meshModel': meshModel,
    'meshSerialNumber': meshSerialNumber,
    'meshWorkingPrinciple': meshWorkingPrinciple,
  };

  factory ClientInstrument.fromJson(Map<String, dynamic> json) {
    return ClientInstrument(
      id: jsonText(json['id']).isEmpty ? _clientItemId() : jsonText(json['id']),
      role: clientInstrumentRoleFrom(
        jsonText(json['role'] ?? json['tipo'] ?? json['equipmentType']),
      ),
      equipmentType: jsonText(
        json['equipmentType'] ?? json['tipoEquipamento'] ?? json['instrumento'],
      ),
      workingPrinciple: jsonText(
        json['workingPrinciple'] ?? json['principioFuncionamento'],
      ),
      dimensions: jsonText(json['dimensions'] ?? json['dimensoes']),
      manufacturer: jsonText(json['manufacturer'] ?? json['fabricante']),
      model: jsonText(json['model'] ?? json['modelo']),
      serialNumber: jsonText(
        json['serialNumber'] ?? json['numeroSerie'] ?? json['nSerie'],
      ),
      tag: jsonText(json['tag'] ?? json['Tag']),
      product: jsonText(json['product'] ?? json['produto']),
      meshTag: jsonText(json['meshTag'] ?? json['tagMalha']),
      meshEquipmentType: jsonText(
        json['meshEquipmentType'] ?? json['tipoMalha'],
      ),
      meshManufacturer: jsonText(
        json['meshManufacturer'] ?? json['fabricanteMalha'],
      ),
      meshModel: jsonText(json['meshModel'] ?? json['modeloMalha']),
      meshSerialNumber: jsonText(
        json['meshSerialNumber'] ?? json['nSerieMalha'],
      ),
      meshWorkingPrinciple: jsonText(
        json['meshWorkingPrinciple'] ?? json['principioMalha'],
      ),
    );
  }
}

class ClientSystem {
  const ClientSystem({
    required this.id,
    this.systemType = '',
    this.installLocation = '',
    this.tag = '',
    this.kind = ClientAssemblyKind.transmitter,
    this.manufacturer = '',
    this.model = '',
    this.serialNumber = '',
    this.assemblyTag = '',
    this.meterCount = 0,
    this.pt100Count = 0,
    this.densimeterCount = 0,
    this.instruments = const [],
  });

  final String id;
  final String systemType;
  final String installLocation;
  final String tag;
  final ClientAssemblyKind kind;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String assemblyTag;
  final int meterCount;
  final int pt100Count;
  final int densimeterCount;
  final List<ClientInstrument> instruments;

  bool get hasPreset =>
      kind == ClientAssemblyKind.preset ||
      kind == ClientAssemblyKind.presetAndTransmitter;

  bool get hasTransmitterAssembly =>
      kind == ClientAssemblyKind.transmitter ||
      kind == ClientAssemblyKind.presetAndTransmitter;

  /// Mantido por compatibilidade: conjunto com preset (só ou com transmissor).
  bool get isPreset => hasPreset;

  bool get allowsCompanionInstruments => hasPreset || hasTransmitterAssembly;

  List<ClientInstrument> get meters => [
    for (final item in instruments)
      if (item.role == ClientInstrumentRole.meter) item,
  ];

  List<ClientInstrument> get pt100s => [
    for (final item in instruments)
      if (item.role == ClientInstrumentRole.pt100) item,
  ];

  List<ClientInstrument> get densimeters => [
    for (final item in instruments)
      if (item.role == ClientInstrumentRole.densimeter) item,
  ];

  List<ClientInstrument> get transmitters => [
    for (final item in instruments)
      if (item.role == ClientInstrumentRole.transmitter) item,
  ];

  List<ClientInstrument> get meshes => [
    for (final item in instruments)
      if (item.role == ClientInstrumentRole.mesh) item,
  ];

  List<ClientInstrument> get selectableInstruments {
    switch (kind) {
      case ClientAssemblyKind.preset:
      case ClientAssemblyKind.presetAndTransmitter:
        return [
          ...meters,
          ...pt100s,
          ...densimeters,
          if (kind == ClientAssemblyKind.presetAndTransmitter) ...transmitters,
        ];
      case ClientAssemblyKind.transmitter:
        return [...transmitters, ...meters, ...pt100s, ...densimeters];
      case ClientAssemblyKind.pt100:
        return pt100s.isNotEmpty ? pt100s : instruments;
      case ClientAssemblyKind.densimeter:
        return densimeters.isNotEmpty ? densimeters : instruments;
      case ClientAssemblyKind.mesh:
        return meshes.isNotEmpty ? meshes : instruments;
    }
  }

  String get title {
    final systemTag = tag.trim();
    if (systemTag.isNotEmpty) return systemTag;
    final assembly = assemblyTag.trim();
    if (assembly.isNotEmpty) return assembly;
    final type = systemType.trim();
    if (type.isNotEmpty) return type;
    return clientAssemblyKindLabel(kind);
  }

  String get _companionSummary => [
    if (meters.isNotEmpty) '${meters.length} medidor(es)',
    if (transmitters.isNotEmpty) '${transmitters.length} transmissor(es)',
    if (pt100s.isNotEmpty) '${pt100s.length} PT100 · ${pt100s.length} malha(s)',
    if (densimeters.isNotEmpty) '${densimeters.length} densímetro(s)',
    if (meshes.isNotEmpty) '${meshes.length} malha(s)',
  ].join(' · ');

  String get subtitle {
    return [
      if (systemType.trim().isNotEmpty) systemType.trim(),
      clientAssemblyKindLabel(kind),
      if (installLocation.trim().isNotEmpty) installLocation.trim(),
      if (_companionSummary.isNotEmpty) _companionSummary,
    ].join(' · ');
  }

  String get assemblyTitle {
    final label = clientAssemblyKindLabel(kind);
    final preset = assemblyTag.trim();
    if (preset.isNotEmpty) return '$label $preset';
    final serial = serialNumber.trim();
    if (serial.isNotEmpty) return '$label N/S $serial';
    return label;
  }

  String get assemblySubtitle {
    return [
      if (manufacturer.trim().isNotEmpty || model.trim().isNotEmpty)
        [
          if (manufacturer.trim().isNotEmpty) manufacturer.trim(),
          if (model.trim().isNotEmpty) model.trim(),
        ].join(' '),
      if (serialNumber.trim().isNotEmpty) 'N/S $serialNumber',
      if (_companionSummary.isNotEmpty) _companionSummary,
    ].join(' · ');
  }

  ClientSystem copyWith({
    String? id,
    String? systemType,
    String? installLocation,
    String? tag,
    ClientAssemblyKind? kind,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? assemblyTag,
    int? meterCount,
    int? pt100Count,
    int? densimeterCount,
    List<ClientInstrument>? instruments,
  }) {
    return ClientSystem(
      id: id ?? this.id,
      systemType: systemType ?? this.systemType,
      installLocation: installLocation ?? this.installLocation,
      tag: tag ?? this.tag,
      kind: kind ?? this.kind,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      assemblyTag: assemblyTag ?? this.assemblyTag,
      meterCount: meterCount ?? this.meterCount,
      pt100Count: pt100Count ?? this.pt100Count,
      densimeterCount: densimeterCount ?? this.densimeterCount,
      instruments: instruments ?? this.instruments,
    );
  }

  ClientSystem syncedCounts() {
    ClientInstrument assemblyAs(ClientInstrumentRole role) {
      final fromRole = [
        for (final item in instruments)
          if (item.role == role) item,
      ];
      final current = fromRole.isNotEmpty
          ? fromRole.first
          : (instruments.isNotEmpty
                ? instruments.first
                : ClientInstrument(id: _clientItemId(), role: role));
      return current.copyWith(
        role: role,
        manufacturer: current.manufacturer.trim().isEmpty
            ? manufacturer
            : current.manufacturer,
        model: current.model.trim().isEmpty ? model : current.model,
        serialNumber: current.serialNumber.trim().isEmpty
            ? serialNumber
            : current.serialNumber,
        tag: current.tag.trim().isEmpty
            ? (assemblyTag.trim().isNotEmpty ? assemblyTag : tag)
            : current.tag,
      );
    }

    switch (kind) {
      case ClientAssemblyKind.transmitter:
        return copyWith(
          instruments: [
            assemblyAs(ClientInstrumentRole.transmitter),
            ..._padInstruments(meters, meterCount, ClientInstrumentRole.meter),
            ..._padInstruments(pt100s, pt100Count, ClientInstrumentRole.pt100),
            ..._padInstruments(
              densimeters,
              densimeterCount,
              ClientInstrumentRole.densimeter,
            ),
          ],
        );
      case ClientAssemblyKind.preset:
        return copyWith(
          instruments: [
            ..._padInstruments(meters, meterCount, ClientInstrumentRole.meter),
            ..._padInstruments(pt100s, pt100Count, ClientInstrumentRole.pt100),
            ..._padInstruments(
              densimeters,
              densimeterCount,
              ClientInstrumentRole.densimeter,
            ),
          ],
        );
      case ClientAssemblyKind.presetAndTransmitter:
        return copyWith(
          instruments: [
            ..._padInstruments(meters, meterCount, ClientInstrumentRole.meter),
            ..._padInstruments(
              transmitters.isEmpty
                  ? [
                      ClientInstrument(
                        id: _clientItemId(),
                        role: ClientInstrumentRole.transmitter,
                      ),
                    ]
                  : transmitters,
              transmitters.isEmpty ? 1 : transmitters.length.clamp(1, 8),
              ClientInstrumentRole.transmitter,
            ),
            ..._padInstruments(pt100s, pt100Count, ClientInstrumentRole.pt100),
            ..._padInstruments(
              densimeters,
              densimeterCount,
              ClientInstrumentRole.densimeter,
            ),
          ],
        );
      case ClientAssemblyKind.pt100:
        return copyWith(
          meterCount: 0,
          densimeterCount: 0,
          pt100Count: pt100Count < 1 ? 1 : pt100Count,
          instruments: _padInstruments(
            pt100s,
            pt100Count < 1 ? 1 : pt100Count,
            ClientInstrumentRole.pt100,
          ),
        );
      case ClientAssemblyKind.densimeter:
        return copyWith(
          meterCount: 0,
          pt100Count: 0,
          densimeterCount: densimeterCount < 1 ? 1 : densimeterCount,
          instruments: _padInstruments(
            densimeters,
            densimeterCount < 1 ? 1 : densimeterCount,
            ClientInstrumentRole.densimeter,
          ),
        );
      case ClientAssemblyKind.mesh:
        return copyWith(
          meterCount: 0,
          pt100Count: 0,
          densimeterCount: 0,
          instruments: _padInstruments(
            meshes.isEmpty
                ? [
                    ClientInstrument(
                      id: _clientItemId(),
                      role: ClientInstrumentRole.mesh,
                      equipmentType: 'Malha de temperatura',
                    ),
                  ]
                : meshes,
            1,
            ClientInstrumentRole.mesh,
          ),
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'systemType': systemType,
    'installLocation': installLocation,
    'tag': tag,
    'kind': kind.name,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'assemblyTag': assemblyTag,
    'meterCount': meterCount,
    'pt100Count': pt100Count,
    'densimeterCount': densimeterCount,
    'instruments': [for (final item in instruments) item.toJson()],
  };

  factory ClientSystem.fromJson(Map<String, dynamic> json) {
    final parsed = ClientSystem(
      id: jsonText(json['id']).isEmpty ? _clientItemId() : jsonText(json['id']),
      systemType: jsonText(json['systemType'] ?? json['tipoSistema']),
      installLocation: jsonText(
        json['installLocation'] ?? json['localInstalado'] ?? json['local'],
      ),
      tag: jsonText(json['tag'] ?? json['systemTag'] ?? json['Tag']),
      kind: clientAssemblyKindFrom(jsonText(json['kind'] ?? json['tipo'])),
      manufacturer: jsonText(json['manufacturer'] ?? json['fabricante']),
      model: jsonText(json['model'] ?? json['modelo']),
      serialNumber: jsonText(
        json['serialNumber'] ?? json['numeroSerie'] ?? json['nSerie'],
      ),
      assemblyTag: jsonText(json['assemblyTag'] ?? json['presetTag']),
      meterCount: _readInt(json['meterCount'] ?? json['qtdMedidor'], 0),
      pt100Count: _readInt(json['pt100Count'] ?? json['qtdPt100'], 0),
      densimeterCount: _readInt(
        json['densimeterCount'] ?? json['qtdDensimetro'],
        0,
      ),
      instruments: [
        for (final item in (json['instruments'] as List<dynamic>? ?? const []))
          if (item is Map)
            ClientInstrument.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
    // Contagens ausentes/zeradas no JSON antigo não podem apagar instrumentos.
    return parsed
        .copyWith(
          meterCount: parsed.meterCount > parsed.meters.length
              ? parsed.meterCount
              : parsed.meters.length,
          pt100Count: parsed.pt100Count > parsed.pt100s.length
              ? parsed.pt100Count
              : parsed.pt100s.length,
          densimeterCount: parsed.densimeterCount > parsed.densimeters.length
              ? parsed.densimeterCount
              : parsed.densimeters.length,
        )
        .syncedCounts();
  }
}

List<ClientInstrument> _padInstruments(
  List<ClientInstrument> current,
  int count,
  ClientInstrumentRole role,
) {
  // Nunca apaga instrumentos já cadastrados: se a contagem vier 0/ausente
  // no JSON (cadastro antigo), mantém o que já existe na lista.
  final target = count > current.length ? count : current.length;
  if (target <= 0) return const [];
  final next = [...current];
  while (next.length < target) {
    next.add(ClientInstrument(id: _clientItemId(), role: role));
  }
  return [for (final item in next.take(target)) item.copyWith(role: role)];
}

class ClientEquipment {
  const ClientEquipment({
    required this.id,
    this.systemType = '',
    this.equipmentType = '',
    this.quantity = 1,
    this.workingPrinciple = '',
    this.dimensions = '',
    this.manufacturer = '',
    this.model = '',
    this.serialNumber = '',
    this.tag = '',
    this.product = '',
    this.installLocation = '',
    this.systemId = '',
    this.systemTag = '',
    this.assemblyKind = '',
    this.presetTag = '',
    this.presetManufacturer = '',
    this.presetModel = '',
    this.presetSerial = '',
    this.presetWorkingPrinciple = '',
    this.instrumentRole = '',
    this.meshTag = '',
    this.meshEquipmentType = '',
    this.meshManufacturer = '',
    this.meshModel = '',
    this.meshSerialNumber = '',
    this.meshWorkingPrinciple = '',
  });

  final String id;
  final String systemType;
  final String equipmentType;
  final int quantity;
  final String workingPrinciple;
  final String dimensions;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String tag;
  final String product;
  final String installLocation;
  final String systemId;
  final String systemTag;
  final String assemblyKind;
  final String presetTag;
  final String presetManufacturer;
  final String presetModel;
  final String presetSerial;
  final String presetWorkingPrinciple;
  final String instrumentRole;
  final String meshTag;
  final String meshEquipmentType;
  final String meshManufacturer;
  final String meshModel;
  final String meshSerialNumber;
  final String meshWorkingPrinciple;

  String get title {
    final tagLabel = tag.trim();
    if (tagLabel.isNotEmpty) return tagLabel;
    final type = equipmentType.trim();
    if (type.isNotEmpty) return type;
    final modelLabel = [
      if (manufacturer.trim().isNotEmpty) manufacturer.trim(),
      if (model.trim().isNotEmpty) model.trim(),
    ].join(' ');
    if (modelLabel.isNotEmpty) return modelLabel;
    return 'Instrumento';
  }

  String get subtitle {
    return [
      if (systemType.trim().isNotEmpty) systemType.trim(),
      if (product.trim().isNotEmpty) product.trim(),
      if (serialNumber.trim().isNotEmpty) 'N/S $serialNumber',
      if (installLocation.trim().isNotEmpty) installLocation.trim(),
    ].join(' · ');
  }

  String get matchKey {
    final serial = serialNumber.trim().toLowerCase();
    final tagKey = tag.trim().toLowerCase();
    if (serial.isNotEmpty && tagKey.isNotEmpty) return 's:$serial|t:$tagKey';
    if (serial.isNotEmpty) return 's:$serial';
    if (tagKey.isNotEmpty) return 't:$tagKey';
    return id;
  }

  ClientEquipment copyWith({
    String? systemType,
    String? equipmentType,
    int? quantity,
    String? workingPrinciple,
    String? dimensions,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? tag,
    String? product,
    String? installLocation,
    String? systemId,
    String? systemTag,
    String? assemblyKind,
    String? presetTag,
    String? presetManufacturer,
    String? presetModel,
    String? presetSerial,
    String? presetWorkingPrinciple,
    String? instrumentRole,
    String? meshTag,
    String? meshEquipmentType,
    String? meshManufacturer,
    String? meshModel,
    String? meshSerialNumber,
    String? meshWorkingPrinciple,
  }) {
    return ClientEquipment(
      id: id,
      systemType: systemType ?? this.systemType,
      equipmentType: equipmentType ?? this.equipmentType,
      quantity: quantity ?? this.quantity,
      workingPrinciple: workingPrinciple ?? this.workingPrinciple,
      dimensions: dimensions ?? this.dimensions,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      tag: tag ?? this.tag,
      product: product ?? this.product,
      installLocation: installLocation ?? this.installLocation,
      systemId: systemId ?? this.systemId,
      systemTag: systemTag ?? this.systemTag,
      assemblyKind: assemblyKind ?? this.assemblyKind,
      presetTag: presetTag ?? this.presetTag,
      presetManufacturer: presetManufacturer ?? this.presetManufacturer,
      presetModel: presetModel ?? this.presetModel,
      presetSerial: presetSerial ?? this.presetSerial,
      presetWorkingPrinciple:
          presetWorkingPrinciple ?? this.presetWorkingPrinciple,
      instrumentRole: instrumentRole ?? this.instrumentRole,
      meshTag: meshTag ?? this.meshTag,
      meshEquipmentType: meshEquipmentType ?? this.meshEquipmentType,
      meshManufacturer: meshManufacturer ?? this.meshManufacturer,
      meshModel: meshModel ?? this.meshModel,
      meshSerialNumber: meshSerialNumber ?? this.meshSerialNumber,
      meshWorkingPrinciple: meshWorkingPrinciple ?? this.meshWorkingPrinciple,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'systemType': systemType,
    'equipmentType': equipmentType,
    'quantity': quantity,
    'workingPrinciple': workingPrinciple,
    'dimensions': dimensions,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'tag': tag,
    'product': product,
    'installLocation': installLocation,
    'systemId': systemId,
    'systemTag': systemTag,
    'assemblyKind': assemblyKind,
    'presetTag': presetTag,
    'presetManufacturer': presetManufacturer,
    'presetModel': presetModel,
    'presetSerial': presetSerial,
    'presetWorkingPrinciple': presetWorkingPrinciple,
    'instrumentRole': instrumentRole,
    'meshTag': meshTag,
    'meshEquipmentType': meshEquipmentType,
    'meshManufacturer': meshManufacturer,
    'meshModel': meshModel,
    'meshSerialNumber': meshSerialNumber,
    'meshWorkingPrinciple': meshWorkingPrinciple,
  };

  factory ClientEquipment.fromJson(Map<String, dynamic> json) {
    return ClientEquipment(
      id: jsonText(json['id']).isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : jsonText(json['id']),
      systemType: jsonText(json['systemType'] ?? json['tipoSistema']),
      equipmentType: jsonText(
        json['equipmentType'] ?? json['tipoEquipamento'] ?? json['instrumento'],
      ),
      quantity: _readInt(json['quantity'] ?? json['quantidade'], 1),
      workingPrinciple: jsonText(
        json['workingPrinciple'] ?? json['principioFuncionamento'],
      ),
      dimensions: jsonText(json['dimensions'] ?? json['dimensoes']),
      manufacturer: jsonText(json['manufacturer'] ?? json['fabricante']),
      model: jsonText(json['model'] ?? json['modelo']),
      serialNumber: jsonText(
        json['serialNumber'] ?? json['numeroSerie'] ?? json['nSerie'],
      ),
      tag: jsonText(json['tag'] ?? json['Tag']),
      product: jsonText(json['product'] ?? json['produto']),
      installLocation: jsonText(
        json['installLocation'] ?? json['localInstalado'] ?? json['local'],
      ),
      systemId: jsonText(json['systemId']),
      systemTag: jsonText(json['systemTag'] ?? json['tagSistema']),
      assemblyKind: jsonText(json['assemblyKind'] ?? json['kind']),
      presetTag: jsonText(json['presetTag'] ?? json['assemblyTag']),
      presetManufacturer: jsonText(json['presetManufacturer']),
      presetModel: jsonText(json['presetModel']),
      presetSerial: jsonText(json['presetSerial']),
      presetWorkingPrinciple: jsonText(json['presetWorkingPrinciple']),
      instrumentRole: jsonText(json['instrumentRole'] ?? json['role']),
      meshTag: jsonText(json['meshTag'] ?? json['tagMalha']),
      meshEquipmentType: jsonText(
        json['meshEquipmentType'] ?? json['tipoMalha'],
      ),
      meshManufacturer: jsonText(
        json['meshManufacturer'] ?? json['fabricanteMalha'],
      ),
      meshModel: jsonText(json['meshModel'] ?? json['modeloMalha']),
      meshSerialNumber: jsonText(
        json['meshSerialNumber'] ?? json['nSerieMalha'],
      ),
      meshWorkingPrinciple: jsonText(
        json['meshWorkingPrinciple'] ?? json['principioMalha'],
      ),
    );
  }
}

List<ClientEquipment> flattenClientSystems(
  List<ClientSystem> systems, {
  bool includeMeshes = false,
}) {
  ClientEquipment row(ClientSystem system, ClientInstrument item) {
    return ClientEquipment(
      id: item.id,
      systemType: system.systemType,
      equipmentType: item.typeLabel,
      quantity: 1,
      workingPrinciple: item.workingPrinciple,
      dimensions: item.dimensions,
      manufacturer: item.manufacturer,
      model: item.model,
      serialNumber: item.serialNumber,
      tag: item.tag,
      product: item.product,
      installLocation: system.installLocation,
      systemId: system.id,
      systemTag: system.tag,
      assemblyKind: system.kind.name,
      presetTag: system.assemblyTag,
      presetManufacturer: system.manufacturer,
      presetModel: system.model,
      presetSerial: system.serialNumber,
      instrumentRole: item.role.name,
      meshTag: item.meshTag,
      meshEquipmentType: item.meshEquipmentType,
      meshManufacturer: item.meshManufacturer,
      meshModel: item.meshModel,
      meshSerialNumber: item.meshSerialNumber,
      meshWorkingPrinciple: item.meshWorkingPrinciple,
    );
  }

  return [
    for (final system in systems)
      for (final item in system.selectableInstruments) ...[
        row(system, item),
        if (includeMeshes && item.role == ClientInstrumentRole.pt100)
          ClientEquipment(
            id: '${item.id}-mesh',
            systemType: system.systemType,
            equipmentType: item.meshTypeLabel,
            quantity: 1,
            workingPrinciple: item.meshWorkingPrinciple,
            manufacturer: item.meshManufacturer,
            model: item.meshModel,
            serialNumber: item.meshSerialNumber,
            tag: item.meshTag,
            installLocation: system.installLocation,
            systemId: system.id,
            systemTag: system.tag,
            assemblyKind: system.kind.name,
            presetTag: system.assemblyTag,
            presetManufacturer: system.manufacturer,
            presetModel: system.model,
            presetSerial: system.serialNumber,
            instrumentRole: ClientInstrumentRole.mesh.name,
          ),
      ],
  ];
}

/// Reaproveita ids do cadastro anterior quando a planilha é reimportada.
/// OS e certificados apontam para esses ids; sem isso, exportar e importar
/// de novo solta todos os vínculos e o app passa a adivinhar pela TAG.
List<ClientSystem> keepCatalogIds(
  List<ClientSystem> previous,
  List<ClientSystem> incoming,
) {
  if (previous.isEmpty || incoming.isEmpty) return incoming;
  String norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<String> keysOf(ClientSystem system, ClientInstrument item) {
    final role = item.role.name;
    final serial = norm(item.serialNumber);
    final tag = norm(item.tag);
    final product = norm(item.product);
    final place = norm(system.installLocation);
    final preset = norm(system.assemblyTag);
    return [
      if (serial.isNotEmpty) ...[
        's|$role|$serial|$product|$place|$preset',
        's|$role|$serial|$product|$place',
        's|$role|$serial|$product',
        's|$role|$serial',
      ],
      if (tag.isNotEmpty) ...[
        't|$role|$tag|$product|$place|$preset',
        't|$role|$tag|$place|$preset',
      ],
    ];
  }

  final byKey = <String, List<(String, String)>>{};
  for (final system in previous) {
    for (final item in system.instruments) {
      for (final key in keysOf(system, item)) {
        byKey.putIfAbsent(key, () => []).add((item.id, system.id));
      }
    }
  }

  final usedItems = <String>{};
  final usedSystems = <String>{};
  final out = <ClientSystem>[];
  for (final system in incoming) {
    final votes = <String, int>{};
    final instruments = <ClientInstrument>[];
    for (final item in system.instruments) {
      (String, String)? hit;
      for (final key in keysOf(system, item)) {
        final free = [
          for (final c in byKey[key] ?? const <(String, String)>[])
            if (!usedItems.contains(c.$1)) c,
        ];
        // Chave genérica com mais de um candidato não decide sozinha.
        if (free.length == 1) {
          hit = free.first;
          break;
        }
      }
      if (hit == null) {
        instruments.add(item);
        continue;
      }
      usedItems.add(hit.$1);
      votes[hit.$2] = (votes[hit.$2] ?? 0) + 1;
      instruments.add(item.copyWith(id: hit.$1));
    }
    String? systemId;
    final ranked = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in ranked) {
      if (usedSystems.add(entry.key)) {
        systemId = entry.key;
        break;
      }
    }
    if (systemId == null) {
      final want =
          '${norm(system.systemType)}|${norm(system.installLocation)}|'
          '${norm(system.assemblyTag)}|${norm(system.tag)}';
      final same = [
        for (final old in previous)
          if (!usedSystems.contains(old.id) &&
              '${norm(old.systemType)}|${norm(old.installLocation)}|'
                      '${norm(old.assemblyTag)}|${norm(old.tag)}' ==
                  want)
            old.id,
      ];
      if (same.length == 1) {
        systemId = same.first;
        usedSystems.add(systemId);
      }
    }
    if (systemId != null) {
      final old = previous.firstWhere((s) => s.id == systemId);
      for (var i = 0; i < instruments.length; i++) {
        final item = instruments[i];
        if (usedItems.contains(item.id)) continue;
        final serial = norm(item.serialNumber);
        final tag = norm(item.tag);
        for (final candidate in old.instruments) {
          if (usedItems.contains(candidate.id) ||
              candidate.role != item.role ||
              norm(candidate.serialNumber) != serial ||
              norm(candidate.tag) != tag) {
            continue;
          }
          usedItems.add(candidate.id);
          instruments[i] = item.copyWith(id: candidate.id);
          break;
        }
      }
    }
    out.add(
      system.copyWith(id: systemId ?? system.id, instruments: instruments),
    );
  }
  return out;
}

bool equipmentLooksLikePreset(ClientEquipment item) {
  if (item.presetTag.trim().isNotEmpty ||
      item.presetSerial.trim().isNotEmpty ||
      item.presetManufacturer.trim().isNotEmpty) {
    return true;
  }
  final raw = item.assemblyKind.trim().toLowerCase();
  if (raw.contains('preset')) return true;
  return false;
}

List<ClientSystem> systemsFromEquipment(List<ClientEquipment> items) {
  if (items.isEmpty) return const [];
  final grouped = <String, ClientSystem>{};
  for (final item in items) {
    final preset = equipmentLooksLikePreset(item);
    final sysId = item.systemId.trim();
    final pTag = item.presetTag.trim().toLowerCase();
    final pSerial = item.presetSerial.trim().toLowerCase();
    final sTag = item.systemTag.trim().toLowerCase();

    final groupKey = sysId.isNotEmpty
        ? 'sys:$sysId'
        : (preset && pTag.isNotEmpty
              ? 'ptag:$pTag'
              : (preset && pSerial.isNotEmpty
                    ? 'pser:$pSerial'
                    : (sTag.isNotEmpty ? 'stag:$sTag' : 'eq:${item.id}')));
    final existing = grouped[groupKey];
    final role = item.instrumentRole.trim().isNotEmpty
        ? clientInstrumentRoleFrom(item.instrumentRole)
        : (preset
              ? clientInstrumentRoleFrom(item.equipmentType)
              : ClientInstrumentRole.transmitter);
    if (role == ClientInstrumentRole.mesh) {
      final mesh = ClientInstrument(
        id: item.id.endsWith('-mesh')
            ? item.id.substring(0, item.id.length - 5)
            : item.id,
        role: ClientInstrumentRole.pt100,
        meshTag: item.meshTag.trim().isNotEmpty ? item.meshTag : item.tag,
        meshEquipmentType: item.equipmentType,
        meshManufacturer: item.manufacturer,
        meshModel: item.model,
        meshSerialNumber: item.serialNumber,
        meshWorkingPrinciple: item.workingPrinciple,
      );
      if (existing == null) {
        grouped[groupKey] = ClientSystem(
          id: item.systemId.trim().isNotEmpty
              ? item.systemId
              : 'sys-${item.id}',
          systemType: item.systemType,
          installLocation: item.installLocation,
          tag: item.systemTag,
          kind: item.assemblyKind.trim().isNotEmpty
              ? clientAssemblyKindFrom(item.assemblyKind)
              : (preset
                    ? ClientAssemblyKind.preset
                    : ClientAssemblyKind.transmitter),
          manufacturer: preset
              ? (item.presetManufacturer.trim().isNotEmpty
                    ? item.presetManufacturer
                    : item.manufacturer)
              : item.manufacturer,
          model: preset
              ? (item.presetModel.trim().isNotEmpty
                    ? item.presetModel
                    : item.model)
              : item.model,
          serialNumber: preset ? item.presetSerial : item.serialNumber,
          assemblyTag: preset
              ? (item.presetTag.trim().isNotEmpty ? item.presetTag : '')
              : item.tag,
          instruments: [mesh],
        );
        continue;
      }
      final instruments = [...existing.instruments];
      final index = instruments.indexWhere(
        (current) =>
            current.role == ClientInstrumentRole.pt100 &&
            current.meshTag.trim().isEmpty,
      );
      if (index < 0) {
        instruments.add(mesh);
      } else {
        final previous = instruments[index];
        instruments[index] = previous.copyWith(
          meshTag: mesh.meshTag,
          meshEquipmentType: mesh.meshEquipmentType,
          meshManufacturer: mesh.meshManufacturer,
          meshModel: mesh.meshModel,
          meshSerialNumber: mesh.meshSerialNumber,
          meshWorkingPrinciple: mesh.meshWorkingPrinciple,
        );
      }
      grouped[groupKey] = existing.copyWith(instruments: instruments);
      continue;
    }
    final instrument = ClientInstrument(
      id: item.id,
      role: role,
      equipmentType: item.equipmentType,
      workingPrinciple: item.workingPrinciple,
      dimensions: item.dimensions,
      manufacturer: item.manufacturer,
      model: item.model,
      serialNumber: item.serialNumber,
      tag: item.tag,
      product: item.product,
      meshTag: item.meshTag,
      meshEquipmentType: item.meshEquipmentType,
      meshManufacturer: item.meshManufacturer,
      meshModel: item.meshModel,
      meshSerialNumber: item.meshSerialNumber,
      meshWorkingPrinciple: item.meshWorkingPrinciple,
    );
    if (existing == null) {
      grouped[groupKey] = ClientSystem(
        id: item.systemId.trim().isNotEmpty ? item.systemId : 'sys-${item.id}',
        systemType: item.systemType,
        installLocation: item.installLocation,
        tag: item.systemTag,
        kind: item.assemblyKind.trim().isNotEmpty
            ? clientAssemblyKindFrom(item.assemblyKind)
            : (preset
                  ? ClientAssemblyKind.preset
                  : ClientAssemblyKind.transmitter),
        manufacturer: preset
            ? (item.presetManufacturer.trim().isNotEmpty
                  ? item.presetManufacturer
                  : item.manufacturer)
            : item.manufacturer,
        model: preset
            ? (item.presetModel.trim().isNotEmpty
                  ? item.presetModel
                  : item.model)
            : item.model,
        // N/S do medidor não é N/S do preset (preset sem N/S fica vazio).
        serialNumber: preset ? item.presetSerial : item.serialNumber,
        assemblyTag: preset
            ? (item.presetTag.trim().isNotEmpty ? item.presetTag : '')
            : item.tag,
        instruments: [instrument],
      );
      continue;
    }
    grouped[groupKey] = existing.copyWith(
      instruments: [...existing.instruments, instrument],
    );
  }
  return [
    for (final system in grouped.values)
      () {
        final hasTx = system.transmitters.isNotEmpty;
        final kind =
            (system.hasPreset || system.kind == ClientAssemblyKind.preset) &&
                hasTx
            ? ClientAssemblyKind.presetAndTransmitter
            : system.kind;
        return system
            .copyWith(
              kind: kind,
              meterCount: system.meters.length,
              pt100Count: system.pt100s.length,
              densimeterCount: system.densimeters.length,
            )
            .syncedCounts();
      }(),
  ];
}

List<ClientSystem> mergeClientSystems(
  List<ClientSystem> current,
  List<ClientSystem> incoming,
) {
  final out = [...current];
  for (final system in incoming) {
    var index = system.id.trim().isEmpty
        ? -1
        : out.indexWhere((existing) => existing.id == system.id);
    if (index < 0) {
      index = out.indexWhere((existing) => _sameClientSystem(existing, system));
    }
    if (index < 0) {
      // Só a ilha não identifica o conjunto quando ela tem vários.
      final islandTag = system.tag.trim().toLowerCase();
      final sameIsland = [
        for (var i = 0; i < out.length; i++)
          if (islandTag.isNotEmpty &&
              out[i].tag.trim().toLowerCase() == islandTag)
            i,
      ];
      if (sameIsland.length == 1 &&
          !out[sameIsland.first].isPreset &&
          !system.isPreset) {
        index = sameIsland.first;
      }
    }
    if (index < 0) {
      out.add(system.syncedCounts());
      continue;
    }
    out[index] = _mergeClientSystem(out[index], system);
  }
  return out;
}

bool _sameClientSystem(ClientSystem current, ClientSystem incoming) {
  if (current.id.isNotEmpty && current.id == incoming.id) return true;
  final currentSysTag = current.tag.trim().toLowerCase();
  final incomingSysTag = incoming.tag.trim().toLowerCase();
  // A ilha ("Ilha 1") é comum a vários presets: sozinha não identifica.
  if (currentSysTag.isNotEmpty &&
      incomingSysTag.isNotEmpty &&
      currentSysTag != incomingSysTag) {
    return false;
  }
  if (current.isPreset && incoming.isPreset) {
    final presetTag = incoming.assemblyTag.trim().toLowerCase();
    if (presetTag.isNotEmpty) {
      return current.assemblyTag.trim().toLowerCase() == presetTag;
    }
    final presetSerial = incoming.serialNumber.trim().toLowerCase();
    if (presetSerial.isNotEmpty) {
      return current.serialNumber.trim().toLowerCase() == presetSerial;
    }
    return false;
  }
  if (current.isPreset || incoming.isPreset) return false;
  final incomingInst = incoming.selectableInstruments.isEmpty
      ? null
      : incoming.selectableInstruments.first;
  if (incomingInst == null) return false;
  for (final item in current.selectableInstruments) {
    final serial = incomingInst.serialNumber.trim().toLowerCase();
    final tag = incomingInst.tag.trim().toLowerCase();
    if (serial.isNotEmpty && item.serialNumber.trim().toLowerCase() == serial) {
      return true;
    }
    if (tag.isNotEmpty && item.tag.trim().toLowerCase() == tag) {
      return true;
    }
  }
  return false;
}

ClientSystem _mergeClientSystem(ClientSystem current, ClientSystem incoming) {
  var instruments = [...current.instruments];
  for (final item in incoming.instruments) {
    final index = instruments.indexWhere((existing) {
      if (existing.role != item.role) return false;
      final serial = item.serialNumber.trim().toLowerCase();
      final tag = item.tag.trim().toLowerCase();
      if (serial.isNotEmpty &&
          existing.serialNumber.trim().toLowerCase() == serial) {
        return true;
      }
      if (tag.isNotEmpty && existing.tag.trim().toLowerCase() == tag) {
        return true;
      }
      return existing.id == item.id;
    });
    if (index < 0) {
      instruments = [...instruments, item];
      continue;
    }
    final previous = instruments[index];
    instruments[index] = previous.copyWith(
      role: item.role,
      equipmentType: item.equipmentType.trim().isEmpty
          ? previous.equipmentType
          : item.equipmentType,
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
  return current
      .copyWith(
        systemType: incoming.systemType.trim().isEmpty
            ? current.systemType
            : incoming.systemType,
        installLocation: incoming.installLocation.trim().isEmpty
            ? current.installLocation
            : incoming.installLocation,
        tag: incoming.tag.trim().isEmpty ? current.tag : incoming.tag,
        kind: incoming.kind,
        manufacturer: incoming.manufacturer.trim().isEmpty
            ? current.manufacturer
            : incoming.manufacturer,
        model: incoming.model.trim().isEmpty ? current.model : incoming.model,
        serialNumber: incoming.serialNumber.trim().isEmpty
            ? current.serialNumber
            : incoming.serialNumber,
        assemblyTag: incoming.assemblyTag.trim().isEmpty
            ? current.assemblyTag
            : incoming.assemblyTag,
        instruments: instruments,
      )
      .copyWith(
        meterCount: incoming.isPreset
            ? [
                incoming.meterCount,
                instruments
                    .where((item) => item.role == ClientInstrumentRole.meter)
                    .length,
              ].reduce((a, b) => a > b ? a : b)
            : 0,
        pt100Count: incoming.isPreset
            ? [
                incoming.pt100Count,
                instruments
                    .where((item) => item.role == ClientInstrumentRole.pt100)
                    .length,
              ].reduce((a, b) => a > b ? a : b)
            : 0,
        densimeterCount: incoming.isPreset
            ? [
                incoming.densimeterCount,
                instruments
                    .where(
                      (item) => item.role == ClientInstrumentRole.densimeter,
                    )
                    .length,
              ].reduce((a, b) => a > b ? a : b)
            : 0,
      )
      .syncedCounts();
}

String clientSystemGroupKey(ClientSystem system) {
  final key = [
    system.systemType.trim().toLowerCase(),
    system.installLocation.trim().toLowerCase(),
    system.tag.trim().toLowerCase(),
  ].join('|');
  if (key.replaceAll('|', '').isEmpty) return 'id:${system.id}';
  return key;
}

ClientEquipment _enrichEquipmentFromStored(
  ClientEquipment item,
  List<ClientEquipment> stored,
) {
  ClientEquipment? match;
  for (final existing in stored) {
    if (item.id.isNotEmpty && existing.id == item.id) {
      match = existing;
      break;
    }
    final serial = item.serialNumber.trim().toLowerCase();
    final tag = item.tag.trim().toLowerCase();
    if (serial.isNotEmpty &&
        existing.serialNumber.trim().toLowerCase() == serial) {
      match = existing;
      break;
    }
    if (tag.isNotEmpty && existing.tag.trim().toLowerCase() == tag) {
      match = existing;
      break;
    }
  }
  if (match == null && item.systemId.trim().isNotEmpty) {
    for (final existing in stored) {
      if (existing.systemId == item.systemId &&
          existing.presetWorkingPrinciple.trim().isNotEmpty) {
        match = existing;
        break;
      }
    }
  }
  if (match == null) return item;
  return item.copyWith(
    quantity: match.quantity > 0 ? match.quantity : item.quantity,
    presetWorkingPrinciple: item.presetWorkingPrinciple.trim().isEmpty
        ? match.presetWorkingPrinciple
        : item.presetWorkingPrinciple,
  );
}

class ClientSystemGroup {
  const ClientSystemGroup({
    required this.groupKey,
    required this.systemType,
    required this.installLocation,
    required this.tag,
    required this.assemblies,
  });

  final String groupKey;
  final String systemType;
  final String installLocation;
  final String tag;
  final List<ClientSystem> assemblies;

  String get title {
    if (tag.trim().isNotEmpty) return tag.trim();
    if (systemType.trim().isNotEmpty) return systemType.trim();
    return 'Sistema';
  }

  String get subtitle {
    return [
      if (systemType.trim().isNotEmpty) systemType.trim(),
      if (installLocation.trim().isNotEmpty) installLocation.trim(),
      assemblies.length == 1
          ? clientAssemblyKindLabel(assemblies.first.kind)
          : '${assemblies.length} conjuntos',
    ].join(' · ');
  }
}

List<ClientSystemGroup> groupClientSystems(List<ClientSystem> systems) {
  final order = <String>[];
  final map = <String, List<ClientSystem>>{};
  for (final system in systems) {
    final key = clientSystemGroupKey(system);
    if (!map.containsKey(key)) {
      order.add(key);
      map[key] = [];
    }
    map[key]!.add(system);
  }
  return [
    for (final key in order)
      ClientSystemGroup(
        groupKey: key,
        systemType: map[key]!.first.systemType,
        installLocation: map[key]!.first.installLocation,
        tag: map[key]!.first.tag,
        assemblies: map[key]!,
      ),
  ];
}

/// Valores únicos de tipo de sistema (carregamento, descarga, telemetria…).
List<String> uniqueClientSystemTypes(List<ClientSystem> systems) {
  final order = <String>[];
  final seen = <String>{};
  for (final system in systems) {
    final label = system.systemType.trim();
    if (label.isEmpty) continue;
    final key = label.toLowerCase();
    if (!seen.add(key)) continue;
    order.add(label);
  }
  return order;
}

/// Locais instalados de um tipo de sistema.
List<String> uniqueClientInstallLocations(
  List<ClientSystem> systems, {
  required String systemType,
}) {
  final typeKey = systemType.trim().toLowerCase();
  final order = <String>[];
  final seen = <String>{};
  for (final system in systems) {
    if (typeKey.isNotEmpty &&
        system.systemType.trim().toLowerCase() != typeKey) {
      continue;
    }
    final label = system.installLocation.trim();
    if (label.isEmpty) continue;
    final key = label.toLowerCase();
    if (!seen.add(key)) continue;
    order.add(label);
  }
  return order;
}

List<String> splitClientProducts(String raw) {
  if (raw.trim().isEmpty) return const [];
  final parts = raw.split(RegExp(r'[,;/|\n]+'));
  final list = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    final clean = part.trim();
    if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
      list.add(clean);
      if (list.length >= 8) break;
    }
  }
  return list;
}

/// Instrumentos filtrados por tipo → local → produto (opcional).
List<ClientEquipment> filterClientEquipmentCascade(
  List<ClientSystem> systems, {
  String systemType = '',
  String installLocation = '',
  String product = '',
  bool includeMeshes = false,
}) {
  final typeKey = systemType.trim().toLowerCase();
  final locationKey = installLocation.trim().toLowerCase();
  final productKey = product.trim().toLowerCase();
  final filtered = [
    for (final system in systems)
      if ((typeKey.isEmpty ||
              system.systemType.trim().toLowerCase() == typeKey) &&
          (locationKey.isEmpty ||
              system.installLocation.trim().toLowerCase() == locationKey))
        system,
  ];
  return [
    for (final item in flattenClientSystems(
      filtered,
      includeMeshes: includeMeshes,
    ))
      if (productKey.isEmpty ||
          splitClientProducts(
            item.product,
          ).any((p) => p.toLowerCase() == productKey) ||
          item.product.trim().toLowerCase() == productKey)
        item,
  ];
}

List<String> uniqueClientProducts(List<ClientEquipment> items) {
  final order = <String>[];
  final seen = <String>{};
  for (final item in items) {
    final parts = splitClientProducts(item.product);
    if (parts.isEmpty) {
      final label = item.product.trim();
      if (label.isNotEmpty && seen.add(label.toLowerCase())) {
        order.add(label);
      }
    } else {
      for (final part in parts) {
        if (seen.add(part.toLowerCase())) {
          order.add(part);
        }
      }
    }
  }
  return order;
}

class ClientBaseContact {
  const ClientBaseContact({
    this.name = '',
    this.cargo = '',
    this.email = '',
    this.phone = '',
  });

  final String name;
  final String cargo;
  final String email;
  final String phone;

  bool get hasName => name.trim().isNotEmpty;

  ClientBaseContact copyWith({
    String? name,
    String? cargo,
    String? email,
    String? phone,
  }) {
    return ClientBaseContact(
      name: name ?? this.name,
      cargo: cargo ?? this.cargo,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'cargo': cargo,
    'email': email,
    'phone': phone,
  };

  factory ClientBaseContact.fromJson(Map<String, dynamic> json) {
    return ClientBaseContact(
      name: jsonText(json['name'] ?? json['baseName']),
      cargo: jsonText(json['cargo'] ?? json['baseCargo']),
      email: jsonText(json['email'] ?? json['baseEmail']),
      phone: jsonText(json['phone'] ?? json['basePhone']),
    );
  }
}

/// Até 3 responsáveis da base. Se a lista vier vazia, usa os campos legados.
List<ClientBaseContact> resolveBaseContacts({
  List<ClientBaseContact> contacts = const [],
  String baseName = '',
  String baseCargo = '',
  String baseEmail = '',
  String basePhone = '',
}) {
  final fromList = [
    for (final item in contacts)
      if (item.hasName) item,
  ];
  if (fromList.isNotEmpty) {
    return fromList.take(3).toList(growable: false);
  }
  if (baseName.trim().isEmpty) return const [];
  return [
    ClientBaseContact(
      name: baseName.trim(),
      cargo: baseCargo.trim(),
      email: baseEmail.trim(),
      phone: basePhone.trim(),
    ),
  ];
}

List<ClientBaseContact> readBaseContacts(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        ClientBaseContact.fromJson(Map<String, dynamic>.from(item)),
  ];
}

class SavedClient {
  const SavedClient({
    required this.id,
    required this.name,
    this.requester = '',
    this.cnpj = '',
    this.sites = const [],
    this.cep = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.service = '',
    this.systemType = '',
    this.baseName = '',
    this.baseCargo = '',
    this.baseEmail = '',
    this.basePhone = '',
    this.baseContacts = const [],
    this.systems = const [],
    this.deletedSystemIds = const [],
    List<ClientEquipment> equipment = const [],
    required this.updatedAt,
  }) : _storedEquipment = equipment;

  final String id;
  final String name;
  final String requester;
  final String cnpj;
  final List<String> sites;
  final String cep;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String service;
  final String systemType;
  final String baseName;
  final String baseCargo;
  final String baseEmail;
  final String basePhone;

  /// Até 3 pessoas que podem assinar o RDO pela base.
  final List<ClientBaseContact> baseContacts;
  final List<ClientSystem> systems;

  /// Sistemas apagados deste cadastro. Cópias antigas (nuvem ou outro
  /// aparelho) ainda os têm; sem isso eles voltariam a cada sincronização.
  final List<String> deletedSystemIds;
  final List<ClientEquipment> _storedEquipment;
  final DateTime updatedAt;

  List<ClientEquipment> get storedEquipment => _storedEquipment;

  List<ClientBaseContact> get resolvedBaseContacts => resolveBaseContacts(
    contacts: baseContacts,
    baseName: baseName,
    baseCargo: baseCargo,
    baseEmail: baseEmail,
    basePhone: basePhone,
  );

  List<ClientEquipment> get equipment {
    if (systems.isEmpty) return _storedEquipment;
    final flat = flattenClientSystems(systems);
    // Sistemas “vazios” (ex.: contagens zeradas no sync antigo) não podem
    // esconder o cadastro plano que veio na planilha/nuvem.
    if (flat.isEmpty && _storedEquipment.isNotEmpty) {
      return _storedEquipment;
    }
    if (_storedEquipment.isEmpty) return flat;
    return [
      for (final item in flat)
        _enrichEquipmentFromStored(item, _storedEquipment),
    ];
  }

  List<ClientSystem> get resolvedSystems {
    if (systems.isNotEmpty) {
      final hasInstruments = systems.any(
        (system) => system.instruments.isNotEmpty,
      );
      if (hasInstruments || _storedEquipment.isEmpty) return systems;
      return systemsFromEquipment(_storedEquipment);
    }
    return systemsFromEquipment(_storedEquipment);
  }

  String get cnpjDigits => cnpj.replaceAll(RegExp(r'[^0-9]'), '');

  String get primarySite => sites.isEmpty ? '' : sites.first;

  String get addressLine {
    final streetPart = [
      street.trim(),
      if (number.trim().isNotEmpty) number.trim(),
      if (complement.trim().isNotEmpty) complement.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final cityPart = [
      neighborhood.trim(),
      city.trim(),
      state.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return [
      if (streetPart.isNotEmpty) streetPart,
      if (cityPart.isNotEmpty) cityPart,
      if (cep.trim().isNotEmpty) 'CEP ${cep.trim()}',
    ].join(' — ');
  }

  SavedClient copyWith({
    String? name,
    String? requester,
    String? cnpj,
    List<String>? sites,
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? service,
    String? systemType,
    String? baseName,
    String? baseCargo,
    String? baseEmail,
    String? basePhone,
    List<ClientBaseContact>? baseContacts,
    List<ClientSystem>? systems,
    List<String>? deletedSystemIds,
    List<ClientEquipment>? equipment,
    DateTime? updatedAt,
  }) {
    final nextContacts = baseContacts ?? this.baseContacts;
    final resolved = resolveBaseContacts(
      contacts: nextContacts,
      baseName: baseName ?? this.baseName,
      baseCargo: baseCargo ?? this.baseCargo,
      baseEmail: baseEmail ?? this.baseEmail,
      basePhone: basePhone ?? this.basePhone,
    );
    final primary = resolved.isEmpty ? null : resolved.first;
    return SavedClient(
      id: id,
      name: name ?? this.name,
      requester: requester ?? this.requester,
      cnpj: cnpj ?? this.cnpj,
      sites: sites ?? this.sites,
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      service: service ?? this.service,
      systemType: systemType ?? this.systemType,
      baseName: primary?.name ?? (baseName ?? this.baseName),
      baseCargo: primary?.cargo ?? (baseCargo ?? this.baseCargo),
      baseEmail: primary?.email ?? (baseEmail ?? this.baseEmail),
      basePhone: primary?.phone ?? (basePhone ?? this.basePhone),
      baseContacts: resolved,
      systems: systems ?? this.systems,
      deletedSystemIds: deletedSystemIds ?? this.deletedSystemIds,
      equipment: equipment ?? _storedEquipment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson({bool slim = false}) {
    final contacts = resolvedBaseContacts;
    final primary = contacts.isEmpty ? null : contacts.first;
    final systems = resolvedSystems;
    final systemsHaveGear = systems.any(
      (system) => system.instruments.isNotEmpty,
    );
    return {
      'id': id,
      'name': name,
      'requester': requester,
      'cnpj': cnpj,
      'sites': sites,
      'cep': cep,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'service': service,
      'systemType': systemType,
      'baseName': primary?.name ?? baseName,
      'baseCargo': primary?.cargo ?? baseCargo,
      'baseEmail': primary?.email ?? baseEmail,
      'basePhone': primary?.phone ?? basePhone,
      if (contacts.isNotEmpty)
        'baseContacts': [for (final item in contacts) item.toJson()],
      'systems': [for (final item in systems) item.toJson()],
      'deletedSystemIds': deletedSystemIds,
      // A lista plana repete cada instrumento que já está no sistema.
      // No navegador isso estoura a cota do localStorage na importação.
      if (!slim || !systemsHaveGear)
        'equipment': [for (final item in equipment) item.toJson()],
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedClient.fromJson(Map<String, dynamic> json) {
    final contacts = resolveBaseContacts(
      contacts: readBaseContacts(json['baseContacts']),
      baseName: json['baseName'] as String? ?? '',
      baseCargo: json['baseCargo'] as String? ?? '',
      baseEmail: json['baseEmail'] as String? ?? '',
      basePhone: json['basePhone'] as String? ?? '',
    );
    final primary = contacts.isEmpty ? null : contacts.first;
    return SavedClient(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? json['client'] as String? ?? '',
      requester: jsonText(
        json['requester'] ?? json['solicitante'] ?? json['nomeFantasia'],
      ),
      cnpj: json['cnpj'] as String? ?? '',
      sites: _readSites(json['sites']),
      cep: jsonText(json['cep'] ?? json['zip']),
      street: jsonText(json['street'] ?? json['endereco'] ?? json['address']),
      number: jsonText(json['number'] ?? json['numero']),
      complement: jsonText(json['complement'] ?? json['complemento']),
      neighborhood: jsonText(json['neighborhood'] ?? json['bairro']),
      city: jsonText(json['city'] ?? json['cidade']),
      state: jsonText(json['state'] ?? json['uf'] ?? json['estado']),
      service: json['service'] as String? ?? '',
      systemType: json['systemType'] as String? ?? '',
      baseName: primary?.name ?? (json['baseName'] as String? ?? ''),
      baseCargo: primary?.cargo ?? (json['baseCargo'] as String? ?? ''),
      baseEmail: primary?.email ?? (json['baseEmail'] as String? ?? ''),
      basePhone: primary?.phone ?? (json['basePhone'] as String? ?? ''),
      baseContacts: contacts,
      systems: _readSystems(json['systems']),
      deletedSystemIds: _readStringList(json['deletedSystemIds']),
      equipment: _readEquipment(
        json['equipment'] ?? json['equipments'] ?? json['instrumentos'],
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory SavedClient.fromRdo(RdoData rdo, {String? id}) {
    final contacts = rdo.resolvedBaseContacts;
    final primary = contacts.isEmpty ? null : contacts.first;
    return SavedClient(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: rdo.client.trim(),
      cnpj: rdo.cnpj.trim(),
      sites: const [],
      service: '',
      systemType: '',
      baseName: primary?.name ?? rdo.baseName.trim(),
      baseCargo: primary?.cargo ?? rdo.baseCargo.trim(),
      baseEmail: primary?.email ?? rdo.baseEmail.trim(),
      basePhone: primary?.phone ?? rdo.basePhone.trim(),
      baseContacts: contacts,
      updatedAt: DateTime.now(),
    );
  }
}

List<String> _readSites(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return [
      for (final part in raw.split('|'))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }
  return const [];
}

int _readInt(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse('$raw'.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
}

var _clientIdSeq = 0;

String _clientItemId() {
  _clientIdSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}-$_clientIdSeq';
}

List<ClientSystem> _readSystems(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return _readSystems(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) ClientSystem.fromJson(Map<String, dynamic>.from(item)),
  ];
}

List<ClientEquipment> _readEquipment(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return _readEquipment(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        ClientEquipment.fromJson(Map<String, dynamic>.from(item)),
  ];
}

List<String> _readStringList(dynamic raw, [String? fallback]) {
  if (raw is List) {
    return [
      for (final item in raw)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return [
      for (final item in raw.split(RegExp(r'[,;]')))
        if (item.trim().isNotEmpty) item.trim(),
    ];
  }
  final single = (fallback ?? '').trim();
  return single.isEmpty ? const [] : [single];
}

Map<String, String> _readStringMap(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return _readStringMap(jsonDecode(raw));
    } catch (_) {
      return const {};
    }
  }
  if (raw is! Map) return const {};
  final map = <String, String>{};
  for (final entry in raw.entries) {
    final value = '${entry.value}'.trim();
    if (value.isEmpty) continue;
    final folded = personFirstKey('${entry.key}');
    final key = folded.isNotEmpty
        ? folded
        : '${entry.key}'.trim().toLowerCase();
    if (key.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

String foldPersonKey(String raw) {
  var value = raw.trim().toLowerCase();
  const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  for (var i = 0; i < from.length; i++) {
    value = value.replaceAll(from[i], to[i]);
  }
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String personFirstKey(String name) {
  final folded = foldPersonKey(name);
  if (folded.isEmpty) return '';
  return folded.split(RegExp(r'\s+')).first;
}

/// Login shown and stored for field work. Felipe always uses felps1255;
/// André always uses nascimento, even if an old row still says andre.
String canonicalTechnicianLogin({
  required String login,
  String email = '',
  String name = '',
}) {
  final folded = foldPersonKey(login);
  final mail = email.trim().toLowerCase();
  final local = mail.contains('@') ? mail.split('@').first : mail;
  final foldedName = foldPersonKey(name);
  if (folded == 'felipe') return 'felps1255';
  if (folded == 'nascimento' ||
      folded == 'andre' ||
      folded == 'andrenascimento' ||
      foldedName.contains('nascimento') ||
      local.contains('nascimento') ||
      mail == 'andre@gssolucoestec.com.br') {
    return 'nascimento';
  }
  return login.trim().toLowerCase();
}

String uniquePersonNames(String raw) {
  final parts = [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  final best = <String, String>{};
  final order = <String>[];
  for (final name in parts) {
    final key = personFirstKey(name);
    if (key.isEmpty) continue;
    if (!best.containsKey(key)) {
      order.add(key);
      best[key] = name;
    } else if (name.length > best[key]!.length) {
      best[key] = name;
    }
  }
  return [for (final key in order) best[key]!].join(', ');
}

bool personMatchesAnyId(String raw, Set<String> viewerIds) {
  if (viewerIds.isEmpty) return false;
  final ids = {for (final id in viewerIds) id.trim().toLowerCase()}
    ..removeWhere((id) => id.isEmpty);
  if (ids.isEmpty) return false;

  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return false;
  if (ids.contains(value)) return true;
  if (value.contains('@') && ids.contains(value.split('@').first)) {
    return true;
  }
  final first = personFirstKey(raw);
  if (first.isNotEmpty && ids.contains(first)) return true;
  final folded = foldPersonKey(raw);
  if (folded.isNotEmpty && ids.contains(folded)) return true;
  for (final id in ids) {
    if (id.length >= 3 && folded.contains(id)) return true;
  }
  return false;
}

bool osHasSingleAssignee(SavedOs os) {
  final keys = <String>{};
  for (final email in os.assigneeEmails) {
    final key = personFirstKey(email);
    if (key.isNotEmpty) keys.add(key);
  }
  for (final part in os.technicianName.split(',')) {
    final key = personFirstKey(part);
    if (key.isNotEmpty) keys.add(key);
  }
  return keys.length == 1;
}

Set<String> assignmentIdsFor({
  String email = '',
  String login = '',
  Iterable<String> aliases = const [],
}) {
  final ids = <String>{
    email.trim().toLowerCase(),
    login.trim().toLowerCase(),
    ...aliases.map((item) => item.trim().toLowerCase()),
  };
  if (email.contains('@')) {
    ids.add(email.split('@').first.trim().toLowerCase());
  }
  ids.removeWhere((item) => item.isEmpty);
  return ids;
}

const photoSlotLabels = ['Instrumento', 'Padrão', 'Instalação', 'Lacre'];
const photoSlotCapacity = 4;

String photoSlotStoredLabel(String slot, int index) {
  return index <= 0 ? slot : '$slot · Anexo $index';
}

String photoSlotDisplayLabel(String slot, int index) {
  return index <= 0 ? slot : 'Anexo $index';
}

bool photoBelongsToSlot(String? label, String slot) {
  if (label == null || label.isEmpty) return false;
  return label == slot || label.startsWith('$slot · Anexo ');
}

int photoSlotIndex(String? label, String slot) {
  if (label == slot) return 0;
  final prefix = '$slot · Anexo ';
  if (label != null && label.startsWith(prefix)) {
    return int.tryParse(label.substring(prefix.length)) ?? 1;
  }
  return -1;
}
