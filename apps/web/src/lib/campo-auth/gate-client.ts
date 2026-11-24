import { appBuild, loginGateUrl } from "./config";
import { passwordHash, passwordHashCandidates } from "./password";
import type { CampoGateUser, CampoLoginResult } from "./types";

export function parseCampoGateUser(raw: unknown): CampoGateUser | null {
  if (!raw || typeof raw !== "object") return null;
  const u = raw as Record<string, unknown>;
  const email = String(u.email ?? "").trim().toLowerCase();
  const login = String(u.login ?? "").trim().toLowerCase();
  if (!email && !login) return null;
  return {
    email,
    name: String(u.name ?? u.nome ?? "").trim(),
    login,
    phone: String(u.phone ?? u.telefone ?? "").trim(),
    role: String(u.role ?? u.papel ?? "tecnico").trim().toLowerCase(),
    status: String(u.status ?? "aprovado").trim().toLowerCase(),
    active: u.active === true || u.ativo === true || u.active === "sim",
    funcao: String(u.funcao ?? "").trim(),
    cargo: String(u.cargo ?? "").trim(),
    calibracao: String(u.calibracao ?? "").trim(),
    permissoes: String(u.permissoes ?? u.permissions ?? "geral").trim(),
    jornada: String(u.jornada ?? "").trim(),
  };
}

function asUser(raw: unknown): CampoGateUser | null {
  return parseCampoGateUser(raw);
}

async function gateGet(
  params: Record<string, string>,
  timeoutMs = 45_000,
): Promise<Record<string, unknown> | null> {
  const base = loginGateUrl();
  if (!base) return null;
  const url = new URL(base);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }
  url.searchParams.set("appBuild", appBuild());

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url.toString(), {
      method: "GET",
      redirect: "follow",
      cache: "no-store",
      signal: controller.signal,
      headers: { Accept: "application/json, text/plain, */*" },
    });
    const text = (await res.text()).trim();
    if (!text || text.startsWith("<")) return null;
    const parsed = JSON.parse(text) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export async function loginWithCampoGate(
  loginOrEmail: string,
  password: string,
): Promise<CampoLoginResult> {
  const login = loginOrEmail.trim();
  if (!login) {
    return { ok: false, error: "Informe o usuário ou e-mail." };
  }
  if (!password) {
    return { ok: false, error: "Informe a senha." };
  }

  const emailHint = login.includes("@") ? login : "";
  const hashes = passwordHashCandidates({
    password,
    login: login.includes("@") ? login.split("@")[0] ?? login : login,
    email: emailHint,
  });
  const primary = passwordHash(
    login.includes("@") ? (login.split("@")[0] ?? login) : login,
    password,
  );

  const payload = await gateGet({
    action: "login",
    login,
    passHash: primary,
    passHashes: hashes.join(","),
  });

  if (!payload) {
    return {
      ok: false,
      unreachable: true,
      error:
        "Não foi possível falar com o cadastro de usuários (planilha GS Campo).",
    };
  }

  if (payload.ok === true) {
    const user = asUser(payload.user);
    if (!user) {
      return { ok: false, error: "Resposta de login incompleta." };
    }
    return { ok: true, user };
  }

  return {
    ok: false,
    error: String(payload.error || "Não foi possível entrar."),
    pending: payload.pending === true,
    wrongPassword: payload.wrongPassword === true,
  };
}
