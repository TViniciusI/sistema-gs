import Link from "next/link";
import { notFound } from "next/navigation";
import { OsCertificadosBoard } from "@/components/certificados/os-certificados-board";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import { PageHeader } from "@/components/ui";
import {
  campoAppUrl,
  certificatesForOs,
  findDriveCertForNumber,
  getCampoOrder,
  groupCertificatesByKind,
  listCampoCalibrations,
  listCampoOsDriveFiles,
  resolveCampoOsNumber,
  stripDevTestPersonNames,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return String(value ?? "").trim();
}

export default async function OsCertificadosPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ kind?: string }>;
}) {
  const { id } = await params;
  const { kind: kindFilter } = await searchParams;
  const osNumber = await resolveCampoOsNumber(id);
  const [os, calibrations, drivePrefetch] = await Promise.all([
    getCampoOrder(id),
    listCampoCalibrations(),
    osNumber
      ? listCampoOsDriveFiles(osNumber)
      : Promise.resolve(null),
  ]);
  if (!os) notFound();
  const driveListing =
    drivePrefetch ?? (await listCampoOsDriveFiles(os.number));

  const rows = certificatesForOs(os, calibrations);
  const groups = groupCertificatesByKind(rows);
  const withCalib = rows.filter((r) => r.hasCalibration).length;

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Calibração"
        title={`Certificados · OS GS ${os.number}`}
        description={
          [
            os.clientName,
            `${rows.length} certificado(s)`,
            withCalib ? `${withCalib} com calibração` : null,
          ]
            .filter(Boolean)
            .join(" · ") ||
          "Slots da OS — volumétrica, temperatura, densidade e demais tipos."
        }
        action={
          <div className="flex flex-wrap gap-2">
            <Link
              href={`/os/${os.id}`}
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar à OS
            </Link>
            <Link
              href={`/os/${os.id}/livro`}
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Livro
            </Link>
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

      <section className="rounded-3xl border border-navy/10 bg-gradient-to-br from-white via-white to-paper p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Organização
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Por tipo · status · PDF
        </h2>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-navy/60">
          Use os chips de tipo para focar (vazão, temperatura, densidade…). O PDF
          oficial continua sendo o gerado no GS Campo e salvo no Drive; aqui
          você acompanha número, instrumento, datas e abre a bancada.
        </p>
      </section>

      <OsDrivePanel listing={driveListing} focus="certificates" />

      <OsCertificadosBoard
        osId={os.id}
        initialKind={kindFilter?.trim() || ""}
        groups={groups.map((group) => ({
          kind: group.kind,
          label: group.label,
          stats: group.stats,
          items: group.items.map((row) => {
            const slot = row.slot;
            const job = row.job;
            const pdf = findDriveCertForNumber(
              driveListing.files,
              slot.certificateNumber || job?.number || "",
            );
            const raw = (job?.raw || {}) as Record<string, unknown>;
            return {
              slotId: slot.id,
              kind: slot.kind || group.kind,
              certificateNumber: slot.certificateNumber || job?.number || "",
              equipmentTag: slot.equipmentTag || job?.equipmentTag || "",
              equipmentType: slot.equipmentType || job?.equipmentType || "",
              serialNumber: slot.serialNumber || text(raw.serialNumber),
              manufacturer: slot.manufacturer || text(raw.manufacturer),
              model: slot.model || text(raw.model),
              installLocation: slot.installLocation || text(raw.site),
              jobStatus: job?.status || "",
              hasCalibration: row.hasCalibration,
              hasPdf: Boolean(pdf),
              pdfUrl: pdf?.url || "",
              calibrationDate: text(raw.calibrationDate),
              nextCalibrationDate: text(raw.nextCalibrationDate),
              technicianName: stripDevTestPersonNames(
                text(raw.technicianName) || text(raw.fieldTechnicianName),
              ),
              jobId: job?.id || "",
            };
          }),
        }))}
      />
    </div>
  );
}
