import {
  CAMPO_SESSION_COOKIE,
  decodeCampoSession,
} from "@/lib/campo-auth";
import {
  appBuild,
  loginGateToken,
  loginGateUrl,
} from "@/lib/campo-auth/config";

export type GateResult<T> = {
  ok: boolean;
  error?: string;
  data?: T;
  raw?: Record<string, unknown>;
};

/** Anexa quem está logado no escritório a toda mutação do gate. */
async function officeActorFields(): Promise<Record<string, string>> {
  try {
    const { cookies } = await import("next/headers");
    const jar = await cookies();
    const session = decodeCampoSession(jar.get(CAMPO_SESSION_COOKIE)?.value);
    if (!session) return {};
    return {
      actorLogin: session.login || "",
      actorName: session.name || "",
      actorEmail: session.email || "",
      actorSource: "escritorio",
    };
  } catch {
    return {};
  }
}

export async function gateGet(
  params: Record<string, string>,
  options?: { timeoutMs?: number; withToken?: boolean },
): Promise<Record<string, unknown> | null> {
  const base = loginGateUrl();
  if (!base) return null;
  const url = new URL(base);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) url.searchParams.set(key, value);
  }
  if (options?.withToken !== false) {
    url.searchParams.set("token", loginGateToken());
  }
  url.searchParams.set("appBuild", appBuild());

  const timeoutMs = options?.timeoutMs ?? 60_000;
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

/** Apps Script aceita POST text/plain JSON (como o app nativo). */
export async function gatePost(
  body: Record<string, unknown>,
  options?: { timeoutMs?: number },
): Promise<Record<string, unknown> | null> {
  const base = loginGateUrl();
  if (!base) return null;
  const actor = await officeActorFields();
  const payload = {
    ...actor,
    ...body,
    token: body.token ?? loginGateToken(),
    appBuild: body.appBuild ?? appBuild(),
    actorLogin: String(body.actorLogin || actor.actorLogin || ""),
    actorName: String(body.actorName || actor.actorName || ""),
    actorEmail: String(body.actorEmail || actor.actorEmail || ""),
    actorSource: String(body.actorSource || actor.actorSource || "escritorio"),
  };
  const timeoutMs = options?.timeoutMs ?? 90_000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(base, {
      method: "POST",
      redirect: "follow",
      cache: "no-store",
      signal: controller.signal,
      headers: { "Content-Type": "text/plain;charset=utf-8" },
      body: JSON.stringify(payload),
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
