import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintToolbar } from "@/components/os/print-toolbar";
import {
  getCampoOrder,
  kindLabel,
  parseOsCalibrationSlots,
  publicCertUrl,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function OsEtiquetasPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();
  const slots = parseOsCalibrationSlots(os).filter(
    (s) => s.certificateNumber || s.serialNumber || s.equipmentTag,
  );

  return (
    <div>
      <div className="no-print mb-4">
        <Link href={`/os/${os.id}/documentos`} className="text-sm text-navy/60 hover:text-navy">
          ← Documentos da OS
        </Link>
      </div>
      <PrintToolbar title={`Etiquetas · OS GS ${os.number}`} />

      {slots.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-10 text-center text-sm text-muted">
          Nenhum slot com dados para etiqueta.
        </p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 print:grid-cols-3">
          {slots.map((slot) => {
            const qr = publicCertUrl({
              number: slot.certificateNumber,
              id: slot.jobId || slot.id,
              osId: os.id,
            });
            const date =
              slot.labelDate ||
              (os.startsAt
                ? new Date(os.startsAt).toLocaleDateString("pt-BR")
                : "");
            return (
              <article
                key={slot.id}
                className="label-sheet flex aspect-[40/60] max-w-[240px] flex-col justify-between rounded-xl border-2 border-navy bg-white p-3 text-navy shadow-sm"
              >
                <div>
                  <p className="text-[9px] font-bold uppercase tracking-[0.14em]">
                    {kindLabel(slot.kind).toUpperCase()}
                  </p>
                  <p className="mt-2 font-serif text-lg leading-tight">
                    Cert. {slot.certificateNumber || "—"}
                  </p>
                  <p className="mt-2 text-[11px] leading-snug">
                    {os.clientName || "Cliente"}
                  </p>
                </div>
                <div className="space-y-1 text-[11px]">
                  {slot.equipmentTag ? <p>TAG {slot.equipmentTag}</p> : null}
                  {slot.serialNumber ? <p>N/S {slot.serialNumber}</p> : null}
                  {date ? <p>Calibração {date}</p> : null}
                  <p className="break-all text-[8px] text-navy/50">{qr}</p>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
