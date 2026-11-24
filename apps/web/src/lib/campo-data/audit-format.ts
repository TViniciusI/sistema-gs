/** Formatação de auditoria — seguro para Client Components. */

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

export function formatChangeMeta(
  raw: Record<string, unknown> | null | undefined,
) {
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
    case "staffdoc":
    case "documento":
      return "Documento RH";
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
    case "assinar":
      return "Assinou";
    default:
      return action || "Alterou";
  }
}
