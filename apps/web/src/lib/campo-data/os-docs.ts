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
  description: string;
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
  if (k === "temperature" || k.includes("temperatura")) return "Temperatura";
  if (k === "temperaturemesh" || k.includes("malha")) {
    return "Malha de temperatura";
  }
  if (k === "density" || k.includes("dens")) return "Densidade";
  if (k === "pressure" || k.includes("press")) return "Pressão";
  if (k === "conductivity" || k.includes("condut")) return "Condutividade";
  if (k === "telemetry" || k.includes("telemetr")) return "Telemetria";
  return kind || "Calibração";
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

export function parseOsRdos(os: CampoOrder): OsRdoLite[] {
  const raw = Array.isArray(os.raw.rdos) ? os.raw.rdos : [];
  return raw
    .map((item, index) => {
      if (!item || typeof item !== "object") {
        return {
          id: `rdo-${index}`,
          date: "",
          description: "Registro de campo",
        };
      }
      const r = item as Record<string, unknown>;
      return {
        id: text(r.id) || `rdo-${index}`,
        date: text(r.date || r.day),
        description:
          text(r.description) || text(r.obs) || "Registro de campo",
      };
    });
}

export function calibrationsForOs(
  os: CampoOrder,
  all: CampoCalibration[],
): CampoCalibration[] {
  const slots = parseOsCalibrationSlots(os);
  const slotNumbers = new Set(
    slots
      .map((s) => s.certificateNumber.toLowerCase())
      .filter(Boolean),
  );
  const slotJobIds = new Set(slots.map((s) => s.jobId).filter(Boolean));

  return all.filter((item) => {
    const raw = item.raw;
    const osId = text(raw.osId);
    const osNumber = text(raw.osNumber);
    if (osId && osId === os.id) return true;
    if (osNumber && osNumber === os.number) return true;
    if (slotJobIds.has(item.id)) return true;
    if (item.number && slotNumbers.has(item.number.toLowerCase())) return true;
    return false;
  });
}

export function groupSlotsByKind(slots: OsCalibrationSlotLite[]) {
  const map = new Map<string, OsCalibrationSlotLite[]>();
  for (const slot of slots) {
    const key = kindLabel(slot.kind);
    const list = map.get(key) ?? [];
    list.push(slot);
    map.set(key, list);
  }
  return [...map.entries()].map(([label, items]) => ({ label, items }));
}

export function publicCertUrl(input: {
  number?: string;
  id?: string;
  osId?: string;
  campoBase?: string;
}) {
  const base =
    input.campoBase?.replace(/\/$/, "") ||
    process.env.NEXT_PUBLIC_CAMPO_URL?.trim() ||
    "https://gs-campo.netlify.app";
  const params = new URLSearchParams();
  if (input.number) params.set("n", input.number);
  if (input.id) params.set("id", input.id);
  if (input.osId) params.set("os", input.osId);
  const query = params.toString();
  return `${base}/c${query ? `?${query}` : ""}`;
}

export function campoAppUrl() {
  return (
    process.env.NEXT_PUBLIC_CAMPO_URL?.trim() || "https://gs-campo.netlify.app"
  );
}
