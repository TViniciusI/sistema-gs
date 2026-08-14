import { notFound } from "next/navigation";
import { formatCnpj } from "@gs/shared";
import { Button, PageHeader, Panel } from "@/components/ui";
import { getClient, locationsForClient } from "@/lib/demo/queries";

export default async function ClienteDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const client = getClient(id);
  if (!client) notFound();
  const locations = locationsForClient(id);

  return (
    <div>
      <PageHeader
        title={client.legalName}
        description={`Código ${client.code} · ${client.alias}`}
        action={<Button href="/locais/novo">Novo local</Button>}
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Dados do contratante</h2>
          <dl className="space-y-2 text-sm">
            <div>
              <dt className="text-muted">CNPJ</dt>
              <dd>{formatCnpj(client.cnpj)}</dd>
            </div>
          </dl>
          <h3 className="mt-5 mb-2 text-xs font-medium uppercase tracking-wide text-muted">
            Solicitante
          </h3>
          <p className="text-sm">
            {client.requester.name} · {client.requester.title}
            <br />
            {client.requester.phone} · {client.requester.email}
          </p>
          <h3 className="mt-5 mb-2 text-xs font-medium uppercase tracking-wide text-muted">
            Responsável da base
          </h3>
          <p className="text-sm">
            {client.manager.name} · {client.manager.title}
            <br />
            {client.manager.phone} · {client.manager.email}
          </p>
        </Panel>
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Locais / bases</h2>
          <ul className="space-y-3 text-sm">
            {locations.map((location) => (
              <li key={location.id}>
                <div className="font-medium">{location.alias}</div>
                <div className="text-muted">
                  {location.address} · {location.city}/{location.state}
                </div>
              </li>
            ))}
          </ul>
        </Panel>
      </div>
    </div>
  );
}
