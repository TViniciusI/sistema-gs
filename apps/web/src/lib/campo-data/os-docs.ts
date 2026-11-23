import { gateGet } from "./gate";
import type { CampoCalibration } from "./catalog";
import type { CampoOrder } from "./types";

export type OsCalibrationSlotLite = {
  id: string;
  kind: string;
  certificateNumber: string;
  serialNumber: string;
  equipmentTag: string;
  equipmentType: string;
  manufacturer: string;
  model: string;
  installLocation: string;
  labelDate: string;
  jobId: string;
};

export type OsRdoLite = {
  id: string;
  date: string;
  clockIn: string;
  lunchStart: string;
  lunchEnd: string;
  clockOut: string;
  description: string;
  notes: string;
  responsibleName: string;
  signedAt: string;
  clientSignedName: string;
  clientSignedAt: string;
  signed: boolean;
};

export type OsRdoMeta = {
  client: string;
  cnpj: string;
  site: string;
  service: string;
  systemType: string;
  technicianCargo: string;
  baseName: string;
  baseCargo: string;
  baseEmail: string;
  basePhone: string;
  technicianFuncoes: Record<string, string>;
  technicianCargos: Record<string, string>;
};

export const DEFAULT_TECHNICIAN_CARGO =
  "Técnico em Instrumentação Industrial";
export const GS_COMPANY_NAME = "GS SOLUÇÕES LTDA.";
export const GS_COMPANY_CNPJ = "64.949.495/0001-82";

export type OsCertificateRow = {
  slot: OsCalibrationSlotLite;
  job: CampoCalibration | null;
  hasCalibration: boolean;
};

export type CampoPublicCertificate = {
  number: string;
  kind: string;
  kindLabel: string;
  issued: boolean;
  clientName: string;
  site: string;
  serviceRequester: string;
  osNumber: string;
  installLocation: string;
  systemType: string;
  systemTag: string;
  equipmentTag: string;
  equipmentType: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  workingPrinciple: string;
  fluid: string;
  procedure: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  technicianName: string;
  kFactorFound: string;
  kFactorLeft: string;
  standards: Array<{
    tag: string;
    description: string;
    serialNumber: string;
    certificate: string;
    validity: string;
    uncertainty: string;
  }>;
};

function text(value: unknown) {
  return String(value ?? "").trim();
}

export function kindLabel(kind: string) {
  const k = kind.trim().toLowerCase();
  if (k === "volumetric" || k.includes("vazao") || k.includes("vazão")) {
    return "Volumétrica / vazão";
  }
  if (k === "volumetricinverted") return "Volumétrica invertida";
  if (k === "temperature" || (k.includes("temperatura") && !k.includes("malha") && !k.includes("mesh"))) {
    return "Temperatura";
  }
  if (k === "temperaturemesh" || k.includes("malha") || k.includes("mesh")) {
    return "Malha de temperatura";
  }
  if (k === "density" || k.includes("dens")) return "Densidade";
  if (k === "pressure" || k.includes("press")) return "Pressão";
  if (k === "conductivity" || k.includes("condut")) return "Condutividade";
  if (k === "telemetry" || k.includes("telemetr")) return "Telemetria";
  return kind || "Calibração";
}

/** Ordem igual ao app (CalibrationKind.values). */
const KIND_ORDER = [
  "volumetric",
  "volumetricInverted",
  "temperature",
  "temperatureMesh",
  "density",
  "pressure",
  "conductivity",
  "telemetry",
];

function kindSortKey(kind: string) {
  const idx = KIND_ORDER.indexOf(kind.trim());
  return idx >= 0 ? idx : 100 + kind.length;
}

