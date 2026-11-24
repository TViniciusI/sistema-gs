import { SignDocButton } from "@/components/documentos/sign-doc-button";
import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { listCampoStaffDocs } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function staffDocDriveUrl(fileId: string) {
  const id = fileId.trim();
  if (!id) return "";
  return `https://drive.google.com/file/d/${encodeURIComponent(id)}/view`;
}

export default async function DocumentosPage() {
  const [profile, docs] = await Promise.all([
    getProfile(),
    listCampoStaffDocs(),
  ]);

  const mineEmail = (profile?.email || "").toLowerCase();
  const visible =
    profile?.role === "admin" || profile?.role === "office"
      ? docs
      : docs.filter((d) => d.staffEmail === mineEmail);

  return (
    <div>
      <PageHeader
        eyebrow="RH"
        title="Documentos"
        description="Mesmos documentos RH do app (holerite, anexos, assinatura)."
      />
      <DataTable
        headers={[
          "Documento",
          "Colaborador",
          "Tipo",
          "Criado",
          "Assinatura",
          "Arquivo",
        ]}
        empty="Nenhum documento encontrado."
        rows={visible.map((doc) => {
          const url = staffDocDriveUrl(doc.path);
          const canSign = doc.requiresSignature && !doc.signedAt;
          return [
            doc.name,
            doc.staffEmail || "—",
            doc.kind || "—",
            doc.createdAt
              ? new Date(doc.createdAt).toLocaleDateString("pt-BR", {
                  timeZone: "America/Sao_Paulo",
                })
              : "—",
            <div key={`${doc.id}-sig`} className="flex items-center gap-2">
              <StatusPill
                label={
                  doc.signedAt
                    ? "Assinado"
                    : doc.requiresSignature
                      ? "Pendente"
                      : "—"
                }
                tone={
                  doc.signedAt
                    ? "ok"
                    : doc.requiresSignature
                      ? "warn"
                      : "neutral"
                }
              />
              <SignDocButton id={doc.id} disabled={!canSign} />
            </div>,
            url ? (
              <a
                key={`${doc.id}-file`}
                href={url}
                target="_blank"
                rel="noreferrer"
                className="text-sm font-medium text-navy hover:underline"
              >
                Abrir ↗
              </a>
            ) : (
              "—"
            ),
          ];
        })}
      />
    </div>
  );
}
