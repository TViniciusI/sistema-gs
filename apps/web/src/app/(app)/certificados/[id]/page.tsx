import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintToolbar } from "@/components/os/print-toolbar";
import { PageHeader, StatusPill } from "@/components/ui";
import {
  campoAppUrl,
  getCampoCalibration,
  getCampoPublicCertificate,
  kindLabel,
  publicCertUrl,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function Field({ label, value }: { label: string; value?: string }) {
  const v = (value || "").trim();
  if (!v) return null;
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-wide text-navy/45">
        {label}
      </dt>
      <dd className="mt-1 text-sm font-medium text-navy">{v}</dd>
    </div>
  );
}

export default async function CertificadoDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const job = await getCampoCalibration(id);
  if (!job) notFound();

  const osId = String(job.raw.osId || "").trim();
  const publicCert = await getCampoPublicCertificate({
    number: job.number,
    jobId: job.id,
    osId: osId || undefined,
  });

  const consultUrl = publicCertUrl({
    number: job.number,
    jobId: job.id,
    osId: osId || undefined,
  });

  return (
    <div className="space-y-6">
      <div className="no-print">
        <PageHeader
          eyebrow={kindLabel(job.kind)}
          title={job.number}
          description={
            publicCert?.kindLabel ||
            "Certificado sincronizado do GS Campo."
          }
          action={
            <div className="flex flex-wrap items-center gap-2">
              <StatusPill
                label={
                  publicCert?.issued
                    ? "Emitido"
                    : job.status === "done"
                      ? "Concluído"
                      : job.status || "—"
                }
                tone={publicCert?.issued || job.status === "done" ? "ok" : "warn"}
              />
              <Link
                href="/certificados"
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                Voltar
              </Link>
              <Link
                href={`/calibracao/${encodeURIComponent(job.id)}`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                Calibração
              </Link>
              {osId ? (
                <Link
                  href={`/os/${osId}/certificados`}
                  className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
                >
                  OS
                </Link>
              ) : null}
              <a
                href={campoAppUrl()}
                target="_blank"
                rel="noreferrer"
                className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
              >
                Abrir no Campo ↗
              </a>
            </div>
          }
        />
      </div>

      <PrintToolbar title={`Certificado ${job.number}`} />

      {publicCert ? (
        <article className="print-sheet space-y-4">
          <section className="rounded-3xl border border-navy/10 bg-white p-6 text-center md:p-8">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              {publicCert.kindLabel}
            </p>
            <h2 className="mt-2 font-serif text-3xl text-navy">
              {publicCert.number || job.number}
            </h2>
            <div className="mt-6 grid gap-3 sm:grid-cols-2">
              <div className="rounded-2xl bg-paper px-4 py-3">
                <p className="text-[10px] uppercase tracking-wide text-navy/45">
                  Calibrado em
                </p>
                <p className="mt-1 font-serif text-xl text-navy">
                  {publicCert.calibrationDate || "—"}
                </p>
              </div>
              <div className="rounded-2xl bg-paper px-4 py-3">
                <p className="text-[10px] uppercase tracking-wide text-navy/45">
                  Próxima calibração
                </p>
                <p className="mt-1 font-serif text-xl text-navy">
                  {publicCert.nextCalibrationDate || "—"}
                </p>
              </div>
            </div>
          </section>

          <section className="rounded-3xl border border-navy/10 bg-white p-6">
            <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Cliente
            </h3>
            <dl className="mt-4 grid gap-4 sm:grid-cols-2">
              <Field label="Cliente" value={publicCert.clientName} />
              <Field label="Local" value={publicCert.site} />
              <Field label="OS" value={publicCert.osNumber} />
              <Field label="Responsável" value={publicCert.technicianName} />
            </dl>
          </section>

          <section className="rounded-3xl border border-navy/10 bg-white p-6">
            <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Instrumento
            </h3>
            <dl className="mt-4 grid gap-4 sm:grid-cols-2">
              <Field label="TAG" value={publicCert.equipmentTag} />
              <Field label="Tipo" value={publicCert.equipmentType} />
              <Field label="Fabricante" value={publicCert.manufacturer} />
              <Field label="Modelo" value={publicCert.model} />
              <Field label="N/S" value={publicCert.serialNumber} />
              <Field label="Fluido" value={publicCert.fluid} />
            </dl>
          </section>

          <div className="no-print">
            <a
              href={consultUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-flex rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
            >
              Consulta pública ↗
            </a>
          </div>
        </article>
      ) : (
        <section className="print-sheet rounded-3xl border border-navy/10 bg-white p-6">
          <h2 className="font-serif text-2xl text-navy">{job.number}</h2>
          <p className="mt-3 text-sm text-navy/60">
            Registro na planilha do Campo ({kindLabel(job.kind)} · {job.status}
            ). A consulta pública completa não retornou — confira se o
            certificado foi sincronizado.
          </p>
          <dl className="mt-6 grid gap-4 sm:grid-cols-2">
            <Field label="Cliente" value={job.clientName} />
            <Field label="TAG" value={job.equipmentTag} />
            <Field label="Equipamento" value={job.equipmentType} />
            <Field label="OS" value={String(job.raw.osNumber || "")} />
          </dl>
          <div className="no-print mt-6">
            <a
              href={consultUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-flex rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
            >
              Tentar consulta pública ↗
            </a>
          </div>
        </section>
      )}
    </div>
  );
}
