import Link from "next/link";
import { StatusPill } from "@/components/ui";
import {
  listCampoClients,
  listCampoOrders,
  listCampoUsers,
} from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const [orders, clients, users] = await Promise.all([
    listCampoOrders(),
    listCampoClients(),
    listCampoUsers(),
  ]);

  const open = orders.filter((os) => {
    const s = os.status.toLowerCase().replace(/\s+/g, "");
    return s !== "encerrada";
  });
  const recent = orders.slice(0, 8);
  const pendingUsers = users.filter((u) => u.status === "pendente");

  return (
    <div>
      <p className="text-[11px] font-medium uppercase tracking-[0.34em] text-brass">
        Escritório GS · dados do Campo
      </p>
      <h1 className="mt-2 font-serif text-3xl tracking-tight text-navy">
        Painel operacional
      </h1>
      <p className="mt-2 max-w-xl text-[15px] leading-7 text-navy/65">
        Visão ao vivo da planilha compartilhada com o GS Campo — OS, clientes e
        acessos.
      </p>

      <div className="mt-8 grid gap-3 sm:grid-cols-4">
        <Stat label="OS em aberto" value={open.length} href="/os" />
        <Stat label="OS no total" value={orders.length} href="/os" />
        <Stat label="Clientes" value={clients.length} href="/clientes" />
        <Stat
          label="Acessos pendentes"
          value={pendingUsers.length}
          href="/equipe"
        />
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-3">
        <section className="lg:col-span-2">
          <h2 className="mb-3 text-[11px] font-medium uppercase tracking-[0.22em] text-brass">
            Últimas ordens
          </h2>
          <div className="divide-y divide-line border border-line bg-white">
            {recent.length === 0 ? (
              <p className="px-5 py-6 text-sm text-muted">
                Nenhuma OS carregada da planilha.
              </p>
            ) : (
              recent.map((os) => (
                <Link
                  key={os.id}
                  href={`/os/${os.id}`}
                  className="flex items-center justify-between px-5 py-3.5 transition hover:bg-paper"
                >
                  <div>
                    <div className="font-medium tracking-wide text-navy">
                      GS {os.number}
                    </div>
                    <div className="mt-0.5 text-sm text-muted">
                      {os.clientName || "—"} · {os.technicianName || "sem técnico"}
                    </div>
                  </div>
                  <StatusPill
                    label={campoOsStatusLabel(os.status)}
                    tone={campoOsStatusTone(os.status)}
                  />
                </Link>
              ))
            )}
          </div>
        </section>

        <section>
          <h2 className="mb-3 text-[11px] font-medium uppercase tracking-[0.22em] text-brass">
            Atalhos
          </h2>
          <div className="space-y-2">
            {[
              { href: "/clientes", label: "Cadastro de clientes e sistemas" },
              { href: "/arquivos", label: "Drive · pastas das OS" },
              { href: "/equipe", label: "Usuários e permissões" },
              { href: "/configuracoes", label: "Configurações e Drive" },
            ].map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="block border border-line bg-white px-4 py-3 text-sm text-navy hover:bg-paper"
              >
                {item.label}
              </Link>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}

function Stat({
  label,
  value,
  href,
}: {
  label: string;
  value: number;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="border border-line bg-white px-4 py-4 transition hover:border-brass/40"
    >
      <div className="text-[11px] uppercase tracking-[0.16em] text-muted">
        {label}
      </div>
      <div className="mt-2 font-serif text-3xl text-navy">{value}</div>
    </Link>
  );
}
