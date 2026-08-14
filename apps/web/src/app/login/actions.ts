"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { DEMO_COOKIE, demoCookieOptions } from "@/lib/demo/constants";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/server";

export async function login() {
  const jar = await cookies();
  jar.set(DEMO_COOKIE, "1", demoCookieOptions);
  redirect("/");
}

export async function logout() {
  const jar = await cookies();
  jar.delete({ name: DEMO_COOKIE, path: "/" });
  if (isSupabaseConfigured()) {
    const supabase = await createClient();
    await supabase.auth.signOut();
  }
  redirect("/login");
}
