import Link from "next/link";
import { CertificadosBoard } from "@/components/certificados/certificados-board";
import { PageHeader } from "@/components/ui";
import { listCampoCalibrations, stripDevTestPersonNames } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return String(value ?? "").trim();
}

export default async function CertificadosPage() {
  const items = await listCampoCalibrations();
  const withNumber = items.filter((item) => item.number.trim().length > 0);

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Qualidade"
        title="Certificados"
        description="Números emitidos/sincronizados do GS Campo — filtre por tipo, status, TAG e OS."
        action={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/calibracao"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Calibrações
            </Link>
            <Link
              href="/calibracao/revisao"
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Revisão de cadastro
            </Link>
          </div>
        }
      />
      <CertificadosBoard
        items={withNumber.map((item) => {
          const raw = item.raw;
          return {
            id: item.id,
            number: item.number,
            clientName: item.clientName,
            kind: item.kind,
            status: item.status,
            equipmentTag: item.equipmentTag || text(raw.equipmentTag),
            equipmentType: item.equipmentType || text(raw.equipmentType),
            serialNumber: text(raw.serialNumber),
            manufacturer: text(raw.manufacturer),
            model: text(raw.model),
            technicianName: stripDevTestPersonNames(
              text(raw.technicianName) || text(raw.fieldTechnicianName),
            ),
            calibrationDate: text(raw.calibrationDate),
            nextCalibrationDate: text(raw.nextCalibrationDate),
            osId: text(raw.osId),
            osNumber: text(raw.osNumber),
            site: text(raw.site),
            updatedAt: item.updatedAt,
          };
        })}
      />
    </div>
  );
}
