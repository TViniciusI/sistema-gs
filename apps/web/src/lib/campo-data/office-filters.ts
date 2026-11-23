import type { CampoOrder } from "./types";

function normalizeText(value: string) {
  return value
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Dev / contas de teste — não entram na carga de técnicos. */
export function isExcludedFromTechLoad(name: string) {
  const n = normalizeText(name);
  if (!n) return true;
  if (n.includes("vinicius") && n.includes("magalhaes")) return true;
  if (n === "vinicius") return true;
  if (n.includes("teste") && n.includes("vini")) return true;
  return false;
}

/**
 * OS de teste do desenvolvedor (ex.: "TESTE (VINI)") — ocultas no escritório.
 */
export function isOfficeHiddenOrder(os: Pick<
  CampoOrder,
  "number" | "clientName" | "technicianName"
>) {
  const blob = normalizeText(
    `${os.number} ${os.clientName} ${os.technicianName}`,
  );
  if (blob.includes("teste") && blob.includes("vini")) return true;
  return false;
}
