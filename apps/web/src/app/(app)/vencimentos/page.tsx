import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listStandards } from "@/lib/demo/queries";

export default function VencimentosPage() {
  const standards = listStandards();

  return (
    <div>
      <PageHeader
        title="Vencimentos"
        description="Padrões de calibração da GS. Um padrão vencido bloqueia a emissão do certificado."
      />
      <DataTable
        headers={["Identificação", "Descrição", "Laboratório", "Certificado", "Validade", "Situação"]}
        empty="Nenhum padrão."
        rows={standards.map((item) => [
          item.code,
          item.description,
          item.lab,
          item.cert,
          new Date(`${item.expiresAt}T00:00:00`).toLocaleDateString("pt-BR"),
          <StatusPill
            key={item.id}
            label={
              item.status === "ok"
                ? "Ativo"
                : item.status === "due"
                  ? "A vencer"
                  : "Vencido"
            }
            tone={item.status === "ok" ? "ok" : "warn"}
          />,
        ])}
      />
    </div>
  );
}
