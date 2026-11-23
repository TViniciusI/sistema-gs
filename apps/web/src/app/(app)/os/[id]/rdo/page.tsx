import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import { PrintToolbar } from "@/components/os/print-toolbar";
import { RdoServiceReport } from "@/components/os/rdo-service-report";
import { PageHeader } from "@/components/ui";
import {
  campoAppUrl,
  getCampoOrder,
  listCampoOsDriveFiles,
  parseOsRdoMeta,
  parseOsRdos,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsRdoPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ rdo?: string }>;
}) {
  const { id } = await params;
  const { rdo: rdoFilter } = await searchParams;
  const os = await getCampoOrder(id);
  if (!os) notFound();

  const meta = parseOsRdoMeta(os);
  const rdos = parseOsRdos(os);
  const drive = await listCampoOsDriveFiles(os.number);
  const selected =
    (rdoFilter
      ? rdos.find((r) => r.id === rdoFilter)
      : null) || rdos[0] || null;

  return (
    <div className="space-y-6">
      <div className="no-print">
        <PageHeader
          eyebrow="Campo"
          title={`RDO · OS GS ${os.number}`}
          description="Relatório de Serviço no mesmo formato do GS Campo. Imprima ou salve em PDF."
          action={
            <div className="flex flex-wrap gap-2">
              <Link
                href={`/os/${os.id}/documentos`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                Documentos
              </Link>
              <a
                href={campoAppUrl()}
                target="_blank"
                rel="noreferrer"
                className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
              >
                Preencher no Campo ↗
              </a>
            </div>
          }
        />
      </div>

      {rdos.length > 1 ? (
        <div className="no-print flex flex-wrap gap-2">
          {rdos.map((rdo, index) => {
            const active = selected?.id === rdo.id;
            return (
              <Link
                key={rdo.id}
                href={`/os/${os.id}/rdo?rdo=${encodeURIComponent(rdo.id)}`}
                className={[
                  "rounded-xl px-3 py-2 text-sm font-medium transition",
                  active
                    ? "bg-navy text-paper"
                    : "border border-navy/15 bg-white text-navy hover:border-brass/40",
                ].join(" ")}
              >
                Dia {index + 1}
                {rdo.date
                  ? ` · ${new Date(rdo.date).toLocaleDateString("pt-BR")}`
                  : ""}
              </Link>
            );
          })}
        </div>
      ) : null}

      <div className="no-print">
        <OsDrivePanel listing={drive} focus="rdo" />
      </div>

      <PrintToolbar
        title={
          selected
            ? `Relatório de Serviço · OS ${os.number}`
            : `RDO · OS GS ${os.number}`
        }
      />

      {rdos.length === 0 || !selected ? (
        <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
          Ainda não há RDO nesta OS. Preencha e assine no GS Campo.
        </p>
      ) : (
        <div className="space-y-8 print:space-y-0">
          {/* Na tela: o selecionado; na impressão: todos os dias, um por página */}
          <div className="print:hidden">
            <RdoServiceReport
              osNumber={os.number}
              technicianName={os.technicianName}
              meta={meta}
              entry={selected}
            />
          </div>
          <div className="hidden print:block">
            {rdos.map((entry) => (
              <div key={entry.id} className="rdo-print-page">
                <RdoServiceReport
                  osNumber={os.number}
                  technicianName={os.technicianName}
                  meta={meta}
                  entry={entry}
                />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
