import Link from "next/link";
import {
  WORK_ORDER_STATUS_LABELS,
  formatWorkOrderNumber,
  type WorkOrderStatus,
} from "@gs/shared";
import { StatusPill } from "@/components/ui";
import { dashboardStats, getClient } from "@/lib/demo/queries";

function tone(status: string) {
  if (status === "cancelled") return "danger" as const;
  if (["completed", "reviewed", "billed"].includes(status)) return "ok" as const;
  if (["in_progress", "traveling", "on_site"].includes(status)) return "warn" as const;
  return "neutral" as const;
}

export default function DashboardPage() {
  const stats = dashboardStats();

  return (
    <div>
      <p className="text-[11px] font-medium uppercase tracking-[0.34em] text-brass">
        Sistema de gestão técnica
      </p>
      <h1 className="mt-2 font-serif text-3xl tracking-tight text-navy">
        Painel operacional
      </h1>
      <p className="mt-2 max-w-xl text-[15px] leading-7 text-navy/65">
        Visão da GS Soluções nesta semana — ordens de serviço, bases e
        vencimentos de padrões.
      </p>

      <div className="mt-8 grid gap-3 sm:grid-cols-4">
        <Stat
          label="OS em aberto"
          value={stats.open}
          href="/os"
        />
        <Stat label="OS de hoje" value={stats.today} href="/agenda" />
        <Stat label="Clientes ativos" value={stats.clients} href="/clientes" />
        <Stat
          label="Padrões a vencer"
          value={stats.dueStandards}
          href="/vencimentos"
        />
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-3">
        <section className="lg:col-span-2">
          <h2 className="mb-3 text-[11px] font-medium uppercase tracking-[0.22em] text-brass">
            Últimas ordens
          </h2>
          <div className="divide-y divide-line border border-line bg-white">
            {stats.recent.map((os) => {
              const client = getClient(os.clientId);
              return (
                <Link
                  key={os.id}
                  href={`/os/${os.id}`}
                  className="flex items-center justify-between px-5 py-3.5 transition hover:bg-paper"
                >
                  <div>
                    <div className="font-medium tracking-wide text-navy">
                      {formatWorkOrderNumber(os.number, os.year)}
                    </div>
                    <div className="mt-0.5 text-sm text-muted">
                      {client?.legalName} · {client?.alias}
                    </div>
                  </div>
                  <StatusPill
                    label={WORK_ORDER_STATUS_LABELS[os.status as WorkOrderStatus]}
                    tone={tone(os.status)}
                  />
                </Link>
              );
            })}
          </div>
        </section>

        <section>
          <h2 className="mb-3 text-[11px] font-medium uppercase tracking-[0.22em] text-brass">
            Nesta apresentação
          </h2>
          <ul className="space-y-0 border border-line bg-white text-sm">
            <Highlight href="/os/os-036" label="RDO e ponto" detail="GS 036/26 · ALESAT/MG" />
            <Highlight href="/certificados/cert-2303126" label="Certificado" detail="Nº 2303126" />
            <Highlight href="/campo" label="App do técnico" detail="GPS, foto e assinatura" />
            <Highlight href="/campo" label="Sem internet" detail="Prévia do fluxo offline" />
            <Highlight href="/vencimentos" label="Padrões RBC" detail="Controle de vencimento" />
          </ul>
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
  value: string | number;
  href: string;
}) {
  return (
    <Link
      href={href}
      className="border border-line bg-white px-5 py-4 transition duration-200 hover:-translate-y-0.5 hover:border-brass/50 hover:shadow-[0_10px_24px_rgba(12,31,51,0.06)]"
    >
      <div className="font-serif text-3xl text-navy">{value}</div>
      <div className="mt-2 text-[10px] font-medium uppercase tracking-[0.18em] text-muted">
        {label}
      </div>
    </Link>
  );
}

function Highlight({
  href,
  label,
  detail,
}: {
  href: string;
  label: string;
  detail: string;
}) {
  return (
    <li className="border-b border-line last:border-0">
      <Link href={href} className="block px-5 py-3.5 transition hover:bg-paper">
        <div className="text-navy">{label}</div>
        <div className="mt-0.5 text-xs text-muted">{detail}</div>
      </Link>
    </li>
  );
}
