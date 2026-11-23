import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintToolbar } from "@/components/os/print-toolbar";
import { PageHeader } from "@/components/ui";
import {
  calibrationsForOs,
  campoAppUrl,
  getCampoOrder,
  groupSlotsByKind,
  kindLabel,
  listCampoCalibrations,
  parseOsCalibrationSlots,
  publicCertUrl,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsCertificadosPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [os, calibrations] = await Promise.all([
    getCampoOrder(id),
    listCampoCalibrations(),
  ]);
  if (!os) notFound();

  const slots = parseOsCalibrationSlots(os);
  const groups = groupSlotsByKind(slots);
  const related = calibrationsForOs(os, calibrations);

  return (
    <div className="space-y-6">
      <div className="no-print">
        <PageHeader
          eyebrow="Calibração"
          title={`Certificados · OS GS ${os.number}`}
          description="Preencha no GS Campo; no escritório confira, imprima a folha e abra a consulta pública."
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
                Gerar no GS Campo ↗
              </a>
            </div>
          }
        />
      </div>

      <PrintToolbar title={`Folha de certificados · OS GS ${os.number}`} />

      <section className="print-sheet rounded-3xl border border-navy/10 bg-white p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          {os.clientName || "Cliente"}
        </p>
        <h2 className="mt-1 font-serif text-2xl text-navy">
          Certificados da OS GS {os.number}
        </h2>

        <div className="mt-6 space-y-6">
          {groups.map((group) => (
            <div key={group.label}>
              <h3 className="font-semibold text-navy">
                {group.label} · {group.items.length}
              </h3>
              <div className="mt-3 grid gap-3 md:grid-cols-2">
                {group.items.map((slot) => (
                  <article
                    key={slot.id}
                    className="rounded-2xl border border-navy/10 bg-paper/60 px-4 py-4"
                  >
                    <p className="font-serif text-xl text-navy">
                      {slot.certificateNumber || "Sem número"}
                    </p>
                    <p className="mt-1 text-sm text-navy/60">
                      {[slot.equipmentTag && `TAG ${slot.equipmentTag}`, slot.serialNumber && `N/S ${slot.serialNumber}`, slot.manufacturer, slot.model]
                        .filter(Boolean)
                        .join(" · ") || kindLabel(slot.kind)}
                    </p>
                    <div className="no-print mt-3 flex flex-wrap gap-2">
                      <a
                        href={publicCertUrl({
                          number: slot.certificateNumber,
                          id: slot.jobId || slot.id,
                          osId: os.id,
                        })}
                        target="_blank"
                        rel="noreferrer"
                        className="rounded-lg border border-navy/15 bg-white px-3 py-1.5 text-xs font-medium text-navy hover:border-brass/40"
                      >
                        Consulta pública
                      </a>
                    </div>
                  </article>
                ))}
              </div>
            </div>
          ))}
        </div>

        {related.length > 0 ? (
          <div className="mt-8 border-t border-navy/10 pt-6">
            <h3 className="font-serif text-xl text-navy">
              Registros na planilha
            </h3>
            <ul className="mt-3 space-y-2">
              {related.map((item) => (
                <li
                  key={item.id}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-navy/10 px-3 py-2 text-sm"
                >
                  <span>
                    <span className="font-semibold text-navy">{item.number}</span>
                    <span className="text-navy/55">
                      {" "}
                      · {kindLabel(item.kind)} · {item.status}
                    </span>
                  </span>
                  <Link
                    href="/calibracao"
                    className="no-print text-xs font-medium text-navy/50 hover:text-navy"
                  >
                    Calibração →
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </section>
    </div>
  );
}
