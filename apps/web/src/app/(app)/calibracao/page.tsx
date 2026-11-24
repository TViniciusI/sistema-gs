import Link from "next/link";
import { CalibracaoBoard } from "@/components/calibracao/calibracao-board";
import { PageHeader } from "@/components/ui";
import { listCampoCalibrations } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function CalibracaoPage() {
  const items = await listCampoCalibrations();

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Qualidade"
        title="Calibração"
        description="Pontos, Mf, incerteza, padrões — edite aqui ou no app; savecalib grava na mesma planilha."
        action={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/calibracao/nova"
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Nova calibração
            </Link>
            <Link
              href="/calibracao/revisao"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Revisão de cadastro
            </Link>
          </div>
        }
      />
      <CalibracaoBoard
        items={items.map((item) => ({
          id: item.id,
          number: item.number,
          clientName: item.clientName,
          equipmentTag: item.equipmentTag,
          equipmentType: item.equipmentType,
          kind: item.kind,
          status: item.status,
          updatedAt: item.updatedAt,
        }))}
      />
    </div>
  );
}
