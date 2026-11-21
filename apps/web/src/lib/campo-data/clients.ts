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
