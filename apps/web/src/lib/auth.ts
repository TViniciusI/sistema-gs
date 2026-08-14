import { cache } from "react";
import type { Role } from "@gs/shared";
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
};

export const getProfile = cache(async (): Promise<Profile | null> => {
  if (!isSupabaseConfigured()) {
    return getDemoProfile();
  }
  if (await isDemoAuthenticated()) {
    return getDemoProfile();
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
  return data as Profile;
});

export async function requireProfile(): Promise<Profile> {
  const profile = await getProfile();
  if (!profile) {
    throw new Error("Sessão inválida");
  }
  return profile;
}
