import { digitsOnly, formatCnpj } from "@gs/shared";
import { gateGet, gatePost } from "./gate";
import { parseClient } from "./parse";
import type { CampoClient, CampoClientSystem } from "./types";

export type CampoClientSystemInput = {
  id?: string;
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
  densimeterCount: number;
};

export type CampoClientWriteInput = {
  id?: string;
  name: string;
  cnpj: string;
  requester?: string;
  sites?: string | string[];
  cep?: string;
  street?: string;
  number?: string;
  complement?: string;
  neighborhood?: string;
  city?: string;
  state?: string;
  service?: string;
  systemType?: string;
  baseName?: string;
  baseCargo?: string;
  baseEmail?: string;
  basePhone?: string;
  systems?: CampoClientSystemInput[];
};

function newClientId() {
  return String(Date.now());
}

function newSystemId() {
  return `sys-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function normalizeSites(sites: string | string[] | undefined): string[] {
  if (Array.isArray(sites)) {
    return sites.map((s) => s.trim()).filter(Boolean);
  }
  if (!sites) return [];
  return sites
    .split(/[|,]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function systemToRecord(input: CampoClientSystemInput): Record<string, unknown> {
  return {
    id: input.id?.trim() || newSystemId(),
    systemType: input.systemType.trim(),
    installLocation: input.installLocation.trim(),
    tag: input.tag.trim(),
    kind: input.kind.trim() || "preset",
    manufacturer: input.manufacturer.trim(),
    model: input.model.trim(),
    serialNumber: input.serialNumber.trim(),
    assemblyTag: input.assemblyTag.trim(),
    meterCount: Number(input.meterCount) || 0,
    pt100Count: Number(input.pt100Count) || 0,
    densimeterCount: Number(input.densimeterCount) || 0,
    instruments: [],
  };
}

async function pushClientRecord(
  record: Record<string, unknown>,
): Promise<{ ok: boolean; error?: string; id?: string }> {
  const id = String(record.id || "").trim();
  if (!id) return { ok: false, error: "Cliente sem id." };
  const name = String(record.name || "").trim();
  if (!name) return { ok: false, error: "Informe o nome / razão social." };
  const cnpjDigits = digitsOnly(String(record.cnpj || ""));
  const cnpj = cnpjDigits.length === 14 ? formatCnpj(cnpjDigits) : String(record.cnpj || "");

  const systems = Array.isArray(record.systems) ? record.systems : [];
  const equipment = Array.isArray(record.equipment) ? record.equipment : [];
  const sites = Array.isArray(record.sites)
    ? (record.sites as string[])
    : normalizeSites(String(record.sites || ""));

  const payload: Record<string, unknown> = {
    ...record,
    id,
    name,
    cnpj,
    sites,
    systems,
    equipment,
    updatedAt: String(record.updatedAt || new Date().toISOString()),
  };
  delete payload._fileId;
  delete payload._payloadLight;

  const result = await gatePost({
    action: "saveclient",
    id,
    name,
    cnpj,
    requester: String(payload.requester || ""),
    sites: sites.join("|"),
    cep: String(payload.cep || ""),
    street: String(payload.street || ""),
    number: String(payload.number || ""),
    complement: String(payload.complement || ""),
    neighborhood: String(payload.neighborhood || ""),
    city: String(payload.city || ""),
    state: String(payload.state || ""),
    service: String(payload.service || ""),
    systemType: String(payload.systemType || ""),
    baseName: String(payload.baseName || ""),
    baseCargo: String(payload.baseCargo || ""),
    baseEmail: String(payload.baseEmail || ""),
    basePhone: String(payload.basePhone || ""),
    systems: JSON.stringify(systems),
    equipment: JSON.stringify(equipment),
    payload: JSON.stringify(payload),
    updatedAt: String(payload.updatedAt),
  });

  if (!result || result.ok !== true) {
    return {
      ok: false,
      error: String(result?.error || "Não foi possível salvar na planilha."),
    };
  }
  return { ok: true, id };
}

export async function listCampoClients(): Promise<CampoClient[]> {
  const payload = await gateGet({ action: "listclients" }, { withToken: false });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.clients) ? payload.clients : [];
  return list.map(parseClient).filter(Boolean) as CampoClient[];
}

export async function getCampoClient(id: string): Promise<CampoClient | null> {
  const payload = await gateGet(
    { action: "getclient", id },
    { withToken: false, timeoutMs: 90_000 },
  );
  if (!payload || payload.ok !== true) return null;
  const raw = payload.client ?? (Array.isArray(payload.clients) ? payload.clients[0] : null);
  return parseClient(raw);
}

/** Cria cliente novo na mesma planilha/Drive do GS Campo (`saveclient`). */
export async function createCampoClient(
  input: CampoClientWriteInput,
): Promise<{ ok: boolean; error?: string; id?: string }> {
  const name = input.name.trim();
  if (!name) return { ok: false, error: "Informe o nome / razão social." };
  const cnpjDigits = digitsOnly(input.cnpj || "");
  if (cnpjDigits.length !== 14) {
    return { ok: false, error: "Informe um CNPJ válido com 14 dígitos." };
  }

  const existing = await listCampoClients();
  const duplicate = existing.find(
    (c) => digitsOnly(c.cnpj) === cnpjDigits,
  );
  if (duplicate) {
    return {
      ok: false,
      error: `Já existe cliente com este CNPJ: ${duplicate.name} (abra o cadastro existente).`,
      id: duplicate.id,
    };
  }

  const id = input.id?.trim() || newClientId();
  const systems = (input.systems || []).map(systemToRecord);
  const sites = normalizeSites(input.sites);
  const primaryType =
    input.systemType?.trim() ||
    String(systems[0]?.systemType || "") ||
    "";

  const record: Record<string, unknown> = {
    id,
    name,
    cnpj: formatCnpj(cnpjDigits),
    requester: (input.requester || "").trim(),
    sites,
    cep: digitsOnly(input.cep || "").slice(0, 8),
    street: (input.street || "").trim(),
    number: (input.number || "").trim(),
    complement: (input.complement || "").trim(),
    neighborhood: (input.neighborhood || "").trim(),
    city: (input.city || "").trim(),
    state: (input.state || "").trim().toUpperCase().slice(0, 2),
    service: (input.service || "").trim(),
    systemType: primaryType,
    baseName: (input.baseName || "").trim(),
    baseCargo: (input.baseCargo || "").trim(),
    baseEmail: (input.baseEmail || "").trim(),
    basePhone: (input.basePhone || "").trim(),
    systems,
    equipment: [],
    updatedAt: new Date().toISOString(),
  };

  return pushClientRecord(record);
}

/** Inclui um sistema no cliente e grava na planilha. */
export async function addCampoClientSystem(
  clientId: string,
  system: CampoClientSystemInput,
): Promise<{ ok: boolean; error?: string }> {
  const full = await getCampoClient(clientId);
  if (!full) return { ok: false, error: "Cliente não encontrado." };
  if (full.payloadLight) {
    return {
      ok: false,
      error: "Cadastro incompleto no Drive. Abra de novo e tente outra vez.",
    };
  }
  const nextSystem = systemToRecord(system) as unknown as CampoClientSystem;
  const systems = [...full.systems, nextSystem];
  const nextRaw: Record<string, unknown> = {
    ...full.raw,
    id: full.id,
    name: full.name,
    cnpj: full.cnpj,
    systems,
    equipment: full.equipment,
    updatedAt: new Date().toISOString(),
  };
  const result = await pushClientRecord(nextRaw);
  return { ok: result.ok, error: result.error };
}

/** Remove um sistema/conjunto do cliente e grava na planilha (fonte da verdade). */
export async function deleteCampoClientSystem(
  clientId: string,
  systemId: string,
): Promise<{ ok: boolean; error?: string; client?: CampoClient }> {
  const full = await getCampoClient(clientId);
  if (!full) {
    return { ok: false, error: "Cliente não encontrado na planilha." };
  }
  if (full.payloadLight) {
    return {
      ok: false,
      error: "Cadastro incompleto no Drive. Abra de novo e tente outra vez.",
    };
  }

  const systems = full.systems.filter((s) => s.id !== systemId);
  if (systems.length === full.systems.length) {
    return { ok: false, error: "Sistema já não está no cadastro." };
  }

  const nextRaw: Record<string, unknown> = {
    ...full.raw,
    id: full.id,
    name: full.name,
    cnpj: full.cnpj,
    systems,
    equipment: Array.isArray(full.raw.equipment)
      ? (full.raw.equipment as unknown[]).filter((item) => {
          if (!item || typeof item !== "object") return true;
          const rec = item as Record<string, unknown>;
          return String(rec.systemId ?? "") !== systemId;
        })
      : [],
    updatedAt: new Date().toISOString(),
  };

  const result = await pushClientRecord(nextRaw);
  if (!result.ok) {
    return { ok: false, error: result.error };
  }

  const refreshed = await getCampoClient(clientId);
  return { ok: true, client: refreshed ?? undefined };
}

/** Atualiza dados de contato/base do cliente (mesma planilha do app). */
export async function updateCampoClientFields(input: {
  clientId: string;
  name?: string;
  requester?: string;
  city?: string;
  state?: string;
  baseName?: string;
  baseCargo?: string;
  baseEmail?: string;
  basePhone?: string;
  sites?: string;
}): Promise<{ ok: boolean; error?: string }> {
  const full = await getCampoClient(input.clientId);
  if (!full) return { ok: false, error: "Cliente não encontrado." };
  if (full.payloadLight) {
    return {
      ok: false,
      error: "Cadastro incompleto no Drive. Abra de novo e tente outra vez.",
    };
  }

  const sites =
    input.sites != null
      ? input.sites
          .split(/[|,]/)
          .map((s) => s.trim())
          .filter(Boolean)
      : full.sites;

  const nextRaw: Record<string, unknown> = {
    ...full.raw,
    id: full.id,
    name: input.name?.trim() || full.name,
    cnpj: full.cnpj,
    requester: input.requester?.trim() ?? full.requester,
    city: input.city?.trim() ?? full.city,
    state: input.state?.trim() ?? full.state,
    baseName: input.baseName?.trim() ?? full.baseName,
    baseCargo: input.baseCargo?.trim() ?? full.baseCargo,
    baseEmail: input.baseEmail?.trim() ?? full.baseEmail,
    basePhone: input.basePhone?.trim() ?? full.basePhone,
    sites,
    systems: full.systems,
    equipment: full.equipment,
    updatedAt: new Date().toISOString(),
  };
  delete nextRaw._fileId;
  delete nextRaw._payloadLight;

  const result = await pushClientRecord(nextRaw);
  return { ok: result.ok, error: result.error };
}
