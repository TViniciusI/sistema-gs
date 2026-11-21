import { gateGet } from "./gate";

export type CampoCalibration = {
  id: string;
  kind: string;
  number: string;
  clientName: string;
  clientCnpj: string;
  equipmentTag: string;
  equipmentType: string;
  status: string;
  updatedAt: string;
  createdAt: string;
  raw: Record<string, unknown>;
};

export type CampoStandard = {
  id: string;
  name: string;
  type: string;
  serial: string;
  certificate: string;
  validity: string;
  updatedAt: string;
  raw: Record<string, unknown>;
};

export type CampoFluid = {
  id: string;
  name: string;
  density: string;
  viscosity: string;
  temperature: string;
  updatedAt: string;
  raw: Record<string, unknown>;
};

export type CampoStaffDoc = {
  id: string;
  staffEmail: string;
  name: string;
  kind: string;
  createdAt: string;
  requiresSignature: boolean;
  signedAt: string;
  signedBy: string;
  path: string;
  raw: Record<string, unknown>;
};

function text(v: unknown) {
  return String(v ?? "").trim();
}

export async function listCampoCalibrations(): Promise<CampoCalibration[]> {
  const payload = await gateGet({ action: "listcalib" }, { withToken: false });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.calibrations) ? payload.calibrations : [];
  return list
    .map((raw) => {
      if (!raw || typeof raw !== "object") return null;
      const c = raw as Record<string, unknown>;
      const id = text(c.id);
      if (!id) return null;
      return {
        id,
        kind: text(c.kind),
        number: text(c.number) || id,
        clientName: text(c.clientName),
        clientCnpj: text(c.clientCnpj),
        equipmentTag: text(c.equipmentTag),
        equipmentType: text(c.equipmentType),
        status: text(c.status) || text(c.phase) || "—",
        updatedAt: text(c.updatedAt),
        createdAt: text(c.createdAt),
        raw: c,
      } satisfies CampoCalibration;
    })
    .filter(Boolean)
    .sort((a, b) =>
      (b!.updatedAt || b!.createdAt).localeCompare(a!.updatedAt || a!.createdAt),
    ) as CampoCalibration[];
}

export async function listCampoStandards(): Promise<CampoStandard[]> {
  const payload = await gateGet(
    { action: "liststandards" },
    { withToken: false },
  );
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.standards) ? payload.standards : [];
  return list
    .map((raw) => {
      if (!raw || typeof raw !== "object") return null;
      const s = raw as Record<string, unknown>;
      const id = text(s.id);
      if (!id) return null;
      return {
        id,
        name: text(s.name) || id,
        type: text(s.type),
        serial: text(s.serial),
        certificate: text(s.certificate),
        validity: text(s.validity),
        updatedAt: text(s.updatedAt),
        raw: s,
      } satisfies CampoStandard;
    })
    .filter(Boolean) as CampoStandard[];
}

export async function listCampoFluids(): Promise<CampoFluid[]> {
  const payload = await gateGet({ action: "listfluids" }, { withToken: false });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.fluids) ? payload.fluids : [];
  return list
    .map((raw) => {
      if (!raw || typeof raw !== "object") return null;
      const f = raw as Record<string, unknown>;
      const id = text(f.id);
      if (!id) return null;
      return {
        id,
        name: text(f.name) || id,
        density: text(f.density),
        viscosity: text(f.viscosity),
        temperature: text(f.temperature) || text(f.densityRefTemp),
        updatedAt: text(f.updatedAt),
        raw: f,
      } satisfies CampoFluid;
    })
    .filter(Boolean) as CampoFluid[];
}

export async function listCampoStaffDocs(): Promise<CampoStaffDoc[]> {
  const payload = await gateGet(
    { action: "liststaffdocs" },
    { withToken: true },
  );
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.docs) ? payload.docs : [];
  return list
    .map((raw) => {
      if (!raw || typeof raw !== "object") return null;
      const d = raw as Record<string, unknown>;
      const id = text(d.id);
      if (!id) return null;
      return {
        id,
        staffEmail: text(d.staffEmail).toLowerCase(),
        name: text(d.name) || id,
        kind: text(d.kind),
        createdAt: text(d.createdAt),
        requiresSignature: d.requiresSignature === true,
        signedAt: text(d.signedAt),
        signedBy: text(d.signedBy),
        path: text(d.path),
        raw: d,
      } satisfies CampoStaffDoc;
    })
    .filter(Boolean)
    .sort((a, b) =>
      (b!.createdAt || "").localeCompare(a!.createdAt || ""),
    ) as CampoStaffDoc[];
}
