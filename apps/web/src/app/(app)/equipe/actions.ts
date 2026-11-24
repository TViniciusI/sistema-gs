"use server";

import { getProfile } from "@/lib/auth";
import {
  decideCampoUser,
  setCampoUserActive,
  setCampoUserCargo,
  setCampoUserPermissions,
  setCampoUserRole,
} from "@/lib/campo-data";

export type EquipeActionResult = { ok: boolean; error?: string };

async function requireOfficeAdmin(): Promise<EquipeActionResult | null> {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  if (profile.role !== "admin" && profile.role !== "office") {
    return { ok: false, error: "Sem permissão de escritório." };
  }
  return null;
}

export async function decideEquipeUser(input: {
  email: string;
  login?: string;
  status: "aprovado" | "recusado";
  role?: string;
}): Promise<EquipeActionResult> {
  const denied = await requireOfficeAdmin();
  if (denied) return denied;
  const email = String(input.email || "").trim().toLowerCase();
  if (!email && !input.login) {
    return { ok: false, error: "Usuário sem e-mail/login." };
  }
  return decideCampoUser({
    email,
    login: input.login,
    status: input.status,
    role: input.role,
  });
}

export async function updateEquipeUser(input: {
  email: string;
  login?: string;
  role?: string;
  active?: boolean;
  permissions?: string;
  cargo?: string;
}): Promise<EquipeActionResult> {
  const denied = await requireOfficeAdmin();
  if (denied) return denied;
  const email = String(input.email || "").trim().toLowerCase();
  if (!email && !input.login) {
    return { ok: false, error: "Usuário sem e-mail/login." };
  }

  if (input.role) {
    const r = await setCampoUserRole({
      email,
      login: input.login,
      role: input.role,
    });
    if (!r.ok) return r;
  }
  if (typeof input.active === "boolean") {
    const r = await setCampoUserActive({
      email,
      login: input.login,
      active: input.active,
    });
    if (!r.ok) return r;
  }
  if (input.permissions != null) {
    const r = await setCampoUserPermissions({
      email,
      login: input.login,
      permissions: input.permissions,
    });
    if (!r.ok) return r;
  }
  if (input.cargo != null) {
    const r = await setCampoUserCargo({
      email,
      login: input.login,
      cargo: input.cargo,
    });
    if (!r.ok) return r;
  }
  return { ok: true };
}
