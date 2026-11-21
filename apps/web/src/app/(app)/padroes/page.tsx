import { DataTable, PageHeader } from "@/components/ui";
import { listCampoStandards } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function PadroesPage() {
  const items = await listCampoStandards();

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Padrões"
        description="Padrões de referência do app — validade e certificado."
      />
      <DataTable
        headers={["Código / nome", "Tipo", "N/S", "Certificado", "Validade"]}
        empty="Nenhum padrão cadastrado."
        rows={items.map((item) => [
          item.name,
          item.type || "—",
          item.serial || "—",
          item.certificate || "—",
          item.validity
            ? new Date(item.validity).toLocaleDateString("pt-BR")
            : "—",
        ])}
      />
    </div>
  );
}
