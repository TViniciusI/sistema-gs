"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export type OsBoardItem = {
  id: string;
  number: string;
  status: string;
  clientName: string;
  technicianName: string;
  startsAt: string;
  rdoCount: number;
  fileCount: number;
  payloadLight: boolean;
};

function isOpenStatus(status: string) {
  const s = status.toLowerCase().replace(/\s+/g, "");
  return s !== "encerrada";
}

type Filter = "todas" | "abertas" | "encerradas";

export function OsBoard({ orders }: { orders: OsBoardItem[] }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("abertas");

  const openCount = orders.filter((os) => isOpenStatus(os.status)).length;
  const closedCount = orders.length - openCount;

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return orders.filter((os) => {
      if (filter === "abertas" && !isOpenStatus(os.status)) return false;
      if (filter === "encerradas" && isOpenStatus(os.status)) return false;
      if (!q) return true;
      const blob =
        `${os.number} ${os.clientName} ${os.technicianName} ${os.status}`.toLowerCase();
      return blob.includes(q);
    });
  }, [orders, query, filter]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Total", value: orders.length, tone: "navy" as const },
          { label: "Em aberto", value: openCount, tone: "brass" as const },
          { label: "Encerradas", value: closedCount, tone: "muted" as const },
        ].map((kpi) => (
          <div
            key={kpi.label}
            className="rounded-2xl border border-navy/10 bg-white px-4 py-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
          >
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              {kpi.label}
            </p>
            <p className="mt-2 font-serif text-3xl text-navy">{kpi.value}</p>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["abertas", "Abertas"],
              ["encerradas", "Encerradas"],
              ["todas", "Todas"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setFilter(value)}
              className={[
                "rounded-lg px-3.5 py-2 text-sm font-medium transition",
                filter === value
                  ? "bg-navy text-brass"
                  : "text-navy/65 hover:text-navy",
              ].join(" ")}
            >
              {label}
            </button>
          ))}
        </div>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar número, cliente ou técnico…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhuma OS neste filtro.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2 xl:grid-cols-3">
          {filtered.map((os) => (
            <Link
              key={os.id}
              href={`/os/${os.id}`}
              className="group flex flex-col rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)] transition hover:-translate-y-0.5 hover:border-brass/40"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                    Ordem
                  </p>
                  <h3 className="mt-1 font-serif text-2xl text-navy">
                    GS {os.number}
                  </h3>
                </div>
                <StatusPill
                  label={campoOsStatusLabel(os.status)}
                  tone={campoOsStatusTone(os.status)}
                />
              </div>

              <p className="mt-4 line-clamp-2 text-sm leading-6 text-navy/70">
                {os.clientName || "Cliente não informado"}
              </p>
              <p className="mt-1 truncate text-xs text-navy/45">
                {os.technicianName || "Sem técnico"}
              </p>

              <div className="mt-5 flex flex-wrap items-center gap-3 border-t border-navy/8 pt-3 text-[11px] font-medium uppercase tracking-wide text-navy/45">
                <span>
                  {os.startsAt
                    ? new Date(os.startsAt).toLocaleDateString("pt-BR")
                    : "Sem data"}
                </span>
                <span>·</span>
                <span>{os.rdoCount} RDO</span>
                <span>·</span>
                <span>{os.fileCount} arq.</span>
                {os.payloadLight ? (
                  <>
                    <span>·</span>
                    <span className="text-warn">resumo</span>
                  </>
                ) : null}
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
