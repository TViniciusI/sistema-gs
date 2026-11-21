import { gateGet } from "./gate";
import { parseUser } from "./parse";
import type { CampoUser } from "./types";

export async function listCampoUsers(): Promise<CampoUser[]> {
  const payload = await gateGet({ action: "users" }, { withToken: true });
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.users) ? payload.users : [];
  return (list.map(parseUser).filter(Boolean) as CampoUser[]).sort((a, b) =>
    a.name.localeCompare(b.name, "pt-BR"),
  );
}
