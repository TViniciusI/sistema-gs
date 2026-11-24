import Link from "next/link";
import { notFound } from "next/navigation";
import { CalibWorkbenchView } from "@/components/calibracao/calib-workbench";
import { PrintToolbar } from "@/components/os/print-toolbar";
import { PageHeader, StatusPill } from "@/components/ui";
import {
  buildCalibrationWorkbench,
  campoAppUrl,
  certificatesForOs,
  findDriveCertForNumber,
  getCampoCalibration,
  getCampoOrder,
  getCampoPublicCertificate,
  kindLabel,
  listCampoCalibrations,
  listCampoOsDriveFiles,
  publicCertUrl,
  resolveCampoOsNumber,
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

export default async function OsCertificadoDetailPage({
  params,
}: {
  params: Promise<{ id: string; slotId: string }>;
}) {
  const { id, slotId } = await params;
  const osNumber = await resolveCampoOsNumber(id);
  const [os, calibrations, drivePrefetch] = await Promise.all([
    getCampoOrder(id),
    listCampoCalibrations(),
    osNumber
      ? listCampoOsDriveFiles(osNumber)
      : Promise.resolve(null),
  ]);
  if (!os) notFound();
  const listing =
    drivePrefetch ?? (await listCampoOsDriveFiles(os.number));

  const rows = certificatesForOs(os, calibrations);
  const row =
    rows.find((r) => r.slot.id === slotId) ||
    rows.find((r) => r.job?.id === slotId) ||
    rows.find((r) => r.slot.certificateNumber === slotId);
  if (!row) notFound();

  const slot = row.slot;
  let job = row.job;
  const jobId = job?.id || slot.jobId;
  const [fullJob, publicCert] = await Promise.all([
    jobId ? getCampoCalibration(jobId) : Promise.resolve(null),
    row.hasCalibration
      ? getCampoPublicCertificate({
          number: slot.certificateNumber || job?.number,
          jobId: jobId || undefined,
          osId: os.id,
        })
      : Promise.resolve(null),
  ]);
  if (fullJob) job = fullJob;

  const consultUrl = publicCertUrl({
    number: slot.certificateNumber || job?.number || publicCert?.number,
    jobId: job?.id || slot.jobId,
    osId: os.id,
  });
  const drivePdf = findDriveCertForNumber(
    listing.files,
    slot.certificateNumber || job?.number || "",
  );
  const workbench = buildCalibrationWorkbench(job?.raw);

  return (
    <div className="space-y-6">
      <div className="no-print">
        <PageHeader
          eyebrow={kindLabel(slot.kind)}
          title={slot.certificateNumber || publicCert?.number || "Certificado"}
          description={
            publicCert
              ? publicCert.kindLabel
              : row.hasCalibration
                ? "Calibração na planilha — consulta pública indisponível no momento."
                : "Slot da OS ainda sem calibração preenchida no GS Campo."
          }
          action={
            <div className="flex flex-wrap items-center gap-2">
              <StatusPill
                label={
                  publicCert?.issued
                    ? "Emitido"
                    : row.hasCalibration
                      ? "Em emissão"
                      : "Sem calibração"
                }
                tone={
                  publicCert?.issued
                    ? "ok"
                    : row.hasCalibration
                      ? "warn"
                      : "neutral"
                }
              />
              {drivePdf ? (
                <a
                  href={drivePdf.url}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
                >
                  PDF Drive ↗
                </a>
              ) : null}
              <Link
                href={`/os/${os.id}/certificados?kind=${encodeURIComponent(slot.kind)}`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                Voltar
              </Link>
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

      <PrintToolbar
        title={`Certificado ${slot.certificateNumber || ""} · OS GS ${os.number}`}
      />

      {!row.hasCalibration ? (
        <section className="print-sheet rounded-3xl border border-navy/10 bg-white p-6 md:p-8">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            OS GS {os.number}
          </p>
          <h2 className="mt-2 font-serif text-3xl text-navy">
            {slot.certificateNumber || "Sem número"}
          </h2>
          <p className="mt-3 text-sm leading-6 text-navy/60">
            Este número existe na OS no app, mas ainda não há calibração
            sincronizada na planilha. Preencha o certificado no GS Campo e
            sincronize para aparecer aqui e na consulta pública.
          </p>
          <dl className="mt-6 grid gap-4 sm:grid-cols-2">
            <Field label="Tipo" value={kindLabel(slot.kind)} />
            <Field label="Cliente" value={os.clientName} />
            <Field label="TAG" value={slot.equipmentTag} />
            <Field label="N/S" value={slot.serialNumber} />
            <Field label="Fabricante" value={slot.manufacturer} />
            <Field label="Modelo" value={slot.model} />
          </dl>
        </section>
      ) : publicCert ? (
        <article className="print-sheet space-y-4">
          <section className="rounded-3xl border border-navy/10 bg-white p-6 text-center md:p-8">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              {publicCert.kindLabel}
            </p>
            <h2 className="mt-2 font-serif text-3xl text-navy">
              {publicCert.number || slot.certificateNumber}
            </h2>
            <p className="mt-3 text-sm text-navy/55">
              {publicCert.issued
                ? "✓ Certificado emitido"
                : "Certificado em emissão"}
            </p>
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
              <Field label="Solicitante" value={publicCert.serviceRequester} />
              <Field label="Local" value={publicCert.site} />
              <Field label="OS" value={publicCert.osNumber || os.number} />
            </dl>
          </section>

          <section className="rounded-3xl border border-navy/10 bg-white p-6">
            <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Instrumento calibrado
            </h3>
            <dl className="mt-4 grid gap-4 sm:grid-cols-2">
              <Field label="TAG" value={publicCert.equipmentTag || slot.equipmentTag} />
              <Field
                label="Tipo"
                value={publicCert.equipmentType || slot.equipmentType}
              />
              <Field
                label="Fabricante"
                value={publicCert.manufacturer || slot.manufacturer}
              />
              <Field label="Modelo" value={publicCert.model || slot.model} />
              <Field
                label="Nº de série"
                value={publicCert.serialNumber || slot.serialNumber}
              />
              <Field label="Princípio" value={publicCert.workingPrinciple} />
              <Field label="Instalação" value={publicCert.installLocation} />
              <Field
                label="Sistema"
                value={[publicCert.systemType, publicCert.systemTag]
                  .filter(Boolean)
                  .join(" · ")}
              />
              <Field label="Fluido" value={publicCert.fluid} />
            </dl>
          </section>

          <section className="rounded-3xl border border-navy/10 bg-white p-6">
            <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Calibração
            </h3>
            <dl className="mt-4 grid gap-4 sm:grid-cols-2">
              <Field label="Procedimento" value={publicCert.procedure} />
              <Field label="Responsável" value={publicCert.technicianName} />
              <Field label="Fator K encontrado" value={publicCert.kFactorFound} />
              <Field label="Fator K deixado" value={publicCert.kFactorLeft} />
            </dl>
          </section>

          {publicCert.standards.length > 0 ? (
            <section className="rounded-3xl border border-navy/10 bg-white p-6">
              <h3 className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
                Padrões utilizados
              </h3>
              <div className="mt-4 space-y-4">
                {publicCert.standards.map((s, i) => (
                  <dl
                    key={`${s.tag}-${i}`}
                    className="grid gap-3 border-t border-navy/8 pt-4 first:border-0 first:pt-0 sm:grid-cols-2"
                  >
                    <Field
                      label="Padrão"
                      value={[s.tag, s.description].filter(Boolean).join(" — ")}
                    />
                    <Field label="Nº de série" value={s.serialNumber} />
                    <Field label="Certificado" value={s.certificate} />
                    <Field label="Validade" value={s.validity} />
                    <Field label="Incerteza" value={s.uncertainty} />
                  </dl>
                ))}
              </div>
            </section>
          ) : null}

          {workbench.hasAny ? <CalibWorkbenchView data={workbench} /> : null}

          <div className="no-print">
            <a
              href={consultUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-flex rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
            >
              Abrir consulta pública ↗
            </a>
          </div>
        </article>
      ) : (
        <section className="print-sheet space-y-4">
          <div className="rounded-3xl border border-navy/10 bg-white p-6 md:p-8">
            <h2 className="font-serif text-2xl text-navy">
              {slot.certificateNumber || job?.number}
            </h2>
            <p className="mt-3 text-sm text-navy/60">
              Há registro na planilha ({job?.status || "—"}), mas a consulta
              pública ainda não retornou os dados. Confira o sync no GS Campo.
            </p>
            <dl className="mt-6 grid gap-4 sm:grid-cols-2">
              <Field
                label="Tipo"
                value={kindLabel(slot.kind || job?.kind || "")}
              />
              <Field label="Cliente" value={job?.clientName || os.clientName} />
              <Field
                label="TAG"
                value={job?.equipmentTag || slot.equipmentTag}
              />
              <Field
                label="Equipamento"
                value={job?.equipmentType || slot.equipmentType}
              />
              <Field label="Status" value={job?.status} />
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
          </div>
          {workbench.hasAny ? <CalibWorkbenchView data={workbench} /> : null}
        </section>
      )}
    </div>
  );
}
