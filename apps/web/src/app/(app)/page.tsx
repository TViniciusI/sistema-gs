import Link from "next/link";
import type { ReactNode } from "react";
import { StatusChart } from "@/components/dashboard/status-chart";
import { TechChart } from "@/components/dashboard/tech-chart";
import { WeekAgenda } from "@/components/dashboard/week-agenda";
import { WeekChart } from "@/components/dashboard/week-chart";
import { WorkCalendar } from "@/components/dashboard/work-calendar";
import { Icons } from "@/components/icons";
import { StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import {
  listCampoCalibrations,
  listCampoClients,
  listCampoOrders,
  listCampoStandards,
  listCampoUsers,
} from "@/lib/campo-data";
import {
  buildStatusSlices,
  buildTechLoad,
  buildWeekBuckets,
  toDashboardOrders,
} from "@/lib/campo-data/dashboard";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

function Panel({
  title,
  eyebrow,
  action,
  children,
  className = "",
}: {
  title: string;
  eyebrow?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_12px_32px_rgba(12,31,51,0.05)] md:p-6 ${className}`}
    >
      <div className="mb-5 flex items-start justify-between gap-3">
        <div>
          {eyebrow ? (
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              {eyebrow}
            </p>
          ) : null}
          <h2 className="mt-1 font-serif text-2xl text-navy">{title}</h2>
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

export default async function DashboardPage() {
  const profile = await getProfile();
  const [orders, clients, users, calibrations, standards] = await Promise.all([
    listCampoOrders(),
    listCampoClients(),
    listCampoUsers(),
    listCampoCalibrations(),
    listCampoStandards(),
  ]);

  const open = orders.filter((os) => {
    const s = os.status.toLowerCase().replace(/\s+/g, "");
    return s !== "encerrada";
  });
  const pendingUsers = users.filter((u) => u.status === "pendente");
  const dueStandards = standards.filter((s) => {
    if (!s.validity) return false;
    const t = Date.parse(s.validity);
    if (!Number.isFinite(t)) return false;
    return t - Date.now() < 1000 * 60 * 60 * 24 * 60;
  });

  const firstName = (profile?.full_name || "GS").split(/\s+/)[0];
  const statusSlices = buildStatusSlices(orders);
  const weekBuckets = buildWeekBuckets(orders, 8);
  const techLoad = buildTechLoad(orders);
  const dashboardOrders = toDashboardOrders(orders);
  const recent = orders.slice(0, 6);
  const closedPct =
    orders.length === 0
      ? 0
      : Math.round(
          ((orders.length - open.length) / Math.max(orders.length, 1)) * 100,
        );

  const kpis = [
    {
      label: "OS em aberto",
      value: open.length,
      hint: `${orders.length} no total`,
      href: "/os",
      accent: true,
    },
    {
      label: "Clientes",
      value: clients.length,
      hint: "cadastro compartilhado",
      href: "/clientes",
      accent: false,
    },
    {
      label: "Calibrações",
      value: calibrations.length,
      hint: "registros no Campo",
      href: "/calibracao",
      accent: false,
    },
    {
      label: "Atenções",
      value: pendingUsers.length + dueStandards.length,
      hint:
        pendingUsers.length > 0
          ? `${pendingUsers.length} acesso(s) pendente(s)`
          : `${dueStandards.length} padrão(ões) a vencer`,
      href: pendingUsers.length > 0 ? "/equipe" : "/vencimentos",
      accent: false,
    },
  ];

  return (
    <div className="space-y-6">
      <section className="relative overflow-hidden rounded-3xl border border-navy/10 bg-navy px-6 py-6 text-paper shadow-[0_20px_50px_rgba(12,31,51,0.18)] md:px-8 md:py-7">
        <div
          aria-hidden
          className="pointer-events-none absolute -right-16 top-1/2 size-[240px] -translate-y-1/2 rounded-full border border-brass/20"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute right-10 top-1/2 size-[140px] -translate-y-1/2 rounded-full border border-brass/30"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(700px_280px_at_0%_100%,rgba(197,158,57,0.16),transparent_55%)]"
        />
        <div className="relative flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.32em] text-brass">
              Área de trabalho
            </p>
            <h1 className="mt-2 font-serif text-3xl leading-tight md:text-4xl">
              Olá, {firstName}
            </h1>
            <p className="mt-2 max-w-xl text-[15px] leading-7 text-paper/65">
              Agenda da semana, calendário e ritmo das OS — na mesma base do GS
              Campo.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-brass/90">
                Encerradas
              </p>
              <p className="mt-1 font-serif text-2xl text-paper">{closedPct}%</p>
            </div>
            <Link
              href="/os/nova"
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Nova OS
            </Link>
            <a
              href="#agenda"
              className="rounded-xl border border-white/15 bg-white/5 px-4 py-2.5 text-sm font-medium text-paper hover:bg-white/10"
            >
              Ver agenda
            </a>
          </div>
        </div>
      </section>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {kpis.map((kpi) => (
          <Link
            key={kpi.label}
            href={kpi.href}
            className={[
              "rounded-2xl border px-4 py-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)] transition hover:-translate-y-0.5",
              kpi.accent
                ? "border-brass/35 bg-navy text-paper hover:border-brass"
                : "border-navy/10 bg-white hover:border-brass/40",
            ].join(" ")}
          >
            <p
              className={`text-[11px] font-semibold uppercase tracking-[0.18em] ${
                kpi.accent ? "text-brass" : "text-navy/45"
              }`}
            >
              {kpi.label}
            </p>
            <p
              className={`mt-2 font-serif text-3xl ${
                kpi.accent ? "text-paper" : "text-navy"
              }`}
            >
              {kpi.value}
            </p>
            <p
              className={`mt-1 text-xs ${
                kpi.accent ? "text-paper/55" : "text-navy/50"
              }`}
            >
              {kpi.hint}
            </p>
          </Link>
        ))}
      </div>

      <Panel eyebrow="Operação" title="Calendário de OS">
        <WorkCalendar orders={dashboardOrders} />
      </Panel>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_12px_32px_rgba(12,31,51,0.05)] md:p-6">
        <WeekAgenda orders={dashboardOrders} />
      </section>

      <div className="grid gap-6 xl:grid-cols-3">
        <Panel eyebrow="Distribuição" title="Status das OS">
          <StatusChart slices={statusSlices} />
        </Panel>
        <Panel eyebrow="Ritmo" title="OS por semana">
          <p className="mb-4 text-sm text-navy/50">Últimas 8 semanas</p>
          <WeekChart buckets={weekBuckets} />
        </Panel>
        <Panel eyebrow="Equipe" title="Carga dos técnicos">
          <p className="mb-4 text-sm text-navy/50">OS abertas por responsável</p>
          <TechChart rows={techLoad} />
        </Panel>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)]">
        <Panel
          eyebrow="Fila"
          title="Últimas OS"
          action={
            <Link
              href="/os"
              className="text-sm font-medium text-navy/55 hover:text-navy"
            >
              Ver todas →
            </Link>
          }
        >
          <div className="divide-y divide-navy/8 overflow-hidden rounded-2xl border border-navy/8">
            {recent.length === 0 ? (
              <p className="px-4 py-8 text-sm text-muted">
                Nenhuma OS carregada da planilha.
              </p>
            ) : (
              recent.map((os) => (
                <Link
                  key={os.id}
                  href={`/os/${os.id}`}
                  className="flex items-center justify-between gap-3 px-4 py-3.5 transition hover:bg-paper"
                >
                  <div className="min-w-0">
                    <div className="font-semibold tracking-wide text-navy">
                      GS {os.number}
                    </div>
                    <div className="mt-0.5 truncate text-sm text-muted">
                      {os.clientName || "—"} ·{" "}
                      {os.technicianName || "sem técnico"}
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
        </Panel>

        <section className="rounded-3xl border border-navy/10 bg-white/80 px-5 py-5 shadow-[0_12px_32px_rgba(12,31,51,0.04)]">
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
            Atalhos
          </p>
          <div className="mt-4 grid gap-2 sm:grid-cols-2 xl:grid-cols-1">
            {[
              { href: "/clientes", label: "Clientes", icon: Icons.building },
              { href: "/calibracao", label: "Calibração", icon: Icons.wrench },
              { href: "/arquivos", label: "Drive", icon: Icons.clipboard },
              { href: "/equipe", label: "Equipe", icon: Icons.users },
              { href: "/equipe/horas", label: "Horas de campo", icon: Icons.clock },
              { href: "/vencimentos", label: "Vencimentos", icon: Icons.clock },
              { href: "/campo", label: "App campo", icon: Icons.phone },
            ].map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="inline-flex items-center gap-3 rounded-2xl border border-navy/10 bg-white px-3.5 py-3 text-sm font-medium text-navy hover:border-brass/45"
              >
                <span className="text-brass">{item.icon}</span>
                {item.label}
              </Link>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
