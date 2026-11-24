import { cachedList, CAMPO_TAGS } from "./cache";
import { gateGet } from "./gate";
import { parseDriveStatus } from "./parse";
import type { CampoDriveStatus } from "./types";

export const getCampoDriveStatus = cachedList(
  "getCampoDriveStatus",
  [CAMPO_TAGS.drive],
  async (): Promise<CampoDriveStatus> => {
    const payload = await gateGet(
      { action: "drivestatus" },
      { withToken: true, timeoutMs: 30_000 },
    );
    if (!payload) {
      return {
        ok: false,
        error: "Não foi possível consultar o Google Drive.",
        raw: {},
      };
    }
    return parseDriveStatus(payload);
  },
  90,
);
