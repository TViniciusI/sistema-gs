"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  CAMPO_SESSION_COOKIE,
  campoSessionCookieOptions,
  encodeCampoSession,
  loginWithCampoGate,
  toSessionUser,
} from "@/lib/campo-auth";
import { DEMO_COOKIE } from "@/lib/demo/constants";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/server";

export type LoginState = {
  error?: string;
};

export async function login(
  _prev: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const loginId = String(formData.get("login") || formData.get("email") || "")
    .trim();
  const password = String(formData.get("password") || "");

  const result = await loginWithCampoGate(loginId, password);
  if (!result.ok) {
    return { error: result.error };
  }

  const sessionUser = toSessionUser(result.user);
  const jar = await cookies();
  jar.set(
    CAMPO_SESSION_COOKIE,
    encodeCampoSession(sessionUser),
    campoSessionCookieOptions,
  );
  // Sessão real substitui a demo antiga.
  jar.delete({ name: DEMO_COOKIE, path: "/" });

  redirect("/");
}

export async function logout() {
  const jar = await cookies();
  jar.delete({ name: CAMPO_SESSION_COOKIE, path: "/" });
  jar.delete({ name: DEMO_COOKIE, path: "/" });
  if (isSupabaseConfigured()) {
    const supabase = await createClient();
    await supabase.auth.signOut();
  }
  redirect("/login");
}
