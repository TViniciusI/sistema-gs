import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintToolbar } from "@/components/os/print-toolbar";
import { PageHeader } from "@/components/ui";
import {
  campoAppUrl,
  getCampoOrder,
  parseOsRdos,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsRdoPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const rdos = parseOsRdos(os);
  const rdoMeta =
    os.raw.rdo && typeof os.raw.rdo === "object"
      ? (os.raw.rdo as Record<string, unknown>)
      : {};

  return (
    <div className="space-y-6">
      <div className="no-print">
        <PageHeader
          eyebrow="Campo"
          title={`RDO · OS GS ${os.number}`}
          description="Impressão consolidada no escritório. Preenchimento e assinatura continuam no GS Campo."
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

      <PrintToolbar title={`RDO · OS GS ${os.number}`} />

      <article className="print-sheet rounded-3xl border border-navy/10 bg-white p-6 md:p-8">
        <header className="border-b border-navy/10 pb-5">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Relatório diário de obra
          </p>
          <h1 className="mt-2 font-serif text-3xl text-navy">
            OS GS {os.number}
          </h1>
          <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-muted">Cliente</dt>
              <dd className="font-medium text-navy">
                {os.clientName || String(rdoMeta.client || "—")}
              </dd>
            </div>
            <div>
              <dt className="text-muted">Técnicos</dt>
              <dd className="font-medium text-navy">
                {os.technicianName || "—"}
              </dd>
            </div>
            <div>
              <dt className="text-muted">Local</dt>
              <dd className="font-medium text-navy">
                {String(rdoMeta.site || "—")}
              </dd>
            </div>
            <div>
              <dt className="text-muted">Serviço</dt>
              <dd className="font-medium text-navy">
                {String(rdoMeta.service || "—")}
              </dd>
            </div>
          </dl>
        </header>

        {rdos.length === 0 ? (
          <p className="mt-8 text-sm text-muted">
            Ainda não há RDO enviado nesta OS.
          </p>
        ) : (
          <div className="mt-6 space-y-4">
            {rdos.map((rdo, index) => (
              <section
                key={rdo.id}
                className="rounded-2xl border border-navy/10 bg-paper/50 px-4 py-4"
              >
                <h2 className="font-semibold text-navy">
                  RDO {index + 1}
                  {rdo.date
                    ? ` · ${new Date(rdo.date).toLocaleDateString("pt-BR")}`
                    : ""}
                </h2>
                <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-navy/75">
                  {rdo.description}
                </p>
              </section>
            ))}
          </div>
        )}
      </article>
    </div>
  );
}
