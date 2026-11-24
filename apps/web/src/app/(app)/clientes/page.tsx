import Link from "next/link";
import { ClientesBoard } from "@/components/clientes/clientes-board";
import { PageHeader } from "@/components/ui";
import { listCampoClients } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function ClientesPage() {
  const clients = await listCampoClients();

  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Clientes"
        description="Cadastro compartilhado com o GS Campo — busca, sistemas e bases."
        action={
          <Link
            href="/clientes/novo"
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Novo cliente
          </Link>
        }
      />
      <ClientesBoard
        clients={clients.map((client) => ({
          id: client.id,
          name: client.name,
          cnpj: client.cnpj,
          city: client.city,
          state: client.state,
          systemCount: client.systems.length,
          payloadLight: client.payloadLight,
          updatedAt: client.updatedAt,
          requester: client.requester,
        }))}
      />
    </div>
  );
}
