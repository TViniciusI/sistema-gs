import Link from "next/link";
import { AuditoriaBoard } from "@/components/auditoria/auditoria-board";
import { PageHeader } from "@/components/ui";
import { listCampoAudit } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function AuditoriaPage() {
  const entries = await listCampoAudit(250);

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Sistema"
        title="Auditoria"
        description="Quem salvou ou apagou cada registro — escritório e app, na mesma planilha."
        action={
          <Link
            href="/configuracoes"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Configurações
          </Link>
        }
      />
      <AuditoriaBoard entries={entries} />
    </div>
  );
}
