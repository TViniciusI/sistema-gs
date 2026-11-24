import Link from "next/link";
import { VencimentosBoard } from "@/components/vencimentos/vencimentos-board";
import { PageHeader } from "@/components/ui";
import { listCampoStandards } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return String(value ?? "").trim();
}

export default async function VencimentosPage() {
  const standards = await listCampoStandards();

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Qualidade"
        title="Vencimentos"
        description="Padrões vencidos ou a vencer — priorize a recalibração antes da próxima OS."
        action={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/padroes"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Padrões
            </Link>
            <Link
              href="/calibracao"
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Calibração
            </Link>
          </div>
        }
      />
      <VencimentosBoard
        items={standards.map((item) => ({
          id: item.id,
          name: item.name,
          type: item.type,
          serial: item.serial,
          certificate: item.certificate,
          validity: item.validity,
          uncertainty: text(item.raw.uncertainty),
          coverageK: text(item.raw.coverageK) || text(item.raw.k),
        }))}
      />
    </div>
  );
}
