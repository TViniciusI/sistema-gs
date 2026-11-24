import { DocumentosBoard } from "@/components/documentos/documentos-board";
import { PageHeader } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { listCampoStaffDocs } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function DocumentosPage() {
  const [profile, docs] = await Promise.all([
    getProfile(),
    listCampoStaffDocs(),
  ]);

  const mineEmail = (profile?.email || "").toLowerCase();
  const isOffice =
    profile?.role === "admin" || profile?.role === "office";
  const visible = isOffice
    ? docs
    : docs.filter((d) => d.staffEmail === mineEmail);

  const pending = visible.filter(
    (d) => d.requiresSignature && !d.signedAt,
  ).length;

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="RH"
        title="Documentos RH"
        description={
          pending > 0
            ? `${pending} pendente(s) de assinatura — entre com o seu login e use Assinar nos cards.`
            : isOffice
              ? "Holerites e anexos — anexe na ficha do funcionário em Funcionários."
              : "Seus holerites e documentos — assine os pendentes com o mesmo login do GS Campo."
        }
      />
      <DocumentosBoard
        docs={visible.map((doc) => ({
          id: doc.id,
          name: doc.name,
          staffEmail: doc.staffEmail,
          kind: doc.kind,
          createdAt: doc.createdAt,
          requiresSignature: doc.requiresSignature,
          signedAt: doc.signedAt,
          signedBy: doc.signedBy,
          path: doc.path,
        }))}
      />
    </div>
  );
}
