import { gateGet } from "./gate";
import type { CampoAuditEntry } from "./audit-format";

export type { CampoAuditEntry } from "./audit-format";
export {
  actionLabel,
  entityLabel,
  formatAuditActor,
  formatChangeMeta,
} from "./audit-format";

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
