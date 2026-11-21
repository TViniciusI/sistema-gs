import { gateGet } from "./gate";
import { parseOrder } from "./parse";
import type { CampoOrder } from "./types";

export async function listCampoOrders(): Promise<CampoOrder[]> {
  const payload = await gateGet({ action: "listos" }, { withToken: false });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.orders) ? payload.orders : [];
  return (list.map(parseOrder).filter(Boolean) as CampoOrder[]).sort((a, b) =>
    b.number.localeCompare(a.number, "pt-BR"),
  );
}

export async function getCampoOrder(id: string): Promise<CampoOrder | null> {
  const payload = await gateGet(
    { action: "getos", id },
    { withToken: false, timeoutMs: 90_000 },
  );
  if (!payload || payload.ok !== true) return null;
  const raw = payload.order ?? (Array.isArray(payload.orders) ? payload.orders[0] : null);
  return parseOrder(raw);
}
