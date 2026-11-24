import Link from "next/link";
import { FluidosBoard } from "@/components/fluidos/fluidos-board";
import { PageHeader } from "@/components/ui";
import { listCampoFluids } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return String(value ?? "").trim();
}

export default async function FluidosPage() {
  const items = await listCampoFluids();

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Qualidade"
        title="Fluidos"
        description="Produtos da calibração — densidade, viscosidade e temperaturas de referência."
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
      <FluidosBoard
        items={items.map((item) => ({
          id: item.id,
          name: item.name,
          densityMin: text(item.raw.densityMin) || text(item.density),
          densityMax: text(item.raw.densityMax),
          viscosityMin: text(item.raw.viscosityMin) || text(item.viscosity),
          viscosityMax: text(item.raw.viscosityMax),
          densityRefTemp:
            text(item.raw.densityRefTemp) || text(item.temperature) || "20 °C",
          viscosityRefTemp: text(item.raw.viscosityRefTemp) || "40 °C",
          updatedAt: item.updatedAt,
        }))}
      />
    </div>
  );
}
