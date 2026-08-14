import Link from "next/link";
import { formatCnpj } from "@gs/shared";
import { Button, DataTable, PageHeader } from "@/components/ui";
import { listClients } from "@/lib/demo/queries";

export default function ClientesPage() {
  const clients = listClients();

  return (
    <div>
      <PageHeader
        title="Clientes"
        description="Contratantes e bases, no mesmo modelo da planilha de registro."
        action={<Button href="/clientes/novo">Novo cliente</Button>}
      />
      <DataTable
        headers={["Código", "Apelido", "Contratante", "CNPJ"]}
        empty="Nenhum cliente."
        rows={clients.map((client) => [
          <Link
            key={client.id}
            href={`/clientes/${client.id}`}
            className="text-navy hover:underline"
          >
            {client.code}
          </Link>,
          client.alias,
          client.legalName,
          formatCnpj(client.cnpj),
        ])}
      />
    </div>
  );
}
