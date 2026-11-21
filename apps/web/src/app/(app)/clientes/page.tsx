import Link from "next/link";
import { formatCnpj } from "@gs/shared";
import { DataTable, PageHeader } from "@/components/ui";
import { listCampoClients } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function ClientesPage() {
  const clients = await listCampoClients();

  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Clientes e sistemas"
        description="Cadastro compartilhado com o GS Campo — sistemas, instrumentos e bases."
      />
      <DataTable
        headers={["Cliente", "CNPJ", "Sistemas", "Cidade", "Atualizado"]}
        empty="Nenhum cliente na planilha."
        rows={clients.map((client) => [
          <Link
            key={client.id}
            href={`/clientes/${client.id}`}
            className="font-medium text-navy hover:underline"
          >
            {client.name}
            {client.payloadLight ? (
              <span className="ml-2 text-[11px] font-normal text-muted">
                (resumo)
              </span>
            ) : null}
          </Link>,
          client.cnpj ? formatCnpj(client.cnpj) : "—",
          client.payloadLight
            ? "Abrir para carregar"
            : String(client.systems.length),
          [client.city, client.state].filter(Boolean).join("/") || "—",
          client.updatedAt
            ? new Date(client.updatedAt).toLocaleString("pt-BR")
            : "—",
        ])}
      />
    </div>
  );
}
