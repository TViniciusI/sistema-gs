import Link from "next/link";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { listCampoOrders } from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

function startOfWeek(d: Date) {
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() + diff);
  return start;
}

export default async function AgendaPage() {
  const orders = await listCampoOrders();
  const weekStart = startOfWeek(new Date());
  const days = Array.from({ length: 7 }, (_, i) => {
    const date = new Date(weekStart);
    date.setDate(weekStart.getDate() + i);
    return date;
  });

  const byDay = days.map((date) => {
    const key = date.toISOString().slice(0, 10);
    const items = orders.filter((os) => {
      if (!os.startsAt) return false;
      return os.startsAt.slice(0, 10) === key;
    });
    return { date, items };
  });

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Agenda da semana"
        description="OS da planilha agrupadas pelo dia de início — visão do escritório."
      />
      <div className="grid gap-3 lg:grid-cols-7">
        {byDay.map(({ date, items }) => (
          <Panel key={date.toISOString()}>
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-brass">
              {date.toLocaleDateString("pt-BR", { weekday: "short" })}
            </p>
            <p className="mt-1 font-serif text-xl text-navy">
              {date.toLocaleDateString("pt-BR", {
                day: "2-digit",
                month: "2-digit",
              })}
            </p>
            <div className="mt-3 space-y-2">
              {items.length === 0 ? (
                <p className="text-xs text-muted">Sem OS</p>
              ) : (
                items.map((os) => (
                  <Link
                    key={os.id}
                    href={`/os/${os.id}`}
                    className="block rounded-xl border border-navy/10 bg-paper px-2.5 py-2 hover:border-brass/40"
                  >
                    <div className="text-[12px] font-semibold text-navy">
                      GS {os.number}
                    </div>
                    <div className="mt-0.5 line-clamp-2 text-[11px] text-navy/60">
                      {os.clientName || "—"}
                    </div>
                    <div className="mt-1.5">
                      <StatusPill
                        label={campoOsStatusLabel(os.status)}
                        tone={campoOsStatusTone(os.status)}
                      />
                    </div>
                  </Link>
                ))
              )}
            </div>
          </Panel>
        ))}
      </div>
    </div>
  );
}
