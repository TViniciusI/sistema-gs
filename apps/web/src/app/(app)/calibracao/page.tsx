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
        description="Pontos, Mf, incerteza, padrões e fluido — mesma planilha do GS Campo (getcalib)."
        action={
          <Link
            href="/calibracao/revisao"
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Revisão de cadastro
          </Link>
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
