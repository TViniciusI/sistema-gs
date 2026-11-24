import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader, Panel } from "@/components/ui";
import { getCampoOrder, parseOsRdoMeta } from "@/lib/campo-data";
import { OsEditForm } from "./os-edit-form";

export const dynamic = "force-dynamic";

export default async function OsEditarPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const meta = parseOsRdoMeta(os);
  const startsAt = os.startsAt
    ? new Date(os.startsAt).toISOString().slice(0, 10)
    : "";

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title={`Editar OS GS ${os.number}`}
        description="Altera cabeçalho na planilha — RDOs e certificados permanecem."
        action={
          <Link
            href={`/os/${os.id}`}
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Voltar
          </Link>
        }
      />
      <Panel>
        <OsEditForm
          osId={os.id}
          defaults={{
            client: meta.client || os.clientName,
            site: meta.site,
            cnpj: meta.cnpj,
            systemType: meta.systemType,
            service: meta.service,
            baseName: meta.baseName,
            baseCargo: meta.baseCargo,
            baseEmail: meta.baseEmail,
            basePhone: meta.basePhone,
            technicianName: os.technicianName,
            technicianEmails: String(
              os.raw.technicianEmails || os.raw.technicianEmail || "",
            ),
            startsAt,
          }}
        />
      </Panel>
    </div>
  );
}
