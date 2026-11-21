import type {
  CampoClient,
  CampoClientSystem,
  CampoDriveStatus,
  CampoOrder,
  CampoUser,
} from "./types";

function text(value: unknown): string {
  return String(value ?? "").trim();
}

function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

export function parseClientSystem(raw: unknown): CampoClientSystem | null {
  const s = asRecord(raw);
  if (!s) return null;
  const id = text(s.id);
  if (!id) return null;
  return {
    id,
    systemType: text(s.systemType),
    installLocation: text(s.installLocation),
    tag: text(s.tag),
    kind: text(s.kind) || "preset",
    manufacturer: text(s.manufacturer),
    model: text(s.model),
    serialNumber: text(s.serialNumber),
    assemblyTag: text(s.assemblyTag),
    meterCount: num(s.meterCount),
    pt100Count: num(s.pt100Count),
    meshCount: num(s.meshCount),
    densimeterCount: num(s.densimeterCount),
    instruments: Array.isArray(s.instruments) ? s.instruments : [],
  };
}

export function parseClient(raw: unknown): CampoClient | null {
  const c = asRecord(raw);
  if (!c) return null;
  const id = text(c.id);
  if (!id) return null;
  const systems = Array.isArray(c.systems)
    ? c.systems.map(parseClientSystem).filter(Boolean)
    : [];
  const sitesRaw = c.sites;
  const sites =
    typeof sitesRaw === "string"
      ? sitesRaw.split("|").map((s) => s.trim()).filter(Boolean)
      : Array.isArray(sitesRaw)
        ? sitesRaw.map((s) => text(s)).filter(Boolean)
        : [];
  return {
    id,
    name: text(c.name) || text(c.legalName) || id,
    cnpj: text(c.cnpj),
    requester: text(c.requester),
    city: text(c.city),
    state: text(c.state),
    baseName: text(c.baseName),
    baseEmail: text(c.baseEmail),
    basePhone: text(c.basePhone),
    baseCargo: text(c.baseCargo),
    updatedAt: text(c.updatedAt),
    systems: systems as CampoClientSystem[],
    equipment: Array.isArray(c.equipment) ? c.equipment : [],
    sites,
    payloadLight: c._payloadLight === true,
    fileId: text(c._fileId),
    raw: c,
  };
}

export function parseOrder(raw: unknown): CampoOrder | null {
  const o = asRecord(raw);
  if (!o) return null;
  const id = text(o.id);
  if (!id) return null;
  const rdo = asRecord(o.rdo);
  const clientName =
    text(o.clientName) ||
    text(rdo?.client) ||
    text(rdo?.clientName) ||
    text(rdo?.empresa) ||
    "";
  const rdos = Array.isArray(o.rdos) ? o.rdos : [];
  const files = Array.isArray(o.files) ? o.files : [];
  return {
    id,
    number: text(o.number) || id,
    status: text(o.status) || "—",
    clientName,
    technicianName: text(o.technicianName),
    startsAt: text(o.startsAt) || text(o.createdAt),
    updatedAt: text(o.updatedAt),
    rdoCount: rdos.length,
    fileCount: files.length,
    payloadLight: o._payloadLight === true,
    raw: o,
  };
}

export function parseUser(raw: unknown): CampoUser | null {
  const u = asRecord(raw);
  if (!u) return null;
  const login = text(u.login).toLowerCase();
  const email = text(u.email).toLowerCase();
  if (!login && !email) return null;
  return {
    email,
    login,
    name: text(u.name) || login || email,
    phone: text(u.phone),
    role: text(u.role) || "tecnico",
    status: text(u.status) || "aprovado",
    active: u.active === true || u.ativo === true || u.active === "sim",
    permissions: text(u.permissoes) || text(u.permissions) || "geral",
    cargo: text(u.cargo),
    funcao: text(u.funcao),
  };
}

export function parseDriveStatus(raw: Record<string, unknown>): CampoDriveStatus {
  return {
    ok: raw.ok === true || raw.connected === true,
    ownerEmail:
      text(raw.folderOwnerEmail) ||
      text(raw.account) ||
      text(raw.ownerEmail) ||
      text(raw.email) ||
      undefined,
    folderName: text(raw.folderName) || text(raw.name) || "Pasta das OS",
    folderUrl: text(raw.folderUrl) || text(raw.url) || undefined,
    wrongOwner: raw.wrongOwner === true,
    error: text(raw.error) || text(raw.warning) || undefined,
    raw,
  };
}
