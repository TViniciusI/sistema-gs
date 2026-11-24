import { CatalogDeleteButton } from "@/components/qualidade/catalog-delete-button";
import { DataTable, PageHeader, Panel } from "@/components/ui";
import { listCampoFluids } from "@/lib/campo-data";
import { deleteFluidoAction, saveFluidoAction } from "./actions";
import { FluidoForm } from "./fluido-form";

export const dynamic = "force-dynamic";

export default async function FluidosPage() {
  const items = await listCampoFluids();

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Fluidos"
        description="Cadastro de fluidos — mesma planilha do GS Campo."
      />
      <Panel>
        <h2 className="mb-3 font-serif text-lg text-navy">Novo / atualizar</h2>
        <FluidoForm action={saveFluidoAction} />
      </Panel>
      <div className="mt-6">
        <DataTable
          headers={["Fluido", "Densidade", "Viscosidade", "Temperatura", ""]}
          empty="Nenhum fluido cadastrado."
          rows={items.map((item) => [
            item.name,
            item.density ||
              [item.raw.densityMin, item.raw.densityMax]
                .map((v) => String(v ?? "").trim())
                .filter(Boolean)
                .join(" a ") ||
              "—",
            item.viscosity ||
              [item.raw.viscosityMin, item.raw.viscosityMax]
                .map((v) => String(v ?? "").trim())
                .filter(Boolean)
                .join(" a ") ||
              "—",
            item.temperature || "—",
            <CatalogDeleteButton
              key={item.id}
              id={item.id}
              label={item.name}
              onDelete={deleteFluidoAction}
            />,
          ])}
        />
      </div>
    </div>
  );
}
