"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";

export type CalibracaoBoardItem = {
  id: string;
  number: string;
  clientName: string;
  equipmentTag: string;
  equipmentType: string;
  kind: string;
  status: string;
  updatedAt: string;
};

function statusTone(status: string): "ok" | "warn" | "danger" | "neutral" {
  const s = status.trim().toLowerCase();
  if (s === "done" || s === "concluido" || s === "concluído") return "ok";
  if (s.includes("review") || s.includes("revisao") || s.includes("revisão"))
    return "warn";
  if (s.includes("progress") || s.includes("andamento")) return "warn";
  if (s === "draft" || s === "rascunho") return "neutral";
  return "neutral";
}

function statusLabel(status: string) {
  const s = status.trim().toLowerCase();
  if (s === "done") return "Concluída";
  if (s === "draft") return "Rascunho";
  if (s === "inprogress" || s === "in_progress") return "Em andamento";
  if (s === "pendingreview" || s === "pending_review") return "Em revisão";
  return status || "—";
}

type Filter = "todas" | "andamento" | "revisao" | "concluidas";

export function CalibracaoBoard({ items }: { items: CalibracaoBoardItem[] }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("todas");

  const counts = useMemo(() => {
    let andamento = 0;
    let revisao = 0;
    let concluidas = 0;
    for (const item of items) {
      const s = item.status.trim().toLowerCase();
      if (s === "done") concluidas += 1;
      else if (s.includes("review") || s.includes("revis")) revisao += 1;
      else if (s.includes("progress") || s === "draft" || s.includes("andamento"))
        andamento += 1;
    }
    return { andamento, revisao, concluidas };
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items.filter((item) => {
      const s = item.status.trim().toLowerCase();
      if (filter === "concluidas" && s !== "done") return false;
      if (
        filter === "revisao" &&
        !(s.includes("review") || s.includes("revis"))
      )
        return false;
      if (
        filter === "andamento" &&
        !(
          s.includes("progress") ||
          s === "draft" ||
          s.includes("andamento") ||
          (!s.includes("review") && s !== "done")
        )
      )
        return false;
      if (!q) return true;
      return [
        item.number,
        item.clientName,
        item.equipmentTag,
        item.equipmentType,
        item.kind,
        item.status,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [items, filter, query]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Em andamento / rascunho", value: counts.andamento },
          { label: "Em revisão", value: counts.revisao },
          { label: "Concluídas", value: counts.concluidas },
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
        <div className="flex flex-wrap rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["todas", `Todas · ${items.length}`],
              ["andamento", "Andamento"],
              ["revisao", "Revisão"],
              ["concluidas", "Concluídas"],
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
          placeholder="Buscar nº, cliente, TAG, tipo…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhuma calibração neste filtro.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.slice(0, 120).map((item) => (
            <Link
              key={item.id}
              href={`/calibracao/${item.id}`}
              className="group rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)] transition hover:-translate-y-0.5 hover:border-brass/40"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                    {item.kind || "Calibração"}
                  </p>
                  <h3 className="mt-1 font-serif text-2xl text-navy group-hover:text-navy-2">
                    {item.number || item.id}
                  </h3>
                  <p className="mt-1 text-sm text-navy/55">
                    {item.clientName || "—"}
                  </p>
                  <p className="mt-1 text-xs text-navy/45">
                    {[item.equipmentTag, item.equipmentType]
                      .filter(Boolean)
                      .join(" · ") || "Sem equipamento"}
                  </p>
                </div>
                <StatusPill
                  label={statusLabel(item.status)}
                  tone={statusTone(item.status)}
                />
              </div>
              <p className="mt-4 text-[11px] text-navy/40">
                Atualizado{" "}
                {item.updatedAt
                  ? new Date(item.updatedAt).toLocaleString("pt-BR")
                  : "—"}
              </p>
            </Link>
          ))}
        </div>
      )}
      {filtered.length > 120 ? (
        <p className="text-sm text-muted">
          Mostrando 120 de {filtered.length}. Refine a busca.
        </p>
      ) : null}
    </div>
  );
}
