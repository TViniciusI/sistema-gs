import { gateGet } from "./gate";
import { parseDriveStatus } from "./parse";
import type { CampoDriveStatus } from "./types";

export async function getCampoDriveStatus(): Promise<CampoDriveStatus> {
  const payload = await gateGet({ action: "drivestatus" }, { withToken: true });
  if (!payload) {
    return {
      ok: false,
      error: "Não foi possível consultar o Google Drive.",
      raw: {},
    };
  }
  return parseDriveStatus(payload);
}
