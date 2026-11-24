import Link from "next/link";
import { PadroesBoard } from "@/components/padroes/padroes-board";
import { PageHeader } from "@/components/ui";
import { listCampoStandards } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return String(value ?? "").trim();
}

export default async function PadroesPage() {
  const items = await listCampoStandards();

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Qualidade"
        title="Padrões"
        description="Cadastro usado nas calibrações — filtre por tipo e validade, edite no card."
        action={
          <div className="flex flex-wrap gap-2">
            <Link
              href="/vencimentos"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Vencimentos
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
      <PadroesBoard
        items={items.map((item) => ({
          id: item.id,
          name: item.name,
          type: item.type,
          serial: item.serial,
          certificate: item.certificate,
          validity: item.validity,
          uncertainty: text(item.raw.uncertainty),
          coverageK: text(item.raw.coverageK) || text(item.raw.coverageFactor),
          updatedAt: item.updatedAt,
          updatedByName:
            text(item.raw.updatedByName) ||
            text(item.raw.updatedBy) ||
            text(item.raw.updatedByEmail),
        }))}
      />
    </div>
  );
}
