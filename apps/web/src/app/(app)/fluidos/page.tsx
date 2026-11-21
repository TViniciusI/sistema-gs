import { DataTable, PageHeader } from "@/components/ui";
import { listCampoFluids } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function FluidosPage() {
  const items = await listCampoFluids();

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Fluidos"
        description="Cadastro de fluidos usado nas calibrações do GS Campo."
      />
      <DataTable
        headers={["Fluido", "Densidade", "Viscosidade", "Temperatura"]}
        empty="Nenhum fluido cadastrado."
        rows={items.map((item) => [
          item.name,
          item.density || "—",
          item.viscosity || "—",
          item.temperature || "—",
        ])}
      />
    </div>
  );
}
