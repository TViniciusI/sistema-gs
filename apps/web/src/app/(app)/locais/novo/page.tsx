import { PageHeader, Panel } from "@/components/ui";
import { listClients, listLocations } from "@/lib/demo/queries";
import { LocationForm } from "./location-form";

export default function NovoLocalPage() {
  const clients = listClients();
  const locations = listLocations();

  return (
    <div>
      <PageHeader
        title="Novo local"
        description="Informe o CNPJ para preencher endereço, cidade e UF automaticamente."
      />
      <Panel>
        <LocationForm
          clients={clients.map((client) => ({
            id: client.id,
            label: `${client.legalName} (${client.alias})`,
            cnpj: client.cnpj,
          }))}
          localRecords={clients.map((client) => {
            const location = locations.find(
              (item) => item.clientId === client.id,
            );
            return {
              cnpj: client.cnpj,
              razaoSocial: client.legalName,
              nomeFantasia: location?.alias || client.alias,
              endereco: location?.address ?? "",
              cidade: location?.city ?? "",
              estado: location?.state ?? "",
              telefone: client.manager.phone,
              email: client.manager.email,
              clientId: client.id,
            };
          })}
        />
      </Panel>
    </div>
  );
}
