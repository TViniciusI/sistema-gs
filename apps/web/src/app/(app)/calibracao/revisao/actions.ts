"use server";

import { revalidatePath } from "next/cache";
import { getProfile } from "@/lib/auth";
import { getCampoOrder, saveCampoOrder } from "@/lib/campo-data";

export async function decideCatalogSlot(input: {
  osId: string;
  slotId: string;
  status: "approved" | "rejected";
}): Promise<{ ok: boolean; error?: string }> {
  const profile = await getProfile();
  if (!profile) return { ok: false, error: "Sessão expirada." };
  if (profile.role !== "admin" && profile.role !== "office") {
    return { ok: false, error: "Sem permissão." };
  }

  const os = await getCampoOrder(input.osId);
  if (!os) return { ok: false, error: "OS não encontrada." };

  const slots = Array.isArray(os.raw.calibrationSlots)
    ? [...(os.raw.calibrationSlots as Record<string, unknown>[])]
    : [];
  let found = false;
  const next = slots.map((slot) => {
    if (!slot || typeof slot !== "object") return slot;
    if (String(slot.id || "") !== input.slotId) return slot;
    found = true;
    return { ...slot, catalogStatus: input.status };
  });
  if (!found) return { ok: false, error: "Slot não encontrado na OS." };

  const result = await saveCampoOrder({
    id: os.id,
    number: os.number,
    status: os.status,
    updatedAt: new Date().toISOString(),
    calibrationSlotsJson: JSON.stringify(next),
  });
  if (!result.ok) {
    return { ok: false, error: result.error || "Falha ao salvar." };
  }
  revalidatePath("/calibracao/revisao");
  revalidatePath(`/os/${os.id}`);
  return { ok: true };
}
