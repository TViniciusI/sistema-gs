import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDocActions } from "@/components/os/os-doc-actions";
import { OsMailForm } from "@/components/os/os-mail-form";
import { OsStatusActions } from "@/components/os/os-status-actions";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { ChangeMeta } from "@/components/ui/change-meta";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import {
  campoAppUrl,
  certificatesForOs,
  driveFilesByKind,
  getCampoDriveStatus,
  getCampoOrder,
  groupCertificatesByKind,
  listCampoCalibrations,
  listCampoOsDriveFiles,
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
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const [drive, calibrations, driveListing] = await Promise.all([
    getCampoDriveStatus(),
    listCampoCalibrations(),
    listCampoOsDriveFiles(os.number),
  ]);

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
  const hasTechnicians = Boolean(
    text(os.raw.technicianEmails) ||
      text(os.raw.technicianEmail) ||
      text(os.technicianName),
  );

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
              href={`/os/${os.id}/editar`}
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Editar
            </Link>
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
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Resumo
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
            <ChangeMeta raw={os.raw} className="mt-2" />
          </div>
          <OsStatusActions
            osId={os.id}
            osNumber={os.number}
            status={os.status}
            hasRdos={rdos.length > 0}
            hasTechnicians={hasTechnicians}
            compact
          />
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

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)]">
        <OsDrivePanel
          listing={driveListing}
          variant="summary"
          docsHref={`/os/${os.id}/documentos`}
        />

        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Escritório
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">
            Documentos e atalhos
          </h2>
          <p className="mt-2 text-sm leading-6 text-navy/60">
            Certificados, livro e RDO — mesmos PDFs do Drive.
          </p>
          <div className="mt-4">
            <OsDocActions
              osId={os.id}
              hasSlots={slotsCount > 0}
              hasRdos={rdos.length > 0}
              driveUrl={driveListing.folderUrl || drive.folderUrl}
              campoUrl={campoAppUrl()}
              showHubLink={false}
            />
          </div>
        </section>
      </div>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Certificados
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Por tipo nesta OS
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              {slotsCount} slot(s)
              {certRows.filter((r) => r.hasCalibration).length
                ? ` · ${certRows.filter((r) => r.hasCalibration).length} com calibração`
                : ""}
            </p>
          </div>
          {slotsCount > 0 ? (
            <div className="flex flex-wrap gap-3">
              <Link
                href={`/os/${os.id}/livro`}
                className="text-sm font-semibold text-navy/60 hover:text-navy"
              >
                Livro
              </Link>
              <Link
                href={`/os/${os.id}/certificados`}
                className="text-sm font-semibold text-navy/60 hover:text-navy"
              >
                Ver todos →
              </Link>
            </div>
          ) : null}
        </div>
        {groups.length === 0 ? (
          <p className="mt-6 rounded-2xl border border-dashed border-navy/15 px-4 py-10 text-center text-sm text-muted">
            Sem certificados nesta OS.
          </p>
        ) : (
          <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {groups.map((group) => {
              const withCalib = group.items.filter((r) => r.hasCalibration).length;
              return (
                <Link
                  key={group.kind}
                  href={`/os/${os.id}/certificados?kind=${encodeURIComponent(group.kind)}`}
                  className="rounded-2xl border border-navy/10 bg-paper/70 px-4 py-4 transition hover:border-brass/40"
                >
                  <p className="font-semibold text-navy">
                    {group.label} · {group.items.length}
                  </p>
                  <p className="mt-1 text-xs text-navy/45">{group.stats}</p>
                  <p className="mt-2 text-[11px] font-medium text-navy/50">
                    {withCalib}/{group.items.length} com calibração
                  </p>
                </Link>
              );
            })}
          </div>
        )}
      </section>

      <Panel>
        <h2 className="mb-1 font-serif text-xl text-navy">Enviar por e-mail</h2>
        <p className="mb-4 text-sm text-navy/60">
          Mesmo <code className="text-xs">sendmail</code> do app — corpo com
          links dos PDFs oficiais no Drive (sem reanexar base64).
        </p>
        <OsMailForm
          osId={os.id}
          osNumber={os.number}
          defaultBody={(() => {
            const fileGroups = driveFilesByKind(driveListing.files);
            const lines = [
              `Documentos da OS GS ${os.number} — ${os.clientName || ""}.`,
              "",
              driveListing.folderUrl
                ? `Pasta da OS: ${driveListing.folderUrl}`
                : "",
              ...fileGroups.rdos.map((f) => `RDO: ${f.name}\n${f.url}`),
              ...fileGroups.certificates
                .slice(0, 20)
                .map((f) => `Certificado: ${f.name}\n${f.url}`),
              ...fileGroups.books.map((f) => `Book: ${f.name}\n${f.url}`),
              "",
              "GS Soluções Técnicas",
            ].filter(Boolean);
            return lines.join("\n");
          })()}
        />
      </Panel>
    </div>
  );
}
