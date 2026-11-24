import { gateGet } from "./gate";

export type CampoAuditEntry = {
  at: string;
  actorLogin: string;
  actorName: string;
  actorEmail: string;
  source: string;
  action: string;
  entity: string;
  entityId: string;
  summary: string;
};

function text(value: unknown) {
  return String(value ?? "").trim();
}

export async function listCampoAudit(
  limit = 200,
): Promise<CampoAuditEntry[]> {
  const payload = await gateGet(
    { action: "listaudit", limit: String(limit) },
    { withToken: true, timeoutMs: 45_000 },
  );
  if (!payload || payload.ok !== true) return [];
  const list = Array.isArray(payload.entries) ? payload.entries : [];
  return list
    .map((raw) => {
      if (!raw || typeof raw !== "object") return null;
      const e = raw as Record<string, unknown>;
      return {
        at: text(e.at),
        actorLogin: text(e.actorLogin),
        actorName: text(e.actorName),
        actorEmail: text(e.actorEmail),
        source: text(e.source) || "—",
        action: text(e.action),
        entity: text(e.entity),
        entityId: text(e.entityId),
        summary: text(e.summary),
      } satisfies CampoAuditEntry;
    })
    .filter(Boolean) as CampoAuditEntry[];
}

export function formatAuditActor(entry: {
  actorName?: string;
  actorLogin?: string;
  actorEmail?: string;
}) {
  return (
    text(entry.actorName) ||
    text(entry.actorLogin) ||
    text(entry.actorEmail) ||
    "—"
  );
}

export function formatChangeMeta(raw: Record<string, unknown> | null | undefined) {
  if (!raw) return null;
  const name =
    text(raw.updatedByName) ||
    text(raw.updatedBy) ||
    text(raw.updatedByEmail);
  if (!name) return null;
  const at = text(raw.updatedByAt) || text(raw.updatedAt);
  const source = text(raw.updatedBySource);
  return { name, at, source };
}

export function entityLabel(entity: string) {
  switch (entity) {
    case "os":
      return "OS";
    case "cliente":
      return "Cliente";
    case "padrao":
      return "Padrão";
    case "fluido":
      return "Fluido";
    case "calibracao":
      return "Calibração";
    case "perfil":
      return "Perfil";
    case "senha":
      return "Senha";
    default:
      return entity || "Registro";
  }
}

export function actionLabel(action: string) {
  switch (action) {
    case "salvar":
      return "Salvou";
    case "apagar":
      return "Apagou";
    default:
      return action || "Alterou";
  }
}
