import { createHmac, timingSafeEqual } from "node:crypto";
import type { NextRequest, NextResponse } from "next/server";
import { sessionSecret } from "./config";
import type { CampoSessionUser } from "./types";

export const CAMPO_SESSION_COOKIE = "gs_campo_session";

const MAX_AGE_SECONDS = 60 * 60 * 24 * 14; // 14 dias

export const campoSessionCookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
  maxAge: MAX_AGE_SECONDS,
};

type SessionPayload = CampoSessionUser & { exp: number };

function b64url(input: Buffer | string): string {
  const buf = typeof input === "string" ? Buffer.from(input, "utf8") : input;
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function fromB64url(value: string): Buffer {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  return Buffer.from(padded + pad, "base64");
}

function sign(body: string): string {
  return b64url(createHmac("sha256", sessionSecret()).update(body).digest());
}

export function encodeCampoSession(user: CampoSessionUser): string {
  const payload: SessionPayload = {
    ...user,
    exp: Math.floor(Date.now() / 1000) + MAX_AGE_SECONDS,
  };
  const body = b64url(JSON.stringify(payload));
  return `${body}.${sign(body)}`;
}

export function decodeCampoSession(raw: string | undefined | null): CampoSessionUser | null {
  if (!raw) return null;
  const parts = raw.split(".");
  if (parts.length !== 2) return null;
  const [body, sig] = parts;
  if (!body || !sig) return null;
  const expected = sign(body);
  try {
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  } catch {
    return null;
  }
  try {
    const parsed = JSON.parse(fromB64url(body).toString("utf8")) as SessionPayload;
    if (!parsed || typeof parsed !== "object") return null;
    if (!parsed.exp || parsed.exp < Math.floor(Date.now() / 1000)) return null;
    if (!parsed.login && !parsed.email) return null;
    if (parsed.active === false) return null;
    return {
      email: String(parsed.email || "").toLowerCase(),
      login: String(parsed.login || "").toLowerCase(),
      name: String(parsed.name || ""),
      phone: String(parsed.phone || ""),
      campoRole: String(parsed.campoRole || "tecnico"),
      role: parsed.role,
      permissions: String(parsed.permissions || "geral"),
      cargo: String(parsed.cargo || ""),
      funcao: String(parsed.funcao || ""),
      status: String(parsed.status || "aprovado"),
      active: true,
    };
  } catch {
    return null;
  }
}

export function readCampoSessionFromRequest(
  request: NextRequest,
): CampoSessionUser | null {
  return decodeCampoSession(request.cookies.get(CAMPO_SESSION_COOKIE)?.value);
}

export function clearCampoSessionCookie(response: NextResponse) {
  response.cookies.set(CAMPO_SESSION_COOKIE, "", {
    ...campoSessionCookieOptions,
    maxAge: 0,
  });
}
