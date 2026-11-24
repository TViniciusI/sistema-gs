"use client";

import { useMemo, useState } from "react";
import type { CampoAuditEntry } from "@/lib/campo-data";
import {
  actionLabel,
  entityLabel,
  formatAuditActor,
} from "@/lib/campo-data";
import { StatusPill } from "@/components/ui";

type EntityFilter = "todos" | string;
type SourceFilter = "todos" | "escritorio" | "campo";

export function AuditoriaBoard({ entries }: { entries: CampoAuditEntry[] }) {
  const [query, setQuery] = useState("");
  const [entity, setEntity] = useState<EntityFilter>("todos");
  const [source, setSource] = useState<SourceFilter>("todos");

  const entities = useMemo(() => {
    const map = new Map<string, number>();
    for (const e of entries) {
      const key = e.entity || "outro";
      map.set(key, (map.get(key) || 0) + 1);
    }
    return [...map.entries()]
      .map(([id, count]) => ({ id, count }))
      .sort((a, b) => b.count - a.count);
  }, [entries]);

  const counts = useMemo(() => {
    let escritorio = 0;
    let campo = 0;
    for (const e of entries) {
      if (e.source === "escritorio") escritorio += 1;
      else if (e.source === "campo") campo += 1;
    }
    return { total: entries.length, escritorio, campo };
  }, [entries]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return entries.filter((e) => {
      if (entity !== "todos" && e.entity !== entity) return false;
      if (source !== "todos" && e.source !== source) return false;
      if (!q) return true;
      return [
        e.actorName,
        e.actorLogin,
        e.actorEmail,
        e.summary,
        e.entity,
        e.entityId,
        e.action,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [entries, query, entity, source]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Registros", value: counts.total },
          { label: "Escritório", value: counts.escritorio },
          { label: "App de campo", value: counts.campo },
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
          onClick={() => setEntity("todos")}
          className={[
            "rounded-xl px-3.5 py-2 text-sm font-medium transition",
            entity === "todos"
              ? "bg-navy text-brass"
              : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
          ].join(" ")}
        >
          Todos · {entries.length}
        </button>
        {entities.map((e) => (
          <button
            key={e.id}
            type="button"
            onClick={() => setEntity(e.id)}
            className={[
              "rounded-xl px-3.5 py-2 text-sm font-medium transition",
              entity === e.id
                ? "bg-navy text-brass"
                : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
            ].join(" ")}
          >
            {entityLabel(e.id)} · {e.count}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["todos", "Todas as origens"],
              ["escritorio", "Escritório"],
              ["campo", "Campo"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setSource(value)}
              className={[
                "rounded-lg px-3.5 py-2 text-sm font-medium transition",
                source === value
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
          placeholder="Buscar pessoa, OS, cliente, resumo…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhuma alteração neste filtro.
          {entries.length === 0
            ? " As próximas mudanças do escritório e do app passam a aparecer aqui (após republicar o Apps Script)."
            : ""}
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((entry, index) => {
            const actor = formatAuditActor(entry);
            const when = entry.at
              ? new Date(entry.at).toLocaleString("pt-BR", {
                  timeZone: "America/Sao_Paulo",
                })
              : "—";
            return (
              <article
                key={`${entry.at}-${entry.entityId}-${index}`}
                className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                      {entityLabel(entry.entity)}
                      {entry.entityId ? ` · ${entry.entityId}` : ""}
                    </p>
                    <h3 className="mt-1 font-serif text-xl text-navy">
                      {actionLabel(entry.action)}
                      {entry.summary ? ` — ${entry.summary}` : ""}
                    </h3>
                    <p className="mt-1 text-sm text-navy/55">
                      Por <span className="font-medium text-navy">{actor}</span>
                      {entry.actorLogin ? ` · @${entry.actorLogin}` : ""}
                    </p>
                  </div>
                  <div className="flex flex-col items-end gap-2">
                    <StatusPill
                      label={
                        entry.source === "escritorio"
                          ? "Escritório"
                          : entry.source === "campo"
                            ? "Campo"
                            : entry.source || "—"
                      }
                      tone={entry.source === "escritorio" ? "ok" : "neutral"}
                    />
                    <p className="text-xs text-navy/45">{when}</p>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
