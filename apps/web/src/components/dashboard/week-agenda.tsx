import Link from "next/link";
import { StatusPill } from "@/components/ui";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";
import type { DashboardOrder } from "./types";

function startOfWeek(d: Date) {
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() + diff);
  return start;
}

function dayKey(d: Date) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function orderKey(os: DashboardOrder) {
  if (os.startsAt?.length >= 10) return os.startsAt.slice(0, 10);
  return "";
}

export function WeekAgenda({ orders }: { orders: DashboardOrder[] }) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayKey = dayKey(today);
  const weekStart = startOfWeek(today);
  const days = Array.from({ length: 7 }, (_, i) => {
    const date = new Date(weekStart);
    date.setDate(weekStart.getDate() + i);
    const key = dayKey(date);
    const items = orders.filter((os) => orderKey(os) === key);
    return { date, key, items, isToday: key === todayKey };
  });

  const weekTotal = days.reduce((sum, d) => sum + d.items.length, 0);
  const rangeLabel = `${days[0].date.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "short",
  })} — ${days[6].date.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "short",
  })}`;

  return (
    <div id="agenda" className="scroll-mt-6">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Nesta semana
          </p>
          <h3 className="mt-1 font-serif text-2xl text-navy">Agenda</h3>
          <p className="mt-1 text-sm text-navy/50">
            {rangeLabel}
            {weekTotal > 0 ? ` · ${weekTotal} OS` : " · sem OS agendada"}
          </p>
        </div>
      </div>

      <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-7">
        {days.map(({ date, key, items, isToday }) => (
          <div
            key={key}
            className={[
              "flex min-h-[180px] flex-col rounded-2xl border px-2.5 py-3",
              isToday
                ? "border-brass/55 bg-navy text-paper shadow-[0_12px_28px_rgba(12,31,51,0.18)]"
                : "border-navy/10 bg-paper/80",
            ].join(" ")}
          >
            <p
              className={`text-[10px] font-semibold uppercase tracking-[0.18em] ${
                isToday ? "text-brass" : "text-brass/90"
              }`}
            >
              {date.toLocaleDateString("pt-BR", { weekday: "short" })}
              {isToday ? " · hoje" : ""}
            </p>
            <p
              className={`mt-1 font-serif text-xl ${
                isToday ? "text-paper" : "text-navy"
              }`}
            >
              {date.toLocaleDateString("pt-BR", {
                day: "2-digit",
                month: "2-digit",
              })}
            </p>

            <div className="mt-3 flex-1 space-y-1.5">
              {items.length === 0 ? (
                <p
                  className={`text-[11px] ${
                    isToday ? "text-paper/45" : "text-muted"
                  }`}
                >
                  Livre
                </p>
              ) : (
                items.slice(0, 4).map((os) => (
                  <Link
                    key={os.id}
                    href={`/os/${os.id}`}
                    className={[
                      "block rounded-xl px-2 py-1.5 transition",
                      isToday
                        ? "bg-white/8 hover:bg-white/14"
                        : "border border-navy/8 bg-white hover:border-brass/40",
                    ].join(" ")}
                  >
                    <div
                      className={`text-[11px] font-semibold tracking-wide ${
                        isToday ? "text-brass-2" : "text-navy"
                      }`}
                    >
                      GS {os.number}
                    </div>
                    <div
                      className={`mt-0.5 line-clamp-2 text-[10px] leading-snug ${
                        isToday ? "text-paper/60" : "text-navy/55"
                      }`}
                    >
                      {os.clientName || "—"}
                    </div>
                    {!isToday ? (
                      <div className="mt-1.5">
                        <StatusPill
                          label={campoOsStatusLabel(os.status)}
                          tone={campoOsStatusTone(os.status)}
                        />
                      </div>
                    ) : null}
                  </Link>
                ))
              )}
              {items.length > 4 ? (
                <p
                  className={`pt-1 text-[10px] font-medium ${
                    isToday ? "text-paper/50" : "text-navy/45"
                  }`}
                >
                  +{items.length - 4} no dia
                </p>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
