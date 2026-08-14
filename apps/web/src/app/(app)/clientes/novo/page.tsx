import { PageHeader, Panel } from "@/components/ui";
import { listClients, listLocations } from "@/lib/demo/queries";
import { ClientForm } from "./client-form";

export default function NovoClientePage() {
  const clients = listClients();
  const locations = listLocations();
  const nextCode =
    clients.reduce((max, client) => Math.max(max, client.code), 0) + 1;

  return (
    <div>
      <PageHeader
        title="Novo cliente"
        description="Informe o CNPJ para preencher razão social e apelido automaticamente."
      />
      <Panel>
        <ClientForm
          nextCode={nextCode}
          localRecords={clients.map((client) => {
            const location = locations.find(
              (item) => item.clientId === client.id,
            );
            return {
              cnpj: client.cnpj,
              razaoSocial: client.legalName,
              nomeFantasia: client.alias,
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
