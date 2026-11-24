import { CatalogDeleteButton } from "@/components/qualidade/catalog-delete-button";
import { DataTable, PageHeader, Panel } from "@/components/ui";
import { listCampoStandards } from "@/lib/campo-data";
import { deletePadraoAction, savePadraoAction } from "./actions";
import { PadraoForm } from "./padrao-form";

export const dynamic = "force-dynamic";

export default async function PadroesPage() {
  const items = await listCampoStandards();

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Padrões"
        description="Cadastro de padrões — mesma planilha do GS Campo."
      />
      <Panel>
        <h2 className="mb-3 font-serif text-lg text-navy">Novo / atualizar</h2>
        <PadraoForm action={savePadraoAction} />
      </Panel>
      <div className="mt-6">
        <DataTable
          headers={[
            "Código / nome",
            "Tipo",
            "N/S",
            "Certificado",
            "Validade",
            "",
          ]}
          empty="Nenhum padrão cadastrado."
          rows={items.map((item) => [
            item.name,
            item.type || "—",
            item.serial || "—",
            item.certificate || "—",
            item.validity
              ? new Date(item.validity).toLocaleDateString("pt-BR", {
                  timeZone: "America/Sao_Paulo",
                })
              : "—",
            <CatalogDeleteButton
              key={item.id}
              id={item.id}
              label={item.name}
              onDelete={deletePadraoAction}
            />,
          ])}
        />
      </div>
    </div>
  );
}
