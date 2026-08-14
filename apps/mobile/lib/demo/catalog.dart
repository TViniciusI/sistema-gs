class DemoWorkOrder {
  const DemoWorkOrder({
    required this.id,
    required this.number,
    required this.client,
    required this.cnpj,
    required this.site,
    required this.city,
    required this.date,
    required this.service,
    required this.status,
    required this.team,
    required this.oc,
    required this.gps,
    required this.description,
    required this.photos,
    required this.signer,
    required this.canAttachCertificate,
    this.instrument = '',
    this.tag = '',
    this.principle = '',
    this.standard = '',
    this.clockIn = '08:05',
    this.lunchStart = '12:00',
    this.lunchEnd = '13:00',
    this.clockOut = '17:40',
  });

  final String id;
  final String number;
  final String client;
  final String cnpj;
  final String site;
  final String city;
  final String date;
  final String service;
  final String status;
  final String team;
  final String oc;
  final String gps;
  final String description;
  final List<String> photos;
  final String signer;
  final bool canAttachCertificate;
  final String instrument;
  final String tag;
  final String principle;
  final String standard;
  final String clockIn;
  final String lunchStart;
  final String lunchEnd;
  final String clockOut;
}

class FieldCertificate {
  const FieldCertificate({
    required this.number,
    required this.workOrderId,
    required this.workOrderNumber,
    required this.client,
    required this.instrument,
    required this.issuedAt,
    required this.sentToOffice,
    this.fileName,
    this.fileBytes,
    this.contentType,
  });

  final String number;
  final String workOrderId;
  final String workOrderNumber;
  final String client;
  final String instrument;
  final String issuedAt;
  final bool sentToOffice;
  final String? fileName;
  final List<int>? fileBytes;
  final String? contentType;
}

const demoTechnician = 'Felipe Souza';

const demoWorkOrders = [
  DemoWorkOrder(
    id: 'os-036',
    number: 'GS 036/26',
    client: 'ALESAT Combustíveis S.A.',
    cnpj: '02.345.678/0001-90',
    site: 'Laje 1 · SKID 01',
    city: 'Betim/MG',
    date: '12/08/2026',
    service: 'Calibração · descarregamento',
    status: 'Em atendimento',
    team: 'Cleber (responsável), Felipe e André',
    oc: '03900/26 / 04457/26',
    gps: '-19.9681, -44.1974',
    description:
        'Montagem do padrão GS 001 e verificação de 4 pontos no Coriolis FT-01.',
    photos: ['FT-01', 'Padrão', 'Preset', 'Lacre'],
    signer: 'Renata Campos',
    canAttachCertificate: true,
    instrument: 'Medidor Coriolis Yokogawa · FT-01',
    tag: 'SKID 01',
    principle: 'Coriolis',
    standard: 'Padrão GS 001 · certificado RBC',
  ),
  DemoWorkOrder(
    id: 'os-037',
    number: 'GS 037/26',
    client: 'Terminal de Combustíveis de Belém Ltda.',
    cnpj: '08.112.233/0001-55',
    site: 'Tanques · telemetria',
    city: 'Belém/PA',
    date: '14/08/2026',
    service: 'Comissionamento · telemetria',
    status: 'Agendada',
    team: 'Cleber Guimarães',
    oc: '04002/26',
    gps: '-1.4558, -48.4902',
    description: 'Start-up do sistema de telemetria de tanques.',
    photos: ['Tanque', 'Display', 'Antena', 'Painel'],
    signer: 'Carla Souza',
    canAttachCertificate: false,
    clockIn: '09:10',
    lunchStart: '12:00',
    lunchEnd: '13:00',
    clockOut: '16:20',
  ),
  DemoWorkOrder(
    id: 'os-038',
    number: 'GS 038/26',
    client: 'ALESAT Combustíveis S.A.',
    cnpj: '02.345.678/0001-90',
    site: 'Laje 1 · SKID 02',
    city: 'Betim/MG',
    date: '20/08/2026',
    service: 'Calibração · carregamento',
    status: 'Atribuída',
    team: 'André (responsável) e Felipe',
    oc: '04110/26',
    gps: '-19.9681, -44.1974',
    description: 'Calibração do SKID 02 — carregamento top.',
    photos: ['SKID 02', 'Medidor', 'Padrão', 'Lacre'],
    signer: 'Renata Campos',
    canAttachCertificate: true,
    instrument: 'Medidor Coriolis · FT-02',
    tag: 'SKID 02',
    principle: 'Coriolis',
    standard: 'Padrão GS 001 · certificado RBC',
  ),
];
