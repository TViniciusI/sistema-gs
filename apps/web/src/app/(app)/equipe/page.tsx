import { Button, DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listEmployees } from "@/lib/demo/queries";

export default function EquipePage() {
  const employees = listEmployees();

  return (
    <div>
      <PageHeader
        title="Equipe técnica"
        description="Quadro atual da GS, como na aba Equipe Técnica do RDO."
        action={<Button href="/equipe/novo">Novo integrante</Button>}
      />
      <DataTable
        headers={["Nome", "Cargo", "Telefone", "Campo"]}
        empty="Nenhum integrante."
        rows={employees.map((employee) => [
          employee.name,
          employee.title,
          employee.phone,
          <StatusPill
            key={employee.id}
            label={employee.field ? "Técnico" : "Escritório"}
            tone={employee.field ? "ok" : "neutral"}
          />,
        ])}
      />
    </div>
  );
}
