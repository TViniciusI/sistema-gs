import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import { PageHeader } from "@/components/ui";
import {
  campoAppUrl,
  certificatesForOs,
  findDriveCertForNumber,
  getCampoOrder,
  groupCertificatesByKind,
  kindLabel,
  listCampoCalibrations,
  listCampoOsDriveFiles,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsCertificadosPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ kind?: string }>;
}) {
  const { id } = await params;
  const { kind: kindFilter } = await searchParams;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const [calibrations, driveListing] = await Promise.all([
    listCampoCalibrations(),
    listCampoOsDriveFiles(os.number),
  ]);

  const rows = certificatesForOs(os, calibrations);
  const groups = groupCertificatesByKind(rows);
  const activeKind = kindFilter?.trim() || "";
  const activeGroup = activeKind
    ? groups.find((g) => g.kind === activeKind)
    : null;

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Calibração"
        title={
          activeGroup
            ? `${activeGroup.label} · OS GS ${os.number}`
            : `Tipo · OS GS ${os.number}`
        }
        description={
          activeGroup
            ? activeGroup.stats
            : "Certificados da OS lidos do GS Campo (volumétrica, temperatura, densidade e demais tipos)."
        }
        action={
          <div className="flex flex-wrap gap-2">
            {activeGroup ? (
              <Link
                href={`/os/${os.id}/certificados`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                ← Tipos
              </Link>
            ) : (
              <Link
                href={`/os/${os.id}/documentos`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                Documentos
              </Link>
            )}
            <a
              href={campoAppUrl()}
              target="_blank"
              rel="noreferrer"
              className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
            >
              Preencher no GS Campo ↗
            </a>
          </div>
        }
      />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          {os.clientName || "Cliente"}
        </p>
        <p className="mt-1 text-sm text-navy/55">
          {rows.length} certificado(s) na OS
          {rows.filter((r) => r.hasCalibration).length > 0
            ? ` · ${rows.filter((r) => r.hasCalibration).length} com calibração na planilha`
            : ""}
        </p>
        <p className="mt-3 text-sm leading-6 text-navy/60">
          O PDF oficial (layout Flutter) é gerado no GS Campo e fica no Drive.
          Aqui você vê todos os números da OS e abre os PDFs já emitidos.
        </p>
      </section>

      <OsDrivePanel listing={driveListing} focus="certificates" />

      {rows.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
          Nenhum certificado nesta OS. Crie os slots no GS Campo (volumétrica,
          temperatura, densidade…).
        </p>
      ) : activeGroup ? (
        <div className="space-y-2">
          {activeGroup.items.map((row) => {
            const slot = row.slot;
            const href = `/os/${os.id}/certificados/${encodeURIComponent(slot.id)}`;
            const pdf = findDriveCertForNumber(
              driveListing.files,
              slot.certificateNumber || row.job?.number || "",
            );
            return (
              <div
                key={slot.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-navy/10 bg-white px-4 py-4"
              >
                <Link href={href} className="min-w-0 flex-1 hover:opacity-90">
                  <p className="font-serif text-xl text-navy">
                    {slot.certificateNumber || "Sem número"}
                  </p>
                  <p className="mt-1 truncate text-sm text-navy/55">
                    {[
                      slot.equipmentTag && `TAG ${slot.equipmentTag}`,
                      slot.serialNumber && `N/S ${slot.serialNumber}`,
                      row.job?.status,
                    ]
                      .filter(Boolean)
                      .join(" · ") || kindLabel(slot.kind)}
                  </p>
                </Link>
                <div className="flex shrink-0 flex-wrap items-center gap-2">
                  {pdf ? (
                    <a
                      href={pdf.url}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-lg bg-navy px-3 py-1.5 text-[11px] font-semibold uppercase tracking-wide text-brass hover:bg-navy-2"
                    >
                      PDF Drive
                    </a>
                  ) : null}
                  <span
                    className={[
                      "rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-wide",
                      row.hasCalibration
                        ? "bg-ok/15 text-ok"
                        : "bg-warn/15 text-warn",
                    ].join(" ")}
                  >
                    {row.hasCalibration ? "Com calibração" : "Sem calibração"}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="space-y-2">
          {groups.map((group) => (
            <Link
              key={group.kind}
              href={`/os/${os.id}/certificados?kind=${encodeURIComponent(group.kind)}`}
              className="flex items-center justify-between gap-3 rounded-2xl border border-navy/10 bg-white px-4 py-4 transition hover:border-brass/40"
            >
              <div>
                <p className="font-semibold text-navy">{group.label}</p>
                <p className="mt-1 text-sm text-navy/55">{group.stats}</p>
              </div>
              <span aria-hidden className="text-navy/35">
                →
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
