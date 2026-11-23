import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import { PrintToolbar } from "@/components/os/print-toolbar";
import {
  campoAppUrl,
  certificatesForOs,
  getCampoOrder,
  groupCertificatesByKind,
  kindLabel,
  listCampoCalibrations,
  listCampoOsDriveFiles,
  publicCertUrl,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsLivroPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const [calibrations, driveListing] = await Promise.all([
    listCampoCalibrations(),
    listCampoOsDriveFiles(os.number),
  ]);

  const rows = certificatesForOs(os, calibrations);
  const groups = groupCertificatesByKind(rows);
  const withJob = rows.filter((r) => r.hasCalibration).length;

  return (
    <div>
      <div className="no-print mb-4 flex flex-wrap items-center justify-between gap-3">
        <Link
          href={`/os/${os.id}/documentos`}
          className="text-sm text-navy/60 hover:text-navy"
        >
          ← Documentos da OS
        </Link>
        <a
          href={campoAppUrl()}
          target="_blank"
          rel="noreferrer"
          className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-medium text-navy hover:bg-paper"
        >
          Gerar book no GS Campo ↗
        </a>
      </div>

      <div className="no-print mb-6">
        <OsDrivePanel listing={driveListing} focus="book" />
      </div>

      <PrintToolbar title={`Livro de certificados · OS GS ${os.number}`} />

      <article className="print-sheet overflow-hidden rounded-3xl border border-navy/10 bg-white shadow-[0_12px_32px_rgba(12,31,51,0.06)]">
        <header className="bg-navy px-8 py-10 text-paper">
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-brass">
            GS Soluções Técnicas
          </p>
          <h1 className="mt-4 font-serif text-4xl leading-tight">
            Livro de certificados
          </h1>
          <p className="mt-3 text-lg text-paper/70">OS GS {os.number}</p>
          <p className="mt-6 max-w-2xl text-sm leading-7 text-paper/65">
            {os.clientName || "Cliente"}
            {os.technicianName ? ` · ${os.technicianName}` : ""}
            {os.startsAt
              ? ` · ${new Date(os.startsAt).toLocaleDateString("pt-BR")}`
              : ""}
          </p>
        </header>

        <div className="px-8 py-8">
          <h2 className="font-serif text-2xl text-navy">Sumário</h2>
          <p className="mt-2 text-sm text-navy/55">
            {rows.length} certificado(s) · {withJob} com calibração na planilha
          </p>

          <div className="mt-6 space-y-5">
            {groups.map((group) => (
              <section key={group.kind}>
                <h3 className="border-b border-navy/10 pb-2 font-semibold text-navy">
                  {group.label} · {group.items.length}
                  <span className="ml-2 text-sm font-normal text-navy/45">
                    {group.stats}
                  </span>
                </h3>
                <ol className="mt-3 space-y-2">
                  {group.items.map((row, index) => {
                    const slot = row.slot;
                    const consult = publicCertUrl({
                      number: slot.certificateNumber || row.job?.number,
                      jobId: row.job?.id || slot.jobId,
                      osId: os.id,
                    });
                    return (
                      <li
                        key={slot.id}
                        className="flex flex-wrap items-baseline justify-between gap-2 text-sm"
                      >
                        <span className="text-navy">
                          {index + 1}. Cert. {slot.certificateNumber || "—"}
                          {slot.equipmentTag
                            ? ` · TAG ${slot.equipmentTag}`
                            : ""}
                          {slot.serialNumber
                            ? ` · N/S ${slot.serialNumber}`
                            : ""}
                          {!row.hasCalibration ? (
                            <span className="text-warn"> · sem calibração</span>
                          ) : null}
                        </span>
                        {row.hasCalibration ? (
                          <Link
                            href={`/os/${os.id}/certificados/${encodeURIComponent(slot.id)}`}
                            className="text-xs text-navy/45 hover:text-navy"
                          >
                            ver no sistema
                          </Link>
                        ) : (
                          <a
                            href={consult}
                            className="text-xs text-navy/35"
                            target="_blank"
                            rel="noreferrer"
                          >
                            consulta
                          </a>
                        )}
                      </li>
                    );
                  })}
                </ol>
              </section>
            ))}
          </div>

          {withJob > 0 ? (
            <section className="mt-10">
              <h2 className="font-serif text-2xl text-navy">
                Com calibração na planilha
              </h2>
              <ul className="mt-4 space-y-2">
                {rows
                  .filter((r) => r.hasCalibration && r.job)
                  .map((row) => (
                    <li
                      key={row.job!.id}
                      className="rounded-xl border border-navy/10 px-4 py-3 text-sm"
                    >
                      <span className="font-semibold text-navy">
                        {row.job!.number || row.slot.certificateNumber}
                      </span>
                      <span className="text-navy/55">
                        {" "}
                        · {kindLabel(row.job!.kind || row.slot.kind)} ·{" "}
                        {row.job!.status}
                      </span>
                    </li>
                  ))}
              </ul>
            </section>
          ) : null}
        </div>
      </article>
    </div>
  );
}
