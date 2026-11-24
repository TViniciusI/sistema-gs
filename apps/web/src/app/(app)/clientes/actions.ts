"use server";

import { revalidatePath } from "next/cache";
import {
  deleteCampoClientSystem,
  updateCampoClientFields,
} from "@/lib/campo-data";

export type DeleteSystemState = { error?: string; ok?: boolean };

export async function deleteClientSystemAction(
  _prev: DeleteSystemState,
  formData: FormData,
): Promise<DeleteSystemState> {
  const clientId = String(formData.get("clientId") || "").trim();
  const systemId = String(formData.get("systemId") || "").trim();
  if (!clientId || !systemId) {
    return { error: "Dados incompletos." };
  }

  const result = await deleteCampoClientSystem(clientId, systemId);
  if (!result.ok) {
    return { error: result.error || "Falha ao apagar." };
  }

  revalidatePath(`/clientes/${clientId}`);
  revalidatePath("/clientes");
  return { ok: true };
}

export async function updateClienteAction(input: {
  clientId: string;
  name: string;
  requester: string;
  city: string;
  state: string;
  baseName: string;
  baseCargo: string;
  baseEmail: string;
  basePhone: string;
  sites: string;
}): Promise<{ ok: boolean; error?: string }> {
  const result = await updateCampoClientFields(input);
  if (result.ok) {
    revalidatePath(`/clientes/${input.clientId}`);
    revalidatePath("/clientes");
  }
  return result;
}
