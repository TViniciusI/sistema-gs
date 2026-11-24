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

type GateOk = { ok: boolean; error?: string };

async function userGatePost(
  action: string,
  fields: Record<string, string>,
): Promise<GateOk> {
  const payload = await gatePost(
    { action, ...fields },
    { timeoutMs: 45_000 },
  );
  if (!payload) return { ok: false, error: "Sem resposta do gate." };
  if (payload.ok !== true) {
    return {
      ok: false,
      error: String(payload.error || payload.message || `Falha em ${action}.`),
    };
  }
  return { ok: true };
}

/** Aprovar / recusar acesso — mesmo `decide` do app. */
export async function decideCampoUser(input: {
  email?: string;
  login?: string;
  status: "aprovado" | "recusado";
  role?: string;
}): Promise<GateOk> {
  return userGatePost("decide", {
    email: input.email || "",
    login: input.login || "",
    status: input.status,
    role: input.role || "",
  });
}

export async function setCampoUserRole(input: {
  email?: string;
  login?: string;
  role: string;
}): Promise<GateOk> {
  return userGatePost("setpapel", {
    email: input.email || "",
    login: input.login || "",
    role: input.role,
  });
}

export async function setCampoUserActive(input: {
  email?: string;
  login?: string;
  active: boolean;
}): Promise<GateOk> {
  return userGatePost("setativo", {
    email: input.email || "",
    login: input.login || "",
    value: input.active ? "1" : "0",
  });
}

export async function setCampoUserPermissions(input: {
  email?: string;
  login?: string;
  permissions: string;
}): Promise<GateOk> {
  return userGatePost("setpermissoes", {
    email: input.email || "",
    login: input.login || "",
    permissoes: input.permissions,
  });
}

export async function setCampoUserCargo(input: {
  email?: string;
  login?: string;
  cargo: string;
}): Promise<GateOk> {
  return userGatePost("setcargo", {
    email: input.email || "",
    login: input.login || "",
    cargo: input.cargo.slice(0, 80),
  });
}
