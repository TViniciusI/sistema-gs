import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDocActions } from "@/components/os/os-doc-actions";
import { PageHeader, StatusPill } from "@/components/ui";
import {
  campoAppUrl,
  certificatesForOs,
  getCampoDriveStatus,
  getCampoOrder,
  groupCertificatesByKind,
  listCampoCalibrations,
  parseOsRdos,
} from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

export default async function OsDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [os, drive, calibrations] = await Promise.all([
    getCampoOrder(id),
    getCampoDriveStatus(),
    listCampoCalibrations(),
  ]);
  if (!os) notFound();

  const rdo = (
    os.raw.rdo && typeof os.raw.rdo === "object" ? os.raw.rdo : {}
  ) as Record<string, unknown>;
  const certRows = certificatesForOs(os, calibrations);
  const rdos = parseOsRdos(os);
  const groups = groupCertificatesByKind(certRows);
  const slotsCount = certRows.length;

  const service = text(rdo.service) || "—";
  const systemType = text(rdo.systemType) || "—";
  const site =
    text(rdo.site) ||
    [rdo.city, rdo.state].filter(Boolean).join("/") ||
    text(rdo.baseName) ||
    "—";

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Operação"
        title={`OS GS ${os.number}`}
        description={os.clientName || "Ordem de serviço GS Campo"}
        action={
          <div className="flex flex-wrap items-center gap-2">
            <StatusPill
              label={campoOsStatusLabel(os.status)}
              tone={campoOsStatusTone(os.status)}
            />
            <Link
              href={`/os/${os.id}/documentos`}
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Documentos
            </Link>
            <Link
              href="/os"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        }
      />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              {campoOsStatusLabel(os.status)}
            </p>
            <h2 className="mt-1 font-serif text-3xl text-navy">
              {os.clientName || text(rdo.client) || "—"}
            </h2>
            <p className="mt-2 text-sm text-navy/55">
              CNPJ {text(rdo.cnpj) || "—"} · {service}
              {os.startsAt
                ? ` · Início ${new Date(os.startsAt).toLocaleDateString("pt-BR")}`
                : ""}
            </p>
            <p className="mt-1 text-sm text-navy/55">
              Técnicos: {os.technicianName || "—"}
            </p>
          </div>
        </div>
        <div className="mt-5 grid gap-3 sm:grid-cols-3">
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Local
            </p>
            <p className="mt-1 text-sm font-medium text-navy">{site}</p>
          </div>
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Sistema
            </p>
            <p className="mt-1 text-sm font-medium text-navy">{systemType}</p>
          </div>
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Campo
            </p>
            <p className="mt-1 text-sm font-medium text-navy">
              {rdos.length} RDO · {slotsCount} cert. · {os.fileCount} arq.
            </p>
          </div>
        </div>
      </section>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Calibração nesta OS
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">
            Certificados, livro e RDO
          </h2>
          <p className="mt-2 text-sm leading-6 text-navy/60">
            Os certificados são preenchidos no GS Campo. No escritório você lê
            volumétrica, temperatura e densidade, gera o livro e imprime o RDO.
          </p>
          <div className="mt-4">
            <OsDocActions
              osId={os.id}
              hasSlots={slotsCount > 0}
              hasRdos={rdos.length > 0}
              driveUrl={drive.folderUrl}
              campoUrl={campoAppUrl()}
            />
          </div>
        </section>

        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Itens
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">
            Slots de calibração
          </h2>
          {groups.length === 0 ? (
            <p className="mt-6 rounded-2xl border border-dashed border-navy/15 px-4 py-10 text-center text-sm text-muted">
              Sem slots nesta OS.
            </p>
          ) : (
            <div className="mt-4 space-y-3">
              {groups.map((group) => (
                <div
                  key={group.kind}
                  className="flex items-center justify-between rounded-2xl border border-navy/10 bg-paper/70 px-4 py-3"
                >
                  <div>
                    <p className="font-semibold text-navy">
                      {group.label} · {group.items.length}
                    </p>
                    <p className="mt-0.5 text-xs text-navy/45">{group.stats}</p>
                  </div>
                  <Link
                    href={`/os/${os.id}/certificados?kind=${encodeURIComponent(group.kind)}`}
                    className="text-xs font-medium text-navy/50 hover:text-navy"
                  >
                    Ver →
                  </Link>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
