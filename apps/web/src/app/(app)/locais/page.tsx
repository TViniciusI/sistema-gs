import { Button, DataTable, PageHeader } from "@/components/ui";
import { listLocations } from "@/lib/demo/queries";

export default function LocaisPage() {
  const locations = listLocations();

  return (
    <div>
      <PageHeader
        title="Locais de atendimento"
        description="Bases e plantas — o apelido é o que o técnico vê no campo."
        action={<Button href="/locais/novo">Novo local</Button>}
      />
      <DataTable
        headers={["Apelido", "Cliente", "Endereço", "Cidade"]}
        empty="Nenhum local."
        rows={locations.map((location) => [
          location.alias,
          location.client?.legalName ?? "—",
          location.address,
          `${location.city}/${location.state}`,
        ])}
      />
    </div>
  );
}