export function parseOsCalibrationSlots(
  os: CampoOrder,
): OsCalibrationSlotLite[] {
  const raw = Array.isArray(os.raw.calibrationSlots)
    ? os.raw.calibrationSlots
    : [];
  return raw
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const s = item as Record<string, unknown>;
      const id = text(s.id);
      if (!id) return null;
      return {
        id,
        kind: text(s.kind),
        certificateNumber: text(s.certificateNumber || s.number),
        serialNumber: text(s.serialNumber),
        equipmentTag: text(s.equipmentTag),
        equipmentType: text(s.equipmentType),
        manufacturer: text(s.manufacturer),
        model: text(s.model),
        installLocation: text(s.installLocation),
        labelDate: text(s.labelDate),
        jobId: text(s.jobId),
      } satisfies OsCalibrationSlotLite;
    })
    .filter(Boolean) as OsCalibrationSlotLite[];
}

function asStringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const out: Record<string, string> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    const k = text(key).toLowerCase();
    const v = text(raw);
    if (k && v) out[k] = v;
  }
  return out;
}

export function parseOsRdoMeta(os: CampoOrder): OsRdoMeta {
  const rdo =
    os.raw.rdo && typeof os.raw.rdo === "object"
      ? (os.raw.rdo as Record<string, unknown>)
      : {};
  return {
    client: text(rdo.client) || os.clientName,
    cnpj: text(rdo.cnpj),
    site: text(rdo.site) || [rdo.city, rdo.state].filter(Boolean).join("/"),
    service: text(rdo.service),
    systemType: text(rdo.systemType),
    technicianCargo: text(rdo.technicianCargo) || DEFAULT_TECHNICIAN_CARGO,
    baseName: text(rdo.baseName),
    baseCargo: text(rdo.baseCargo),
    baseEmail: text(rdo.baseEmail),
    basePhone: text(rdo.basePhone),
    technicianFuncoes: asStringMap(rdo.technicianFuncoes),
    technicianCargos: asStringMap(rdo.technicianCargos),
  };
}

export function parseOsRdos(os: CampoOrder): OsRdoLite[] {
  const raw = Array.isArray(os.raw.rdos) ? os.raw.rdos : [];
  return raw.map((item, index) => {
    if (!item || typeof item !== "object") {
      return {
        id: `rdo-${index}`,
        date: "",
        clockIn: "",
        lunchStart: "",
        lunchEnd: "",
        clockOut: "",
        description: "Registro de campo",
        notes: "",
        responsibleName: "",
        signedAt: "",
        clientSignedName: "",
        clientSignedAt: "",
        signed: false,
      };
    }
    const r = item as Record<string, unknown>;
    return {
      id: text(r.id) || `rdo-${index}`,
      date: text(r.date || r.day),
      clockIn: text(r.clockIn),
      lunchStart: text(r.lunchStart),
      lunchEnd: text(r.lunchEnd),
      clockOut: text(r.clockOut),
      description: text(r.description) || text(r.obs) || "",
      notes: text(r.notes),
      responsibleName: text(r.responsibleName),
      signedAt: text(r.signedAt),
      clientSignedName: text(r.clientSignedName),
      clientSignedAt: text(r.clientSignedAt),
      signed: r.signed === true || Boolean(text(r.responsibleName)),
    };
  });
}

/** Primeira palavra do nome, normalizada — chave das maps do app. */
export function personFirstKey(name: string) {
  return text(name)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .split(/\s+/)[0] || "";
}

export function splitTeamNames(raw: string) {
  const parts = raw
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);
  const seen = new Set<string>();
  const out: string[] = [];
  for (const name of parts) {
    const key = personFirstKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(name);
  }
  return out;
}

export function teamWithLead(names: string[], responsibleName: string) {
  const lead = text(responsibleName);
  if (!lead) return names.length ? names : ["-"];
  const leadKey = personFirstKey(lead);
  const rest = names.filter((n) => personFirstKey(n) !== leadKey);
  return [lead, ...rest];
}

export function formatRdoDate(raw: string) {
  const value = text(raw);
  if (!value) return "";
  const dmy = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(value);
  if (dmy) {
    return `${dmy[1].padStart(2, "0")}/${dmy[2].padStart(2, "0")}/${dmy[3]}`;
  }
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}

