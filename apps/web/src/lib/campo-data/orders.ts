import { bumpCampoCache, cachedList, CAMPO_TAGS } from "./cache";
import { gateGet, gatePost } from "./gate";
import { isOfficeHiddenOrder } from "./office-filters";
import { parseOrder } from "./parse";
import type { CampoOrder } from "./types";

export const listCampoOrders = cachedList(
  "listCampoOrders",
  [CAMPO_TAGS.orders],
  async (): Promise<CampoOrder[]> => {
    const payload = await gateGet(
      { action: "listos" },
      { withToken: false, timeoutMs: 45_000 },
    );
    if (!payload || payload.ok !== true) return [];
    const list = Array.isArray(payload.orders) ? payload.orders : [];
    return (list.map(parseOrder).filter(Boolean) as CampoOrder[])
      .filter((os) => !isOfficeHiddenOrder(os))
      .sort((a, b) => b.number.localeCompare(a.number, "pt-BR"));
  },
);

export async function getCampoOrder(id: string): Promise<CampoOrder | null> {
  const payload = await gateGet(
    { action: "getos", id },
    { withToken: false, timeoutMs: 90_000 },
  );
  if (!payload || payload.ok !== true) return null;
  const raw =
    payload.order ?? (Array.isArray(payload.orders) ? payload.orders[0] : null);
  const os = parseOrder(raw);
  if (!os || isOfficeHiddenOrder(os)) return null;
  return os;
}

/** Mesmo contrato do app: `action=saveos` com campos flat. */
export async function saveCampoOrder(
  fields: Record<string, string>,
): Promise<{ ok: boolean; error?: string; id?: string }> {
  const id = String(fields.id || "").trim();
  if (!id) return { ok: false, error: "ID da OS ausente." };
  const payload = await gatePost(
    { action: "saveos", ...fields },
    { timeoutMs: 90_000 },
  );
  if (!payload) {
    return { ok: false, error: "Sem resposta do gate (rede/Apps Script)." };
  }
  if (payload.ok !== true) {
    return {
      ok: false,
      error: String(payload.error || payload.message || "Falha ao salvar OS."),
    };
  }
  bumpCampoCache(CAMPO_TAGS.orders);
  return { ok: true, id };
}
