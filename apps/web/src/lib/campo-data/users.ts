import { gateGet, gatePost } from "./gate";
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

/** Aprovar / recusar acesso — mesmo `decide` do app. */
export async function decideCampoUser(input: {
  email?: string;
  login?: string;
  status: "aprovado" | "recusado";
  role?: string;
}): Promise<{ ok: boolean; error?: string }> {
  const payload = await gatePost(
    {
      action: "decide",
      email: input.email || "",
      login: input.login || "",
      status: input.status,
      role: input.role || "",
    },
    { timeoutMs: 45_000 },
  );
  if (!payload) {
    return { ok: false, error: "Sem resposta do gate." };
  }
  if (payload.ok !== true) {
    return {
      ok: false,
      error: String(payload.error || payload.message || "Falha ao decidir."),
    };
  }
  return { ok: true };
}
