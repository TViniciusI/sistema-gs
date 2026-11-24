"use server";

import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import { deleteCampoFluid, saveCampoFluid } from "@/lib/campo-data";

export async function saveFluidoAction(
  _prev: { error?: string; ok?: boolean },
  formData: FormData,
): Promise<{ error?: string; ok?: boolean }> {
  const profile = await getProfile();
  if (!profile) return { error: "Sessão expirada." };
  const name = String(formData.get("name") || "").trim();
  if (!name) return { error: "Informe o nome do fluido." };
  const result = await saveCampoFluid({
    id: String(formData.get("id") || "").trim() || undefined,
    name,
    densityMin: String(formData.get("densityMin") || ""),
    densityMax: String(formData.get("densityMax") || ""),
    viscosityMin: String(formData.get("viscosityMin") || ""),
    viscosityMax: String(formData.get("viscosityMax") || ""),
    densityRefTemp: String(formData.get("densityRefTemp") || "20 °C"),
    viscosityRefTemp: String(formData.get("viscosityRefTemp") || "40 °C"),
  });
  if (!result.ok) return { error: result.error };
  revalidatePath("/fluidos");
  return { ok: true };
}

export async function deleteFluidoAction(id: string) {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  const result = await deleteCampoFluid(id);
  if (result.ok) revalidatePath("/fluidos");
  return result;
}
