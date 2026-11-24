"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { formatCnpj } from "@gs/shared";

export type ClienteBoardItem = {
  id: string;
  name: string;
  cnpj: string;
  city: string;
  state: string;
  systemCount: number;
  payloadLight: boolean;
  updatedAt: string;
  requester: string;
};

type Filter = "todos" | "completos" | "resumo";

const PAGE_SIZE = 12;

export function ClientesBoard({ clients }: { clients: ClienteBoardItem[] }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("todos");
  const [visible, setVisible] = useState(PAGE_SIZE);

  const completeCount = clients.filter((c) => !c.payloadLight).length;
  const lightCount = clients.length - completeCount;
  const systemTotal = clients.reduce((sum, c) => sum + c.systemCount, 0);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return clients.filter((client) => {
      if (filter === "completos" && client.payloadLight) return false;
      if (filter === "resumo" && !client.payloadLight) return false;
      if (!q) return true;
      const blob = [
        client.name,
        client.cnpj,
        client.city,
        client.state,
        client.requester,
      ]
        .join(" ")
        .toLowerCase();
      return blob.includes(q);
    });
  }, [clients, query, filter]);

  const shown = filtered.slice(0, visible);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Clientes", value: clients.length },
          { label: "Sistemas", value: systemTotal },
          { label: "Resumo / incompleto", value: lightCount },
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
              ["todos", `Todos · ${clients.length}`],
              ["completos", `Completos · ${completeCount}`],
              ["resumo", `Resumo · ${lightCount}`],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => {
                setFilter(value);
                setVisible(PAGE_SIZE);
              }}
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
          onChange={(e) => {
            setQuery(e.target.value);
            setVisible(PAGE_SIZE);
          }}
          placeholder="Buscar nome, CNPJ, cidade…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum cliente neste filtro.
        </div>
      ) : (
        <>
          <p className="text-sm text-navy/55">
            {filtered.length} cliente(s)
            {shown.length < filtered.length
              ? ` · mostrando ${shown.length}`
              : ""}
          </p>
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {shown.map((client) => {
              const place =
                [client.city, client.state].filter(Boolean).join("/") || "—";
              return (
                <Link
                  key={client.id}
                  href={`/clientes/${client.id}`}
                  className="group flex flex-col rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)] transition hover:-translate-y-0.5 hover:border-brass/40"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                        Cliente
                      </p>
                      <h3 className="mt-1 font-serif text-xl text-navy group-hover:text-navy-2">
                        {client.name || "Sem nome"}
                      </h3>
                    </div>
                    {client.payloadLight ? (
                      <span className="shrink-0 rounded-full bg-warn/15 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide text-warn">
                        Resumo
                      </span>
                    ) : (
                      <span className="shrink-0 rounded-full bg-ok/15 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide text-ok">
                        Completo
                      </span>
                    )}
                  </div>
                  <p className="mt-3 text-sm text-navy/55">
                    {client.cnpj ? formatCnpj(client.cnpj) : "Sem CNPJ"}
                  </p>
                  <div className="mt-4 flex flex-wrap gap-2 text-xs text-navy/50">
                    <span className="rounded-lg bg-paper px-2.5 py-1">
                      {place}
                    </span>
                    <span className="rounded-lg bg-paper px-2.5 py-1">
                      {client.payloadLight
                        ? "Abrir p/ carregar sistemas"
                        : `${client.systemCount} sistema(s)`}
                    </span>
                  </div>
                  {client.updatedAt ? (
                    <p className="mt-auto pt-4 text-[11px] text-navy/40">
                      Atualizado{" "}
                      {new Date(client.updatedAt).toLocaleString("pt-BR")}
                    </p>
                  ) : null}
                </Link>
              );
            })}
          </div>
          {shown.length < filtered.length ? (
            <button
              type="button"
              onClick={() => setVisible((n) => n + PAGE_SIZE)}
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-semibold text-navy hover:border-brass/40"
            >
              Mostrar mais ({filtered.length - shown.length})
            </button>
          ) : null}
        </>
      )}
    </div>
  );
}
