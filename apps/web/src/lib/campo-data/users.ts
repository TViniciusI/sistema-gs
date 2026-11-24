import {
  parseCampoGateUser,
  passwordHash,
  passwordHashCandidates,
} from "@/lib/campo-auth";
import type { CampoGateUser } from "@/lib/campo-auth";
import { bumpCampoCache, cachedList, CAMPO_TAGS } from "./cache";
import { gateGet, gatePost } from "./gate";
import { parseUser } from "./parse";
import type { CampoUser } from "./types";

export const listCampoUsers = cachedList(
  "listCampoUsers",
  [CAMPO_TAGS.users],
  async (): Promise<CampoUser[]> => {
    const payload = await gateGet(
      { action: "users" },
      { withToken: true, timeoutMs: 45_000 },
    );
    if (!payload || payload.ok !== true) return [];
    const list = Array.isArray(payload.users) ? payload.users : [];
    return (list.map(parseUser).filter(Boolean) as CampoUser[]).sort((a, b) =>
      a.name.localeCompare(b.name, "pt-BR"),
    );
  },
);

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
  bumpCampoCache(CAMPO_TAGS.users);
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

type AccountOk =
  | { ok: true; user: CampoGateUser }
  | { ok: false; error: string; wrongPassword?: boolean };

async function accountGatePost(
  action: string,
  fields: Record<string, string>,
): Promise<AccountOk> {
  const payload = await gatePost(
    { action, cmd: action, ...fields },
    { timeoutMs: 45_000 },
  );
  if (!payload) return { ok: false, error: "Sem resposta do gate." };
  if (payload.ok !== true) {
    return {
      ok: false,
      error: String(payload.error || payload.message || `Falha em ${action}.`),
      wrongPassword: payload.wrongPassword === true,
    };
  }
  const user = parseCampoGateUser(payload.user);
  if (!user) {
    return { ok: false, error: "Resposta do gate sem usuário." };
  }
  return { ok: true, user };
}

/** Atualiza nome/login/e-mail/telefone — mesmo `setperfil` do app. */
export async function updateCampoProfile(input: {
  email: string;
  login: string;
  password: string;
  name: string;
  newLogin: string;
  newEmail: string;
  phone: string;
}): Promise<AccountOk> {
  const login = input.login.trim().toLowerCase();
  const email = input.email.trim().toLowerCase();
  const newLogin = input.newLogin.trim().toLowerCase();
  const hashes = passwordHashCandidates({
    password: input.password,
    login,
    email,
  });
  return accountGatePost("setperfil", {
    email,
    login,
    passHash: passwordHash(login, input.password),
    passHashes: hashes.join(","),
    name: input.name.trim(),
    newLogin,
    newEmail: input.newEmail.trim().toLowerCase(),
    phone: input.phone.trim(),
    newPassHash: input.password
      ? passwordHash(newLogin, input.password)
      : "",
  });
}

/** Troca senha — mesmo `setsenha` do app. */
export async function changeCampoPassword(input: {
  email: string;
  login: string;
  currentPassword: string;
  newPassword: string;
}): Promise<AccountOk> {
  const login = input.login.trim().toLowerCase();
  const email = input.email.trim().toLowerCase();
  const hashes = passwordHashCandidates({
    password: input.currentPassword,
    login,
    email,
  });
  return accountGatePost("setsenha", {
    email,
    login,
    passHash: passwordHash(login, input.currentPassword),
    passHashes: hashes.join(","),
    newLogin: login,
    newPassHash: passwordHash(login, input.newPassword),
  });
}
