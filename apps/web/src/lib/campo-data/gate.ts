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
  const payload = {
    ...body,
    token: body.token ?? loginGateToken(),
    appBuild: body.appBuild ?? appBuild(),
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
