import { bumpCampoCache, cachedList, CAMPO_TAGS } from "./cache";
import { gateGet, gatePost } from "./gate";

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

function parseCalibration(raw: unknown): CampoCalibration | null {
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
  };
}

export const listCampoCalibrations = cachedList(
  "listCampoCalibrations",
  [CAMPO_TAGS.calibrations],
  async (): Promise<CampoCalibration[]> => {
    const payload = await gateGet(
      { action: "listcalib" },
      { withToken: false, timeoutMs: 45_000 },
    );
    if (!payload || payload.ok !== true) return [];
    const list = Array.isArray(payload.calibrations) ? payload.calibrations : [];
    return list
      .map(parseCalibration)
      .filter(Boolean)
      .sort((a, b) =>
        (b!.updatedAt || b!.createdAt).localeCompare(
          a!.updatedAt || a!.createdAt,
        ),
      ) as CampoCalibration[];
  },
);

/** Lê uma calibração completa (forceFull no gate). Fallback: lista leve. */
export async function getCampoCalibration(
  idOrNumber: string,
): Promise<CampoCalibration | null> {
  const key = text(idOrNumber);
  if (!key) return null;
  const payload = await gateGet(
    { action: "getcalib", id: key, n: key },
    { withToken: false, timeoutMs: 60_000 },
  );
  if (payload?.ok === true && payload.calibration) {
    return parseCalibration(payload.calibration);
  }
  // Só cai na lista (cacheada) se o gate não negou explicitamente.
  const err = text(payload?.error).toLowerCase();
  if (err.includes("não encontr") || err.includes("nao encontr") || err.includes("not found")) {
    return null;
  }
  const all = await listCampoCalibrations();
  return (
    all.find((item) => item.id === key) ||
    all.find((item) => item.number.toLowerCase() === key.toLowerCase()) ||
    null
  );
}

