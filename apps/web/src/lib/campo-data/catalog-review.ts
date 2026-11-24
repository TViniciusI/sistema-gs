import type { CampoOrder } from "./types";
import { parseOsCalibrationSlots } from "./os-docs";

export type PendingCatalogItem = {
  osId: string;
  osNumber: string;
  clientName: string;
  slotId: string;
  kind: string;
  certificateNumber: string;
  equipmentTag: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
};

/** Slots com catalogStatus=pending nas OS (mesmo critério do app). */
export function pendingCatalogFromOrders(
  orders: CampoOrder[],
): PendingCatalogItem[] {
  const out: PendingCatalogItem[] = [];
  for (const os of orders) {
    const slots = parseOsCalibrationSlots(os);
    const rawSlots = Array.isArray(os.raw.calibrationSlots)
      ? os.raw.calibrationSlots
      : [];
    for (const slot of slots) {
      const raw = rawSlots.find(
        (item) =>
          item &&
          typeof item === "object" &&
          String((item as Record<string, unknown>).id || "") === slot.id,
      ) as Record<string, unknown> | undefined;
      const status = String(raw?.catalogStatus || "")
        .trim()
        .toLowerCase();
      if (status !== "pending") continue;
      out.push({
        osId: os.id,
        osNumber: os.number,
        clientName: os.clientName,
        slotId: slot.id,
        kind: slot.kind,
        certificateNumber: slot.certificateNumber,
        equipmentTag: slot.equipmentTag,
        serialNumber: slot.serialNumber,
        manufacturer: slot.manufacturer,
        model: slot.model,
      });
    }
  }
  return out;
}
