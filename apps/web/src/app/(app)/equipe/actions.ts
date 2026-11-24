"use server";

import { getProfile } from "@/lib/auth";
import { decideCampoUser } from "@/lib/campo-data";

export type DecideUserResult = { ok: boolean; error?: string };

export async function decideEquipeUser(input: {
  email: string;
  login?: string;
  status: "aprovado" | "recusado";
  role?: string;
}): Promise<DecideUserResult> {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  if (profile.role !== "admin" && profile.role !== "office") {
    return { ok: false, error: "Sem permissão para aprovar acessos." };
  }

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
