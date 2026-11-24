"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";
import { kindLabel } from "@/lib/campo-data/kind-labels";

export type CertificadoBoardItem = {
  id: string;
  number: string;
  clientName: string;
  kind: string;
  status: string;
  equipmentTag: string;
  equipmentType: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
  technicianName: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  osId: string;
  osNumber: string;
  site: string;
  updatedAt: string;
};

type StatusFilter = "todas" | "emitidos" | "andamento" | "rascunho";

function statusTone(status: string): "ok" | "warn" | "danger" | "neutral" {
  const s = status.trim().toLowerCase();
  if (s === "done" || s === "issued" || s.includes("emit")) return "ok";
  if (s.includes("review") || s.includes("progress") || s.includes("andamento"))
    return "warn";
  if (s === "draft" || s === "rascunho") return "neutral";
  return "neutral";
}

function statusLabel(status: string) {
  const s = status.trim().toLowerCase();
  if (s === "done") return "Concluído";
  if (s === "draft" || s === "rascunho") return "Rascunho";
  if (s.includes("progress") || s.includes("andamento")) return "Em andamento";
  if (s.includes("review") || s.includes("revis")) return "Em revisão";
  if (s.includes("emit")) return "Emitido";
  return status || "—";
}

function isDone(status: string) {
  const s = status.trim().toLowerCase();
  return s === "done" || s.includes("emit");
}

function isDraft(status: string) {
  const s = status.trim().toLowerCase();
  return s === "draft" || s === "rascunho" || !s || s === "—";
}

function hrefFor(item: CertificadoBoardItem) {
  return `/certificados/${encodeURIComponent(item.id)}`;
}

export function CertificadosBoard({ items }: { items: CertificadoBoardItem[] }) {
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("todas");
  const [kindFilter, setKindFilter] = useState("todos");

  const kinds = useMemo(() => {
    const map = new Map<string, number>();
    for (const item of items) {
      const key = item.kind || "outros";
      map.set(key, (map.get(key) || 0) + 1);
    }
    return [...map.entries()]
      .map(([kind, count]) => ({ kind, count, label: kindLabel(kind) }))
      .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));
  }, [items]);

  const counts = useMemo(() => {
    let emitidos = 0;
    let andamento = 0;
    let rascunho = 0;
    for (const item of items) {
      if (isDone(item.status)) emitidos += 1;
      else if (isDraft(item.status)) rascunho += 1;
      else andamento += 1;
    }
    return { emitidos, andamento, rascunho, total: items.length };
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items.filter((item) => {
      if (kindFilter !== "todos" && (item.kind || "outros") !== kindFilter) {
        return false;
      }
      if (statusFilter === "emitidos" && !isDone(item.status)) return false;
      if (
        statusFilter === "andamento" &&
        (isDone(item.status) || isDraft(item.status))
      )
        return false;
      if (statusFilter === "rascunho" && !isDraft(item.status)) return false;
      if (!q) return true;
      return [
        item.number,
        item.clientName,
        item.equipmentTag,
        item.equipmentType,
        item.serialNumber,
        item.manufacturer,
        item.model,
        item.osNumber,
        item.technicianName,
        item.site,
        kindLabel(item.kind),
        item.status,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [items, query, statusFilter, kindFilter]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Total com número", value: counts.total },
          { label: "Concluídos / emitidos", value: counts.emitidos },
          { label: "Em andamento", value: counts.andamento },
          { label: "Rascunho", value: counts.rascunho },
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

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setKindFilter("todos")}
          className={[
            "rounded-xl px-3.5 py-2 text-sm font-medium transition",
            kindFilter === "todos"
              ? "bg-navy text-brass"
              : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
          ].join(" ")}
        >
          Todos os tipos · {items.length}
        </button>
        {kinds.map((k) => (
          <button
            key={k.kind}
            type="button"
            onClick={() => setKindFilter(k.kind)}
            className={[
              "rounded-xl px-3.5 py-2 text-sm font-medium transition",
              kindFilter === k.kind
                ? "bg-navy text-brass"
                : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
            ].join(" ")}
          >
            {k.label} · {k.count}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["todas", "Todas"],
              ["emitidos", "Concluídos"],
              ["andamento", "Andamento"],
              ["rascunho", "Rascunho"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setStatusFilter(value)}
              className={[
                "rounded-lg px-3.5 py-2 text-sm font-medium transition",
                statusFilter === value
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
          placeholder="Buscar nº, cliente, TAG, N/S, OS…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum certificado neste filtro.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.slice(0, 160).map((item) => (
            <article
              key={item.id}
              className="group rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)] transition hover:-translate-y-0.5 hover:border-brass/40"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                    {kindLabel(item.kind)}
                  </p>
                  <Link
                    href={hrefFor(item)}
                    className="mt-1 block font-serif text-2xl text-navy group-hover:text-navy-2"
                  >
                    {item.number}
                  </Link>
                  <p className="mt-1 text-sm text-navy/55">
                    {item.clientName || "Sem cliente"}
                    {item.site ? ` · ${item.site}` : ""}
                  </p>
                </div>
                <StatusPill
                  label={statusLabel(item.status)}
                  tone={statusTone(item.status)}
                />
              </div>

              <dl className="mt-4 grid gap-2 sm:grid-cols-2">
                <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                  <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                    Instrumento
                  </dt>
                  <dd className="mt-0.5 text-sm font-medium text-navy">
                    {[item.equipmentTag && `TAG ${item.equipmentTag}`, item.equipmentType]
                      .filter(Boolean)
                      .join(" · ") || "—"}
                  </dd>
                </div>
                <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                  <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                    Fabricante / N/S
                  </dt>
                  <dd className="mt-0.5 text-sm font-medium text-navy">
                    {[
                      [item.manufacturer, item.model].filter(Boolean).join(" "),
                      item.serialNumber && `N/S ${item.serialNumber}`,
                    ]
                      .filter(Boolean)
                      .join(" · ") || "—"}
                  </dd>
                </div>
                <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                  <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                    Calibrado / próxima
                  </dt>
                  <dd className="mt-0.5 text-sm font-medium text-navy">
                    {[item.calibrationDate || "—", item.nextCalibrationDate || "—"].join(
                      " → ",
                    )}
                  </dd>
                </div>
                <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                  <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                    Técnico / OS
                  </dt>
                  <dd className="mt-0.5 text-sm font-medium text-navy">
                    {[
                      item.technicianName,
                      item.osNumber
                        ? `OS ${item.osNumber}`
                        : item.osId
                          ? "Com OS"
                          : "Sem OS",
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </dd>
                </div>
              </dl>

              <div className="mt-4 flex flex-wrap items-center gap-2">
                <Link
                  href={hrefFor(item)}
                  className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
                >
                  Abrir certificado
                </Link>
                {item.osId ? (
                  <Link
                    href={`/os/${item.osId}`}
                    className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
                  >
                    Ver OS
                  </Link>
                ) : null}
                <Link
                  href={`/calibracao/${encodeURIComponent(item.id)}`}
                  className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
                >
                  Calibração
                </Link>
                <span className="ml-auto text-[11px] text-navy/40">
                  {item.updatedAt
                    ? new Date(item.updatedAt).toLocaleString("pt-BR")
                    : ""}
                </span>
              </div>
            </article>
          ))}
        </div>
      )}
      {filtered.length > 160 ? (
        <p className="text-sm text-muted">
          Mostrando 160 de {filtered.length}. Refine a busca.
        </p>
      ) : null}
    </div>
  );
}
