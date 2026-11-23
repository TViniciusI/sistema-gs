import Link from "next/link";
import { notFound } from "next/navigation";
import { OsDocActions } from "@/components/os/os-doc-actions";
import { PageHeader, StatusPill } from "@/components/ui";
import { OsDrivePanel } from "@/components/os/os-drive-panel";
import {
  campoAppUrl,
  certificatesForOs,
  getCampoDriveStatus,
  getCampoOrder,
  groupCertificatesByKind,
  kindLabel,
  listCampoCalibrations,
  listCampoOsDriveFiles,
  parseOsCalibrationSlots,
  parseOsRdos,
} from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function OsDocumentosPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const [calibrations, drive, driveListing] = await Promise.all([
    listCampoCalibrations(),
    getCampoDriveStatus(),
    listCampoOsDriveFiles(os.number),
  ]);

  const slots = parseOsCalibrationSlots(os);
  const rdos = parseOsRdos(os);
  const certRows = certificatesForOs(os, calibrations);
  const groups = groupCertificatesByKind(certRows);
  const withCalibration = certRows.filter((r) => r.hasCalibration).length;
  const emptySlots = slots.filter(
    (s) => !s.serialNumber.trim() && !s.equipmentTag.trim(),
  ).length;

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Documentos da OS"
        title={`OS GS ${os.number}`}
        description="Certificados, livro e RDO — mesmo hub do GS Campo, no escritório."
        action={
          <div className="flex flex-wrap items-center gap-2">
            <StatusPill
              label={campoOsStatusLabel(os.status)}
              tone={campoOsStatusTone(os.status)}
            />
            <Link
              href={`/os/${os.id}`}
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar à OS
            </Link>
          </div>
        }
      />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Cliente
        </p>
        <h2 className="mt-1 font-serif text-2xl text-navy">
          {os.clientName || "—"}
        </h2>
        <p className="mt-2 text-sm text-navy/55">
          {os.technicianName || "Sem técnico"}
          {os.startsAt
            ? ` · Início ${new Date(os.startsAt).toLocaleDateString("pt-BR")}`
            : ""}
        </p>
        <p className="mt-4 max-w-3xl text-sm leading-6 text-navy/60">
          Os certificados oficiais (PDF) são os mesmos gerados no GS Campo e
          salvos no Google Drive. Aqui você lê a planilha, abre os PDFs e
          imprime o Relatório de Serviço.
        </p>
      </section>

      <OsDrivePanel listing={driveListing} />

      <div className="grid gap-6 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Calibração nesta OS
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">Ações</h2>
          <div className="mt-4">
            <OsDocActions
              osId={os.id}
              hasSlots={slots.length > 0}
              hasRdos={rdos.length > 0}
              driveUrl={driveListing.folderUrl || drive.folderUrl}
              campoUrl={campoAppUrl()}
              showHubLink={false}
            />
          </div>
          <div className="mt-4 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-xl bg-paper px-2 py-3">
              <p className="font-serif text-2xl text-navy">{slots.length}</p>
              <p className="text-[10px] uppercase tracking-wide text-navy/45">
                Slots
              </p>
            </div>
            <div className="rounded-xl bg-paper px-2 py-3">
              <p className="font-serif text-2xl text-navy">{withCalibration}</p>
              <p className="text-[10px] uppercase tracking-wide text-navy/45">
                Com calib.
              </p>
            </div>
            <div className="rounded-xl bg-paper px-2 py-3">
              <p className="font-serif text-2xl text-navy">{rdos.length}</p>
              <p className="text-[10px] uppercase tracking-wide text-navy/45">
                RDOs
              </p>
            </div>
          </div>
          {emptySlots > 0 ? (
            <p className="mt-3 text-xs text-warn">
              {emptySlots} slot(s) sem TAG/N/S — limpe no GS Campo se for lixo de
              cadastro.
            </p>
          ) : null}
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
              Nenhum slot nesta OS. Crie/preencha no GS Campo ou ao gerar a OS
              com calibração.
            </p>
          ) : (
            <div className="mt-4 space-y-3">
              {groups.map((group) => (
                <div
                  key={group.kind}
                  className="rounded-2xl border border-navy/10 bg-paper/70 px-4 py-3"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="font-semibold text-navy">
                        {group.label} · {group.items.length}
                      </p>
                      <p className="mt-0.5 text-xs text-navy/45">
                        {group.stats}
                      </p>
                    </div>
                    <Link
                      href={`/os/${os.id}/certificados?kind=${encodeURIComponent(group.kind)}`}
                      className="text-xs font-medium text-navy/55 hover:text-navy"
                    >
                      Ver →
                    </Link>
                  </div>
                  <ul className="mt-2 space-y-1.5">
                    {group.items.slice(0, 6).map((row) => (
                      <li
                        key={row.slot.id}
                        className="flex flex-wrap items-center justify-between gap-2 text-sm text-navy/70"
                      >
                        <Link
                          href={`/os/${os.id}/certificados/${encodeURIComponent(row.slot.id)}`}
                          className="hover:text-navy"
                        >
                          {row.slot.certificateNumber || "Sem nº"}
                          {row.slot.equipmentTag
                            ? ` · TAG ${row.slot.equipmentTag}`
                            : ""}
                          {row.slot.serialNumber
                            ? ` · N/S ${row.slot.serialNumber}`
                            : ""}
                        </Link>
                        <span className="text-[11px] uppercase tracking-wide text-navy/40">
                          {row.hasCalibration
                            ? "com calibração"
                            : kindLabel(row.slot.kind)}
                        </span>
                      </li>
                    ))}
                    {group.items.length > 6 ? (
                      <li className="text-xs text-navy/45">
                        +{group.items.length - 6} itens
                      </li>
                    ) : null}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
