"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";
import type { DashboardOrder } from "./types";

const WEEKDAYS = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"];

function dateKey(d: Date) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function startOfMonth(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function addMonths(d: Date, delta: number) {
  return new Date(d.getFullYear(), d.getMonth() + delta, 1);
}

function orderDayKey(os: DashboardOrder) {
  if (os.startsAt && os.startsAt.length >= 10) return os.startsAt.slice(0, 10);
  if (os.updatedAt && os.updatedAt.length >= 10) return os.updatedAt.slice(0, 10);
  return "";
}

export function WorkCalendar({ orders }: { orders: DashboardOrder[] }) {
  const today = useMemo(() => {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now;
  }, []);
  const [cursor, setCursor] = useState(() => startOfMonth(today));
  const [selected, setSelected] = useState(dateKey(today));

  const byDay = useMemo(() => {
    const map = new Map<string, DashboardOrder[]>();
    for (const os of orders) {
      const key = orderDayKey(os);
      if (!key) continue;
      const list = map.get(key) ?? [];
      list.push(os);
      map.set(key, list);
    }
    return map;
  }, [orders]);

  const cells = useMemo(() => {
    const first = startOfMonth(cursor);
    const mondayOffset = (first.getDay() + 6) % 7;
    const gridStart = new Date(first);
    gridStart.setDate(first.getDate() - mondayOffset);
    return Array.from({ length: 42 }, (_, i) => {
      const date = new Date(gridStart);
      date.setDate(gridStart.getDate() + i);
      const key = dateKey(date);
      return {
        date,
        key,
        inMonth: date.getMonth() === cursor.getMonth(),
        isToday: key === dateKey(today),
        items: byDay.get(key) ?? [],
      };
    });
  }, [cursor, byDay, today]);

  const selectedItems = byDay.get(selected) ?? [];
  const monthLabel = cursor.toLocaleDateString("pt-BR", {
    month: "long",
    year: "numeric",
  });

  return (
    <div className="grid gap-5 xl:grid-cols-[minmax(0,1.35fr)_minmax(260px,0.9fr)]">
      <div>
        <div className="mb-4 flex items-center justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Calendário
            </p>
            <h3 className="mt-1 font-serif text-2xl capitalize text-navy">
              {monthLabel}
            </h3>
          </div>
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              onClick={() => setCursor((c) => addMonths(c, -1))}
              className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-navy/12 bg-white text-navy hover:border-brass/50"
              aria-label="Mês anterior"
            >
              ‹
            </button>
            <button
              type="button"
              onClick={() => {
                setCursor(startOfMonth(today));
                setSelected(dateKey(today));
              }}
              className="rounded-xl border border-navy/12 bg-white px-3 py-2 text-xs font-semibold uppercase tracking-wide text-navy hover:border-brass/50"
            >
              Hoje
            </button>
            <button
              type="button"
              onClick={() => setCursor((c) => addMonths(c, 1))}
              className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-navy/12 bg-white text-navy hover:border-brass/50"
              aria-label="Próximo mês"
            >
              ›
            </button>
          </div>
        </div>

        <div className="grid grid-cols-7 gap-1.5 text-center text-[11px] font-semibold uppercase tracking-wide text-navy/40">
          {WEEKDAYS.map((d) => (
            <div key={d} className="py-1">
              {d}
            </div>
          ))}
        </div>

        <div className="mt-1 grid grid-cols-7 gap-1.5">
          {cells.map((cell) => {
            const active = cell.key === selected;
            const hasItems = cell.items.length > 0;
            const busy =
              cell.items.length >= 3
                ? "bg-brass/12"
                : cell.items.length > 0
                  ? "bg-brass/[0.06]"
                  : "";
            return (
              <button
                key={cell.key}
                type="button"
                onClick={() => setSelected(cell.key)}
                className={[
                  "relative flex min-h-[72px] flex-col rounded-2xl border px-1.5 py-1.5 text-left transition",
                  cell.inMonth ? `bg-white ${busy}` : "bg-paper/60",
                  active
                    ? "border-brass shadow-[0_8px_20px_rgba(197,158,57,0.18)]"
                    : "border-navy/8 hover:border-brass/35",
                  !cell.inMonth ? "opacity-45" : "",
                ].join(" ")}
              >
                <span
                  className={[
                    "inline-flex h-6 w-6 items-center justify-center rounded-full text-[12px] font-semibold",
                    cell.isToday
                      ? "bg-navy text-brass"
                      : active
                        ? "text-navy"
                        : "text-navy/70",
                  ].join(" ")}
                >
                  {cell.date.getDate()}
                </span>
                {hasItems ? (
                  <div className="mt-auto flex flex-wrap gap-0.5 pb-0.5">
                    {cell.items.slice(0, 3).map((os) => (
                      <span
                        key={os.id}
                        className="h-1.5 w-1.5 rounded-full bg-brass"
                        title={`GS ${os.number}`}
                      />
                    ))}
                    {cell.items.length > 3 ? (
                      <span className="text-[9px] font-semibold text-navy/40">
                        +{cell.items.length - 3}
                      </span>
                    ) : null}
                  </div>
                ) : null}
              </button>
            );
          })}
        </div>
      </div>

      <div className="rounded-2xl border border-navy/10 bg-paper/70 p-4">
        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
          Dia selecionado
        </p>
        <h4 className="mt-1 font-serif text-xl text-navy">
          {new Date(`${selected}T12:00:00`).toLocaleDateString("pt-BR", {
            weekday: "long",
            day: "2-digit",
            month: "long",
          })}
        </h4>
        <p className="mt-1 text-sm text-navy/50">
          {selectedItems.length === 0
            ? "Nenhuma OS neste dia"
            : `${selectedItems.length} OS`}
        </p>

        <div className="mt-4 max-h-[360px] space-y-2 overflow-y-auto pr-1">
          {selectedItems.length === 0 ? (
            <div className="rounded-xl border border-dashed border-navy/15 bg-white/70 px-3 py-8 text-center text-sm text-muted">
              Escolha outro dia ou veja a{" "}
              <a href="#agenda" className="font-medium text-navy underline">
                agenda da semana
              </a>
              .
            </div>
          ) : (
            selectedItems.map((os) => (
              <Link
                key={os.id}
                href={`/os/${os.id}`}
                className="block rounded-xl border border-navy/10 bg-white px-3 py-3 hover:border-brass/45"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold tracking-wide text-navy">
                      GS {os.number}
                    </p>
                    <p className="mt-0.5 line-clamp-2 text-xs text-navy/55">
                      {os.clientName || "—"}
                      {os.technicianName ? ` · ${os.technicianName}` : ""}
                    </p>
                  </div>
                  <StatusPill
                    label={campoOsStatusLabel(os.status)}
                    tone={campoOsStatusTone(os.status)}
                  />
                </div>
              </Link>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
