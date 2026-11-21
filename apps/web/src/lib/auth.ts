import { cache } from "react";
import { cookies } from "next/headers";
import type { Role } from "@gs/shared";
import {
  CAMPO_SESSION_COOKIE,
  campoRoleLabel,
  decodeCampoSession,
} from "@/lib/campo-auth";
import { getDemoProfile, isDemoAuthenticated } from "@/lib/demo/session";
import { isSupabaseConfigured } from "@/lib/supabase/server";
import { createClient } from "@/lib/supabase/server";

export type Profile = {
  id: string;
  organization_id: string;
  email: string;
  full_name: string;
  role: Role;
  is_active: boolean;
  login?: string;
  permissions?: string;
  cargo?: string;
  /** Rótulo amigável do papel (planilha / shell) */
  role_label?: string;
  source?: "campo" | "demo" | "supabase";
};

export const getProfile = cache(async (): Promise<Profile | null> => {
  const jar = await cookies();
  const campo = decodeCampoSession(jar.get(CAMPO_SESSION_COOKIE)?.value);
  if (campo) {
    return {
      id: `campo:${campo.login || campo.email}`,
      organization_id: "org-gs",
      email: campo.email || `${campo.login}@gssolucoestec.com.br`,
      full_name: campo.name,
      role: campo.role,
      is_active: campo.active,
      login: campo.login,
      permissions: campo.permissions,
      cargo: campo.cargo,
      role_label: campoRoleLabel(campo.campoRole, campo.role),
      source: "campo",
    };
  }

  if (!isSupabaseConfigured()) {
    if (await isDemoAuthenticated()) {
      return { ...getDemoProfile(), source: "demo" };
    }
    return null;
  }

  if (await isDemoAuthenticated()) {
    return { ...getDemoProfile(), source: "demo" };
  }

  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) return null;

  const { data, error } = await supabase
    .from("profiles")
    .select("id, organization_id, email, full_name, role, is_active")
    .eq("id", userId)
    .maybeSingle();

  if (error || !data) return null;
  return { ...(data as Profile), source: "supabase" };
});

export async function requireProfile(): Promise<Profile> {
  const profile = await getProfile();
  if (!profile) {
    throw new Error("Sessão inválida");
  }
  return profile;
}
