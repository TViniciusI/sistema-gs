"use server";

import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import { deleteCampoStandard, saveCampoStandard } from "@/lib/campo-data";

export async function savePadraoAction(
  _prev: { error?: string; ok?: boolean },
  formData: FormData,
): Promise<{ error?: string; ok?: boolean }> {
  const profile = await getProfile();
  if (!profile) return { error: "Sessão expirada." };
  const name = String(formData.get("name") || "").trim();
  if (!name) return { error: "Informe o nome do padrão." };
  const result = await saveCampoStandard({
    id: String(formData.get("id") || "").trim() || undefined,
    name,
    type: String(formData.get("type") || ""),
    serial: String(formData.get("serial") || ""),
    certificate: String(formData.get("certificate") || ""),
    validity: String(formData.get("validity") || ""),
    uncertainty: String(formData.get("uncertainty") || ""),
    coverageK: String(formData.get("coverageK") || ""),
  });
  if (!result.ok) return { error: result.error };
  revalidatePath("/padroes");
  return { ok: true };
}

export async function deletePadraoAction(id: string) {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  const result = await deleteCampoStandard(id);
  if (result.ok) revalidatePath("/padroes");
  return result;
}
