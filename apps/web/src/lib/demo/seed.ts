import type {
  ServiceType,
  SystemType,
  TechnicianFunction,
  WorkOrderStatus,
} from "@gs/shared";

export type DemoClient = {
  id: string;
  code: number;
  alias: string;
  legalName: string;
  cnpj: string;
  requester: { name: string; title: string; phone: string; email: string };
  manager: { name: string; title: string; phone: string; email: string };
};

export type DemoLocation = {
  id: string;
  clientId: string;
  alias: string;
  address: string;
  city: string;
  state: string;
};

export type DemoEmployee = {
  id: string;
  technicianId?: string;
  name: string;
  title: string;
  phone: string;
  field: boolean;
};

export type DemoWorkOrder = {
  id: string;
  number: number;
  year: number;
  purchaseOrder: string;
  clientId: string;
  locationId: string;
  serviceType: ServiceType;
  systemType: SystemType;
  status: WorkOrderStatus;
  scheduledDate: string;
  notes: string;
  team: { technicianId: string; function: TechnicianFunction; owner: boolean }[];
  events: { type: string; at: string; detail: string; lat?: number; lng?: number }[];
  timeEntries: {
    id: string;
    technicianId: string;
    date: string;
    clockIn: string;
    lunchStart: string;
    lunchEnd: string;
    clockOut: string;
    description: string;
  }[];
  photos: { id: string; caption: string }[];
  signature?: { name: string; role: string; at: string };
};

export type DemoCertificate = {
  id: string;
  number: string;
  workOrderId: string;
  issuedAt: string;
  nextDue: string;
  instrument: string;
  tag: string;
  principle: string;
  standard: string;
  signer: string;
  source?: "office" | "field";
  fileName?: string;
  contentType?: string;
  fileBase64?: string;
};

export type DemoEquipment = {
  id: string;
  locationId: string;
  tag: string;
  systemType: SystemType;
  instruments: { tag: string; kind: string; manufacturer: string; serial: string }[];
};

export type DemoStandard = {
  id: string;
  code: string;
  description: string;
  lab: string;
  cert: string;
  expiresAt: string;
  status: "ok" | "due" | "expired";
};

export type DemoState = {
  clients: DemoClient[];
  locations: DemoLocation[];
  employees: DemoEmployee[];
  workOrders: DemoWorkOrder[];
  certificates: DemoCertificate[];
  equipment: DemoEquipment[];
  standards: DemoStandard[];
};

