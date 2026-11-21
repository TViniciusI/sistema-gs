export type CampoClientSystem = {
  id: string;
  systemType: string;
  installLocation: string;
  tag: string;
  kind: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  assemblyTag: string;
  meterCount: number;
  pt100Count: number;
  meshCount: number;
  densimeterCount: number;
  instruments?: unknown[];
};

export type CampoClient = {
  id: string;
  name: string;
  cnpj: string;
  requester: string;
  city: string;
  state: string;
  baseName: string;
  baseEmail: string;
  basePhone: string;
  baseCargo: string;
  updatedAt: string;
  systems: CampoClientSystem[];
  equipment: unknown[];
  sites: string[];
  payloadLight: boolean;
  fileId: string;
  raw: Record<string, unknown>;
};

export type CampoOrder = {
  id: string;
  number: string;
  status: string;
  clientName: string;
  technicianName: string;
  startsAt: string;
  updatedAt: string;
  rdoCount: number;
  fileCount: number;
  payloadLight: boolean;
  raw: Record<string, unknown>;
};

export type CampoUser = {
  email: string;
  login: string;
  name: string;
  phone: string;
  role: string;
  status: string;
  active: boolean;
  permissions: string;
  cargo: string;
  funcao: string;
};

export type CampoDriveStatus = {
  ok: boolean;
  ownerEmail?: string;
  folderName?: string;
  folderUrl?: string;
  wrongOwner?: boolean;
  error?: string;
  raw: Record<string, unknown>;
};
