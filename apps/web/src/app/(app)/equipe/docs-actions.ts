"use server";

import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import {
  deleteCampoStaffDoc,
  saveCampoStaffDoc,
  signCampoStaffDoc,
} from "@/lib/campo-data";

async function requireOffice() {
  const profile = await getProfile();
  if (!profile) return { ok: false as const, error: "Sessão expirada." };
  if (profile.role !== "admin" && profile.role !== "office") {
    return { ok: false as const, error: "Sem permissão de escritório." };
  }
  return { ok: true as const, profile };
}

export async function uploadStaffDocAction(input: {
  staffEmail: string;
  name: string;
  kind: string;
  requiresSignature: boolean;
  mime?: string;
  data: string;
}) {
  const gate = await requireOffice();
  if (!gate.ok) return gate;
  const result = await saveCampoStaffDoc(input);
  if (result.ok) {
    revalidatePath("/equipe");
    revalidatePath("/documentos");
    const key = encodeURIComponent(input.staffEmail.toLowerCase());
    revalidatePath(`/equipe/${key}`);
  }
  return result;
}

export async function deleteStaffDocAction(id: string, staffKey: string) {
  const gate = await requireOffice();
  if (!gate.ok) return gate;
  const result = await deleteCampoStaffDoc(id);
  if (result.ok) {
    revalidatePath("/equipe");
    revalidatePath("/documentos");
    revalidatePath(`/equipe/${encodeURIComponent(staffKey)}`);
  }
  return result;
}

export async function signStaffDocOnFichaAction(id: string, staffKey: string) {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  const result = await signCampoStaffDoc({
    id,
    signedBy: profile.full_name || profile.email || profile.login || "escritorio",
  });
  if (result.ok) {
    revalidatePath("/documentos");
    revalidatePath(`/equipe/${encodeURIComponent(staffKey)}`);
  }
  return result;
}
