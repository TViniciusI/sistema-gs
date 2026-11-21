import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { listCampoStaffDocs } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

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
        headers={["Documento", "Colaborador", "Tipo", "Criado", "Assinatura"]}
        empty="Nenhum documento encontrado."
        rows={visible.map((doc) => [
          doc.name,
          doc.staffEmail || "—",
          doc.kind || "—",
          doc.createdAt
            ? new Date(doc.createdAt).toLocaleDateString("pt-BR")
            : "—",
          <StatusPill
            key={doc.id}
            label={
              doc.signedAt
                ? "Assinado"
                : doc.requiresSignature
                  ? "Pendente"
                  : "—"
            }
            tone={
              doc.signedAt ? "ok" : doc.requiresSignature ? "warn" : "neutral"
            }
          />,
        ])}
      />
    </div>
  );
}
