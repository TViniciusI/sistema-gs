"use server";

import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import { signCampoStaffDoc } from "@/lib/campo-data";

export async function signDocumentoAction(id: string) {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  const result = await signCampoStaffDoc({
    id,
    signedBy: profile.full_name || profile.email || profile.login || "escritorio",
  });
  if (result.ok) revalidatePath("/documentos");
  return result;
}
