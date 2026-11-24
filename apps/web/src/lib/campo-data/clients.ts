import { gateGet, gatePost } from "./gate";
import { parseClient } from "./parse";
import type { CampoClient } from "./types";

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
  delete nextRaw._fileId;
  delete nextRaw._payloadLight;

  const result = await gatePost({
    action: "saveclient",
    id: full.id,
    name: full.name,
    cnpj: full.cnpj,
    systems: JSON.stringify(systems),
    equipment: JSON.stringify(nextRaw.equipment ?? []),
    payload: JSON.stringify(nextRaw),
    updatedAt: String(nextRaw.updatedAt),
  });

  if (!result || result.ok !== true) {
    return {
      ok: false,
      error: String(result?.error || "Não foi possível salvar na planilha."),
    };
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

  const result = await gatePost({
    action: "saveclient",
    id: full.id,
    name: String(nextRaw.name),
    cnpj: full.cnpj,
    requester: String(nextRaw.requester || ""),
    city: String(nextRaw.city || ""),
    state: String(nextRaw.state || ""),
    baseName: String(nextRaw.baseName || ""),
    baseCargo: String(nextRaw.baseCargo || ""),
    baseEmail: String(nextRaw.baseEmail || ""),
    basePhone: String(nextRaw.basePhone || ""),
    sites: Array.isArray(sites) ? sites.join("|") : "",
    systems: JSON.stringify(full.systems),
    equipment: JSON.stringify(full.equipment ?? []),
    payload: JSON.stringify(nextRaw),
    updatedAt: String(nextRaw.updatedAt),
  });

  if (!result || result.ok !== true) {
    return {
      ok: false,
      error: String(result?.error || "Não foi possível salvar o cliente."),
    };
  }
  return { ok: true };
}
