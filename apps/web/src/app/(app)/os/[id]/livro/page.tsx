import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintToolbar } from "@/components/os/print-toolbar";
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

export default async function OsLivroPage({
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
          PDF oficial no GS Campo ↗
        </a>
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
            {slots.length} slot(s) · {related.length} certificado(s) na planilha
          </p>

          <div className="mt-6 space-y-5">
            {groups.map((group) => (
              <section key={group.label}>
                <h3 className="border-b border-navy/10 pb-2 font-semibold text-navy">
                  {group.label} · {group.items.length}
                </h3>
                <ol className="mt-3 space-y-2">
                  {group.items.map((slot, index) => (
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
                      </span>
                      <a
                        href={publicCertUrl({
                          number: slot.certificateNumber,
                          id: slot.jobId || slot.id,
                          osId: os.id,
                        })}
                        className="text-xs text-navy/45 hover:text-navy"
                        target="_blank"
                        rel="noreferrer"
                      >
                        consulta pública
                      </a>
                    </li>
                  ))}
                </ol>
              </section>
            ))}
          </div>

          {related.length > 0 ? (
            <section className="mt-10">
              <h2 className="font-serif text-2xl text-navy">
                Certificados na planilha
              </h2>
              <ul className="mt-4 space-y-2">
                {related.map((item) => (
                  <li
                    key={item.id}
                    className="rounded-xl border border-navy/10 px-4 py-3 text-sm"
                  >
                    <span className="font-semibold text-navy">
                      {item.number}
                    </span>
                    <span className="text-navy/55">
                      {" "}
                      · {kindLabel(item.kind)} ·{" "}
                      {[item.equipmentTag, item.equipmentType]
                        .filter(Boolean)
                        .join(" · ") || "equipamento"}
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
