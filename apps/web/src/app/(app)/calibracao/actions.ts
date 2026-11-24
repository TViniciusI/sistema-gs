"use server";

import { revalidatePath } from "next/cache";
import {
  newCalibrationId,
  saveCampoCalibration,
} from "@/lib/campo-data";

export async function saveCalibracaoAction(input: {
  id?: string;
  number?: string;
  kind?: string;
  clientName?: string;
  payload: Record<string, unknown>;
}): Promise<{ ok: boolean; error?: string; id?: string }> {
  const id = input.id || String(input.payload.id || "") || newCalibrationId();
  const result = await saveCampoCalibration({
    ...input,
    id,
    payload: { ...input.payload, id },
  });
  if (result.ok && result.id) {
    revalidatePath("/calibracao");
    revalidatePath(`/calibracao/${result.id}`);
    revalidatePath("/certificados");
  }
  return result;
}
