import Link from "next/link";
import { PageHeader } from "@/components/ui";
import {
  isFieldTechnicianUser,
  listCampoClients,
  listCampoUsers,
} from "@/lib/campo-data";
import { OsCreateForm } from "./os-create-form";

export const dynamic = "force-dynamic";

export default async function NovaOsPage() {
  const [clients, users] = await Promise.all([
    listCampoClients(),
    listCampoUsers(),
  ]);

  const clientOptions = clients
    .map((client) => ({
      id: client.id,
      name: client.name,
      cnpj: client.cnpj,
      city: client.city,
      state: client.state,
      baseName: client.baseName,
      baseCargo: client.baseCargo,
      baseEmail: client.baseEmail,
      basePhone: client.basePhone,
      sites: client.sites,
      systems: client.systems.map((system) => ({
        id: system.id,
        systemType: system.systemType,
        installLocation: system.installLocation,
      })),
    }))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));

  const technicians = users
    .filter(isFieldTechnicianUser)
    .map((user) => ({
      email: user.email || `${user.login}@gssolucoestec.com.br`,
      login: user.login,
      name: user.name || user.login,
      cargo: user.cargo,
      funcao: user.funcao,
    }))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Nova ordem de serviço"
        description="Mesmo fluxo do GS Campo: número, cliente, serviço, base e equipe — grava na planilha."
        action={
          <Link
            href="/os"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Voltar às OS
          </Link>
        }
      />
      <OsCreateForm clients={clientOptions} technicians={technicians} />
    </div>
  );
}