export function formatRdoSignedAt(raw: string, fallbackDate?: string) {
  const value = text(raw) || text(fallbackDate);
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  const date = d.toLocaleString("pt-BR", {
    timeZone: "America/Sao_Paulo",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  // pt-BR locale often yields "dd/mm/yyyy, HH:mm:ss"
  return `${date.replace(",", "")} -03:00`;
}

function jobBelongsToOs(
  job: CampoCalibration,
  os: CampoOrder,
  slotId?: string,
) {
  const wantId = os.id.trim();
  const wantNum = os.number.trim().toLowerCase();
  const jOsId = text(job.raw.osId);
  const jOsNum = text(job.raw.osNumber).toLowerCase();
  const jSlot = text(job.raw.calibrationSlotId);

  if (wantId && jOsId && jOsId !== wantId) return false;
  if (wantNum && jOsNum && jOsNum !== wantNum) return false;

  if ((wantId || wantNum) && !jOsId && !jOsNum) {
    return Boolean(slotId && jSlot === slotId);
  }
  return true;
}

/** Liga slot da OS ao job da planilha — mesma lógica do GS Campo. */
export function jobForSlot(
  slot: OsCalibrationSlotLite,
  os: CampoOrder,
  jobs: CampoCalibration[],
): CampoCalibration | null {
  if (slot.jobId) {
    const byId = jobs.find((j) => j.id === slot.jobId);
    if (byId && jobBelongsToOs(byId, os, slot.id)) return byId;
    // Stub leve sem osId: confia no jobId gravado no slot.
    if (byId) return byId;
  }

  const number = slot.certificateNumber.toLowerCase();
  if (!number) return null;

  for (const job of jobs) {
    if (job.number.toLowerCase() !== number) continue;
    if (jobBelongsToOs(job, os, slot.id)) return job;
    // Stub leve: se o número está nesta OS e bate, aceita.
    if (!text(job.raw.osId) && !text(job.raw.osNumber)) return job;
  }
  return null;
}

export function certificatesForOs(
  os: CampoOrder,
  all: CampoCalibration[],
): OsCertificateRow[] {
  const slots = parseOsCalibrationSlots(os);
  return slots.map((slot) => {
    const job = jobForSlot(slot, os, all);
    return {
      slot,
      job,
      hasCalibration: Boolean(job),
    };
  });
}

export function calibrationsForOs(
  os: CampoOrder,
  all: CampoCalibration[],
): CampoCalibration[] {
  const rows = certificatesForOs(os, all);
  const byId = new Map<string, CampoCalibration>();
  for (const row of rows) {
    if (row.job) byId.set(row.job.id, row.job);
  }
  // Jobs da planilha ligados à OS mesmo sem slot (legado).
  for (const job of all) {
    if (byId.has(job.id)) continue;
    const osId = text(job.raw.osId);
    const osNumber = text(job.raw.osNumber);
    if (osId === os.id || (osNumber && osNumber === os.number)) {
      byId.set(job.id, job);
    }
  }
  return [...byId.values()];
}

export function groupSlotsByKind(slots: OsCalibrationSlotLite[]) {
  const map = new Map<string, OsCalibrationSlotLite[]>();
  for (const slot of slots) {
    const key = slot.kind || "other";
    const list = map.get(key) ?? [];
    list.push(slot);
    map.set(key, list);
  }
  return [...map.entries()]
    .sort((a, b) => kindSortKey(a[0]) - kindSortKey(b[0]))
    .map(([kind, items]) => ({
      kind,
      label: kindLabel(kind),
      items,
    }));
}

export function groupCertificatesByKind(rows: OsCertificateRow[]) {
  const map = new Map<string, OsCertificateRow[]>();
  for (const row of rows) {
    const key = row.slot.kind || "other";
    const list = map.get(key) ?? [];
    list.push(row);
    map.set(key, list);
  }
  return [...map.entries()]
    .sort((a, b) => kindSortKey(a[0]) - kindSortKey(b[0]))
    .map(([kind, items]) => {
      const withJob = items.filter((r) => r.hasCalibration).length;
      const orphan = items.length - withJob;
      return {
        kind,
        label: kindLabel(kind),
        items,
        withJob,
        orphan,
        stats: [
          `${items.length} certificado(s)`,
          withJob > 0 ? `${withJob} com calibração` : null,
          orphan > 0 ? `${orphan} sem calibração` : null,
        ]
          .filter(Boolean)
          .join(" · "),
      };
    });
}

/**
 * Link da consulta pública do adesivo.
 * Nunca usa id do slot — só id do job (planilha) ou número + OS.
 */
export function publicCertUrl(input: {
  number?: string;
  jobId?: string;
  osId?: string;
  campoBase?: string;
}) {
  const base =
    input.campoBase?.replace(/\/$/, "") ||
    process.env.NEXT_PUBLIC_CAMPO_URL?.trim() ||
    "https://gs-campo.netlify.app";
  const params = new URLSearchParams();
  const number = text(input.number);
  const jobId = text(input.jobId);
  const osId = text(input.osId);
  if (number) params.set("n", number);
  if (jobId) params.set("id", jobId);
  if (osId) params.set("os", osId);
  // Sem jobId e sem (número+os) o gate responde incompleto / não encontrado.
  if (!jobId && !(number && osId)) return `${base}/c`;
  return `${base}/c?${params.toString()}`;
}

export function campoAppUrl() {
  return (
    process.env.NEXT_PUBLIC_CAMPO_URL?.trim() || "https://gs-campo.netlify.app"
  );
}

export async function getCampoPublicCertificate(input: {
  number?: string;
  jobId?: string;
  osId?: string;
}): Promise<CampoPublicCertificate | null> {
  const number = text(input.number);
  const jobId = text(input.jobId);
  const osId = text(input.osId);
  if (!jobId && !(number && osId)) return null;

  const params: Record<string, string> = { action: "certpublic" };
  if (number) params.n = number;
  if (jobId) params.id = jobId;
  if (osId) params.osId = osId;

  const payload = await gateGet(params, { withToken: false, timeoutMs: 45_000 });
  if (!payload || payload.ok !== true) return null;
  const c = payload.certificate;
  if (!c || typeof c !== "object") return null;
  const rec = c as Record<string, unknown>;
  const standardsRaw = Array.isArray(rec.standards) ? rec.standards : [];
  return {
    number: text(rec.number),
    kind: text(rec.kind),
    kindLabel: text(rec.kindLabel) || kindLabel(text(rec.kind)),
    issued: rec.issued === true,
    clientName: text(rec.clientName),
    site: text(rec.site),
    serviceRequester: text(rec.serviceRequester),
    osNumber: text(rec.osNumber),
    installLocation: text(rec.installLocation),
    systemType: text(rec.systemType),
    systemTag: text(rec.systemTag),
    equipmentTag: text(rec.equipmentTag),
    equipmentType: text(rec.equipmentType),
    manufacturer: text(rec.manufacturer),
    model: text(rec.model),
    serialNumber: text(rec.serialNumber),
    workingPrinciple: text(rec.workingPrinciple),
    fluid: text(rec.fluid),
    procedure: text(rec.procedure),
    calibrationDate: text(rec.calibrationDate),
    nextCalibrationDate: text(rec.nextCalibrationDate),
    technicianName: text(rec.technicianName),
    kFactorFound: text(rec.kFactorFound),
    kFactorLeft: text(rec.kFactorLeft),
    standards: standardsRaw
      .map((item) => {
        if (!item || typeof item !== "object") return null;
        const s = item as Record<string, unknown>;
        return {
          tag: text(s.tag),
          description: text(s.description),
          serialNumber: text(s.serialNumber),
          certificate: text(s.certificate),
          validity: text(s.validity),
          uncertainty: text(s.uncertainty),
        };
      })
      .filter(Boolean) as CampoPublicCertificate["standards"],
  };
}