/** Grava job completo na planilha (mesma action `savecalib` do app). */
export async function saveCampoCalibration(input: {
  id?: string;
  number?: string;
  kind?: string;
  clientName?: string;
  payload: Record<string, unknown>;
}): Promise<{ ok: boolean; error?: string; id?: string; skipped?: boolean }> {
  const payload = { ...input.payload };
  const id = text(input.id) || text(payload.id) || `calib-${Date.now()}`;
  const number = text(input.number) || text(payload.number);
  const kind = text(input.kind) || text(payload.kind) || "volumetric";
  const clientName = text(input.clientName) || text(payload.clientName);
  const updatedAt = new Date().toISOString();

  payload.id = id;
  payload.number = number;
  payload.kind = kind;
  payload.clientName = clientName;
  payload.updatedAt = updatedAt;
  if (!payload.createdAt) payload.createdAt = updatedAt;

  const result = await gatePost(
    {
      action: "savecalib",
      id,
      number,
      kind,
      clientName,
      payload: JSON.stringify(payload),
      updatedAt,
    },
    { timeoutMs: 90_000 },
  );

  if (!result || result.ok !== true) {
    return {
      ok: false,
      error: String(result?.error || "Não foi possível salvar a calibração."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.calibrations);

  if (result.skipped === true) {
    return {
      ok: false,
      id,
      skipped: true,
      error: String(
        result.reason ||
          "Planilha preservou versão mais forte (não sobrescreveu).",
      ),
    };
  }
  return { ok: true, id };
}

export function newCalibrationId() {
  return `calib-${Date.now()}`;
}

export const listCampoStandards = cachedList(
  "listCampoStandards",
  [CAMPO_TAGS.standards],
  async (): Promise<CampoStandard[]> => {
    const payload = await gateGet(
      { action: "liststandards" },
      { withToken: false, timeoutMs: 45_000 },
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
  },
);

export const listCampoFluids = cachedList(
  "listCampoFluids",
  [CAMPO_TAGS.fluids],
  async (): Promise<CampoFluid[]> => {
    const payload = await gateGet(
      { action: "listfluids" },
      { withToken: false, timeoutMs: 45_000 },
    );
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
  },
);

export async function saveCampoStandard(fields: {
  id?: string;
  name: string;
  type?: string;
  serial?: string;
  certificate?: string;
  validity?: string;
  uncertainty?: string;
  coverageK?: string;
}): Promise<{ ok: boolean; error?: string; id?: string }> {
  const id = text(fields.id) || `std-${Date.now()}`;
  const payload = await gatePost(
    {
      action: "savestandard",
      id,
      name: text(fields.name),
      type: text(fields.type) || "Outro",
      serial: text(fields.serial),
      certificate: text(fields.certificate),
      validity: text(fields.validity),
      uncertainty: text(fields.uncertainty),
      coverageK: text(fields.coverageK),
      updatedAt: new Date().toISOString(),
    },
    { timeoutMs: 60_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao salvar padrão."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.standards);
  return { ok: true, id };
}

export async function deleteCampoStandard(
  id: string,
): Promise<{ ok: boolean; error?: string }> {
  const payload = await gatePost(
    { action: "deletestandard", id: text(id) },
    { timeoutMs: 45_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao apagar padrão."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.standards);
  return { ok: true };
}

export async function saveCampoFluid(fields: {
  id?: string;
  name: string;
  densityMin?: string;
  densityMax?: string;
  viscosityMin?: string;
  viscosityMax?: string;
  densityRefTemp?: string;
  viscosityRefTemp?: string;
}): Promise<{ ok: boolean; error?: string; id?: string }> {
  const id = text(fields.id) || `fluid-${Date.now()}`;
  const payload = await gatePost(
    {
      action: "savefluid",
      id,
      name: text(fields.name),
      densityMin: text(fields.densityMin),
      densityMax: text(fields.densityMax),
      viscosityMin: text(fields.viscosityMin),
      viscosityMax: text(fields.viscosityMax),
      densityRefTemp: text(fields.densityRefTemp) || "20 °C",
      viscosityRefTemp: text(fields.viscosityRefTemp) || "40 °C",
      updatedAt: new Date().toISOString(),
    },
    { timeoutMs: 60_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao salvar fluido."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.fluids);
  return { ok: true, id };
}

export async function deleteCampoFluid(
  id: string,
): Promise<{ ok: boolean; error?: string }> {
  const payload = await gatePost(
    { action: "deletefluid", id: text(id) },
    { timeoutMs: 45_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao apagar fluido."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.fluids);
  return { ok: true };
}

export async function signCampoStaffDoc(input: {
  id: string;
  signedBy: string;
}): Promise<{ ok: boolean; error?: string }> {
  const payload = await gatePost(
    {
      action: "signstaffdoc",
      id: text(input.id),
      signedBy: text(input.signedBy),
      signedAt: new Date().toISOString(),
    },
    { timeoutMs: 60_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao assinar documento."),
    };
  }
  return { ok: true };
}

function parseStaffDoc(raw: unknown): CampoStaffDoc | null {
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
    requiresSignature:
      d.requiresSignature === true ||
      String(d.requiresSignature || "").toLowerCase() === "sim",
    signedAt: text(d.signedAt),
    signedBy: text(d.signedBy),
    path: text(d.path) || text(d.fileId),
    raw: d,
  };
}

export async function listCampoStaffDocs(
  staffEmail?: string,
): Promise<CampoStaffDoc[]> {
  const email = text(staffEmail).toLowerCase();
  const params: Record<string, string> = { action: "liststaffdocs" };
  if (email) params.staffEmail = email;
  const payload = await gateGet(params, {
    withToken: true,
    timeoutMs: 45_000,
  });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.docs) ? payload.docs : [];
  return list
    .map(parseStaffDoc)
    .filter(Boolean)
    .sort((a, b) =>
      (b!.createdAt || "").localeCompare(a!.createdAt || ""),
    ) as CampoStaffDoc[];
}

function guessMime(fileName: string) {
  const n = fileName.toLowerCase();
  if (n.endsWith(".pdf")) return "application/pdf";
  if (n.endsWith(".png")) return "image/png";
  if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "image/jpeg";
  if (n.endsWith(".webp")) return "image/webp";
  if (n.endsWith(".heic")) return "image/heic";
  return "application/octet-stream";
}

/** Anexa holerite / foto / registro no mesmo fluxo do GS Campo (`savestaffdoc`). */
export async function saveCampoStaffDoc(input: {
  id?: string;
  staffEmail: string;
  name: string;
  kind?: string;
  requiresSignature?: boolean;
  mime?: string;
  /** Base64 sem prefixo data: */
  data: string;
}): Promise<{ ok: boolean; error?: string; id?: string }> {
  const staffEmail = text(input.staffEmail).toLowerCase();
  const name = text(input.name);
  const data = text(input.data);
  if (!staffEmail) return { ok: false, error: "Informe o e-mail do funcionário." };
  if (!name) return { ok: false, error: "Informe o nome do arquivo." };
  if (!data) return { ok: false, error: "Arquivo vazio." };
  const id = text(input.id) || `staffdoc-${Date.now()}`;
  const kind = text(input.kind) || "anexo";
  const payload = await gatePost(
    {
      action: "savestaffdoc",
      id,
      staffEmail,
      name,
      kind,
      requiresSignature: input.requiresSignature ? "sim" : "nao",
      createdAt: new Date().toISOString(),
      mime: text(input.mime) || guessMime(name),
      data,
    },
    { timeoutMs: 120_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao enviar documento RH."),
    };
  }
  return { ok: true, id: text(payload.id) || id };
}

export async function deleteCampoStaffDoc(
  id: string,
): Promise<{ ok: boolean; error?: string }> {
  const payload = await gatePost(
    { action: "deletestaffdoc", id: text(id) },
    { timeoutMs: 45_000 },
  );
  if (!payload || payload.ok !== true) {
    return {
      ok: false,
      error: String(payload?.error || "Falha ao apagar documento."),
    };
  }
  return { ok: true };
}
