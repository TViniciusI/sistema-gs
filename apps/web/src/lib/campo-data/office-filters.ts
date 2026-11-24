import type { CampoOrder, CampoUser } from "./types";

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
  if (n.includes("viniciusmagalhaes")) return true;
  if (n.includes("teste") && n.includes("vini")) return true;
  return false;
}

/**
 * Remove nomes de teste/dev de listas "Técnico1, Técnico2".
 * Usado na leitura do escritório para não mostrar Vinicius em OS/certificados.
 */
export function stripDevTestPersonNames(value: string) {
  return value
    .split(/[,;|/]+/)
    .map((part) => part.trim())
    .filter((part) => part && !isExcludedFromTechLoad(part))
    .join(", ");
}

/**
 * OS de teste do desenvolvedor (ex.: "TESTE (VINI)") — ocultas no escritório.
 */
export function isOfficeHiddenOrder(
  os: Pick<CampoOrder, "number" | "clientName" | "technicianName">,
) {
  const blob = normalizeText(
    `${os.number} ${os.clientName} ${os.technicianName}`,
  );
  if (blob.includes("teste") && blob.includes("vini")) return true;
  return false;
}

/** Técnicos de campo elegíveis para equipe da OS (espelha o app). */
export function isFieldTechnicianUser(user: CampoUser) {
  if (!user.active) return false;
  const status = normalizeText(user.status);
  if (status && status !== "aprovado") return false;
  if (isExcludedFromTechLoad(user.name) || isExcludedFromTechLoad(user.login)) {
    return false;
  }
  const role = normalizeText(user.role);
  if (role === "dev" || role === "desenvolvedor") return false;
  return (
    role.includes("tecnico") ||
    role === "ambos" ||
    role.includes("tecnico e administrativo")
  );
}