export function createSeed(): DemoState {
  return {
    clients: [
      {
        id: "cli-alesat",
        code: 19,
        alias: "ALESAT/MG",
        legalName: "ALESAT Combustíveis S.A.",
        cnpj: "02345678000190",
        requester: {
          name: "Marcos Oliveira",
          title: "Coordenador de Medição",
          phone: "(31) 98812-4400",
          email: "marcos.oliveira@alesat.example",
        },
        manager: {
          name: "Renata Campos",
          title: "Responsável da base",
          phone: "(31) 3344-2100",
          email: "renata.campos@alesat.example",
        },
      },
      {
        id: "cli-atem",
        code: 7,
        alias: "ATEM/RO",
        legalName: "ATEM's Distribuidora de Petróleo S.A.",
        cnpj: "04567890000111",
        requester: {
          name: "Paulo Henrique",
          title: "Supervisor de Terminal",
          phone: "(69) 99210-3311",
          email: "paulo.henrique@atem.example",
        },
        manager: {
          name: "Luciana Freitas",
          title: "Responsável da base",
          phone: "(69) 3212-0900",
          email: "luciana.freitas@atem.example",
        },
      },
      {
        id: "cli-belem",
        code: 3,
        alias: "TERMINAL BELÉM",
        legalName: "Terminal de Combustíveis de Belém Ltda.",
        cnpj: "08112233000155",
        requester: {
          name: "João Batista",
          title: "Engenheiro de Processos",
          phone: "(91) 98100-2200",
          email: "joao.batista@terminalbelem.example",
        },
        manager: {
          name: "Carla Souza",
          title: "Responsável da base",
          phone: "(91) 3225-4400",
          email: "carla.souza@terminalbelem.example",
        },
      },
    ],
    locations: [
      {
        id: "loc-alesat-laje1",
        clientId: "cli-alesat",
        alias: "Laje 1",
        address: "Rodovia BR-381, km 12 — Base ALESAT",
        city: "Betim",
        state: "MG",
      },
      {
        id: "loc-atem-pvh",
        clientId: "cli-atem",
        alias: "Porto Velho",
        address: "Av. dos Combustíveis, 450 — Terminal",
        city: "Porto Velho",
        state: "RO",
      },
      {
        id: "loc-belem",
        clientId: "cli-belem",
        alias: "Ilha de Outeiro",
        address: "Estrada do Outeiro, s/n — Terminal",
        city: "Belém",
        state: "PA",
      },
    ],
    employees: [
      {
        id: "emp-cleber",
        technicianId: "tec-cleber",
        name: "Cleber Guimarães",
        title: "Técnico em Instrumentação Industrial",
        phone: "(91) 99900-1100",
        field: true,
      },
      {
        id: "emp-felipe",
        technicianId: "tec-felipe",
        name: "Felipe Souza",
        title: "Técnico em Instrumentação Industrial",
        phone: "(91) 98877-2200",
        field: true,
      },
      {
        id: "emp-andre",
        technicianId: "tec-andre",
        name: "Andre Nascimento",
        title: "Técnico em Instrumentação Industrial",
        phone: "(91) 98765-3300",
        field: true,
      },
      {
        id: "emp-marina",
        name: "Marina Costa",
        title: "Assistente administrativa",
        phone: "(91) 3222-1000",
        field: false,
      },
    ],
    workOrders: [
      {
        id: "os-036",
        number: 36,
        year: 2026,
        purchaseOrder: "Nº 03900/26 / Nº 04457/26",
        clientId: "cli-alesat",
        locationId: "loc-alesat-laje1",
        serviceType: "calibracao",
        systemType: "descarregamento",
        status: "in_progress",
        scheduledDate: "2026-08-12",
        notes: "Calibração volumétrica no SKID 01 — Laje 1.",
        team: [
          { technicianId: "tec-cleber", function: "responsavel_tecnico", owner: true },
          { technicianId: "tec-felipe", function: "suporte_tecnico", owner: false },
          { technicianId: "tec-andre", function: "suporte_tecnico", owner: false },
        ],
        events: [
          { type: "OS criada", at: "2026-08-03T08:00:00-03:00", detail: "Numerada GS 036/26" },
          { type: "Equipe atribuída", at: "2026-08-03T08:10:00-03:00", detail: "Cleber, Felipe e André" },
          { type: "Aceita no app", at: "2026-08-12T06:40:00-03:00", detail: "Cleber Guimarães", lat: -19.967, lng: -44.198 },
          { type: "Deslocamento iniciado", at: "2026-08-12T06:45:00-03:00", detail: "Saída Belém → Betim/MG" },
          { type: "Chegada no local", at: "2026-08-12T07:52:00-03:00", detail: "Laje 1 · ALESAT/MG", lat: -19.9681, lng: -44.1974 },
          { type: "Atendimento iniciado", at: "2026-08-12T08:05:00-03:00", detail: "Abertura do SKID 01" },
        ],
        timeEntries: [
          {
            id: "te-036-1",
            technicianId: "tec-cleber",
            date: "2026-08-12",
            clockIn: "08:05",
            lunchStart: "12:00",
            lunchEnd: "13:00",
            clockOut: "17:40",
            description:
              "Montagem da unidade padrão GS 001, verificação de 4 pontos de vazão no medidor Coriolis FT-01 e conferência do preset Fusion4.",
          },
        ],
        photos: [
          { id: "ph1", caption: "Tag FT-01 no skid" },
          { id: "ph2", caption: "Padrão GS 001 conectado" },
          { id: "ph3", caption: "Display do preset Fusion4" },
          { id: "ph4", caption: "Lacre do medidor" },
        ],
        signature: {
          name: "Renata Campos",
          role: "Responsável da base",
          at: "2026-08-12T17:35:00-03:00",
        },
      },
      {
        id: "os-035",
        number: 35,
        year: 2026,
        purchaseOrder: "OC 03812/26",
        clientId: "cli-atem",
        locationId: "loc-atem-pvh",
        serviceType: "manutencao",
        systemType: "carregamento",
        status: "completed",
        scheduledDate: "2026-07-28",
        notes: "Manutenção corretiva em válvula de controle digital.",
        team: [
          { technicianId: "tec-felipe", function: "responsavel_tecnico", owner: true },
          { technicianId: "tec-andre", function: "suporte_tecnico", owner: false },
        ],
        events: [
          { type: "OS criada", at: "2026-07-20T09:00:00-03:00", detail: "GS 035/26" },
          { type: "Concluída", at: "2026-07-28T16:20:00-03:00", detail: "Assinatura coletada" },
        ],
        timeEntries: [
          {
            id: "te-035-1",
            technicianId: "tec-felipe",
            date: "2026-07-28",
            clockIn: "07:30",
            lunchStart: "11:30",
            lunchEnd: "12:30",
            clockOut: "16:20",
            description: "Substituição do atuador e teste de intertravamento no braço de carregamento.",
          },
        ],
        photos: [
          { id: "ph5", caption: "Válvula antes da manutenção" },
          { id: "ph6", caption: "Atuador instalado" },
        ],
        signature: {
          name: "Luciana Freitas",
          role: "Responsável da base",
          at: "2026-07-28T16:15:00-03:00",
        },
      },
      {
        id: "os-037",
        number: 37,
        year: 2026,
        purchaseOrder: "OC 04002/26",
        clientId: "cli-belem",
        locationId: "loc-belem",
        serviceType: "comissionamento",
        systemType: "telemetria",
        status: "scheduled",
        scheduledDate: "2026-08-14",
        notes: "Start-up do sistema de telemetria de tanques.",
        team: [
          { technicianId: "tec-cleber", function: "responsavel_tecnico", owner: true },
        ],
        events: [
          { type: "OS criada", at: "2026-08-10T11:00:00-03:00", detail: "Agendada para 14/08" },
          { type: "Equipe atribuída", at: "2026-08-10T11:05:00-03:00", detail: "Cleber Guimarães" },
        ],
        timeEntries: [],
        photos: [],
      },
      {
        id: "os-038",
        number: 38,
        year: 2026,
        purchaseOrder: "OC 04110/26",
        clientId: "cli-alesat",
        locationId: "loc-alesat-laje1",
        serviceType: "calibracao",
        systemType: "carregamento",
        status: "assigned",
        scheduledDate: "2026-08-20",
        notes: "Calibração do SKID 02 — carregamento top.",
        team: [
          { technicianId: "tec-andre", function: "responsavel_tecnico", owner: true },
          { technicianId: "tec-felipe", function: "suporte_tecnico", owner: false },
        ],
        events: [
          { type: "OS criada", at: "2026-08-11T14:00:00-03:00", detail: "GS 038/26" },
        ],
        timeEntries: [],
        photos: [],
      },
      {
        id: "os-034",
        number: 34,
        year: 2026,
        purchaseOrder: "OC 03701/26",
        clientId: "cli-alesat",
        locationId: "loc-alesat-laje1",
        serviceType: "calibracao",
        systemType: "carregamento",
        status: "reviewed",
        scheduledDate: "2026-07-18",
        notes: "Certificado 2303126 emitido.",
        team: [
          { technicianId: "tec-cleber", function: "responsavel_tecnico", owner: true },
        ],
        events: [
          { type: "Concluída", at: "2026-07-18T17:00:00-03:00", detail: "Campo encerrado" },
          { type: "Certificado emitido", at: "2026-07-18T18:10:00-03:00", detail: "Nº 2303126" },
        ],
        timeEntries: [],
        photos: [{ id: "ph7", caption: "Skid 01 após calibração" }],
        signature: {
          name: "Renata Campos",
          role: "Responsável da base",
          at: "2026-07-18T16:50:00-03:00",
        },
      },
    ],
    certificates: [
      {
        id: "cert-2303126",
        number: "2303126",
        workOrderId: "os-034",
        issuedAt: "2026-07-18",
        nextDue: "2027-07-18",
        instrument: "Medidor Coriolis Yokogawa · FT-01",
        tag: "SKID 01",
        principle: "Coriolis",
        standard: "GS 001 · ACCI/SP · V28012-1A",
        signer: "Cleber Barbosa Guimarães",
        source: "office",
      },
    ],
    equipment: [
      {
        id: "eq-skid01",
        locationId: "loc-alesat-laje1",
        tag: "SKID 01",
        systemType: "carregamento",
        instruments: [
          {
            tag: "FT-01",
            kind: "Medidor Coriolis",
            manufacturer: "Yokogawa",
            serial: "D11200553",
          },
          {
            tag: "FIT-01",
            kind: "Transmissor",
            manufacturer: "Yokogawa",
            serial: "D112005553",
          },
          {
            tag: "PRESET-01",
            kind: "Preset eletrônico",
            manufacturer: "Honeywell Enraf Fusion4 MSC",
            serial: "5230496",
          },
        ],
      },
      {
        id: "eq-skid-belem",
        locationId: "loc-belem",
        tag: "TANQUE TK-04",
        systemType: "telemetria",
        instruments: [
          {
            tag: "LT-04",
            kind: "Medidor de nível",
            manufacturer: "Endress+Hauser",
            serial: "EH-90421",
          },
        ],
      },
    ],
    standards: [
      {
        id: "std-gs001",
        code: "GS 001",
        description: "Medidor Coriolis (master meter)",
        lab: "ACCI/SP",
        cert: "V28012-1A",
        expiresAt: "2027-09-15",
        status: "ok",
      },
      {
        id: "std-mm001",
        code: "MM-001",
        description: "Medida de volume 5000 L top-loading",
        lab: "IPEM/AM",
        cert: "008/2025",
        expiresAt: "2026-09-10",
        status: "due",
      },
      {
        id: "std-mm003",
        code: "MM-003",
        description: "Medida de volume 5000 L top-loading",
        lab: "IPEM/AM",
        cert: "010/2026",
        expiresAt: "2027-04-27",
        status: "ok",
      },
    ],
  };
}

export const DEMO_PROFILE = {
  id: "user-demo",
  organization_id: "org-gs",
  email: "cleber@gssolucoestec.com.br",
  full_name: "Cleber Guimarães",
  role: "admin" as const,
  is_active: true,
};
