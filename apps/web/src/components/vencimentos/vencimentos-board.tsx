"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";

export type VencimentoItem = {
  id: string;
  name: string;
  type: string;
  serial: string;
  certificate: string;
  validity: string;
  uncertainty: string;
  coverageK: string;
};

type UrgencyFilter =
  | "atencao"
  | "vencidos"
  | "a_vencer"
  | "em_dia"
  | "sem_data"
  | "todos";

const WARN_DAYS = 60;

function parseValidity(raw: string): Date | null {
  const s = raw.trim();
  if (!s) return null;
  const iso = Date.parse(s);
  if (Number.isFinite(iso)) return new Date(iso);
  const br = s.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$/);
  if (br) {
    const d = Number(br[1]);
    const m = Number(br[2]);
    let y = Number(br[3]);
    if (y < 100) y += 2000;
    const dt = new Date(y, m - 1, d);
    return Number.isNaN(dt.getTime()) ? null : dt;
  }
  return null;
}

function startOfToday() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function validityMeta(raw: string): {
  tone: "ok" | "warn" | "danger" | "neutral";
  label: string;
  days: number | null;
  date: Date | null;
} {
  const date = parseValidity(raw);
  if (!date) {
    return { tone: "neutral", label: "Sem validade", days: null, date: null };
  }
  const days = Math.ceil(
    (date.getTime() - startOfToday().getTime()) / (1000 * 60 * 60 * 24),
  );
  if (days < 0) {
    return {
      tone: "danger",
      label: days === -1 ? "Venceu ontem" : `Vencido há ${Math.abs(days)}d`,
      days,
      date,
    };
  }
  if (days === 0) {
    return { tone: "danger", label: "Vence hoje", days, date };
  }
  if (days <= WARN_DAYS) {
    return {
      tone: "warn",
      label: days === 1 ? "Vence amanhã" : `A vencer · ${days}d`,
      days,
      date,
    };
  }
  return { tone: "ok", label: `Em dia · ${days}d`, days, date };
}

function formatValidity(raw: string) {
  const date = parseValidity(raw);
  if (!date) return raw.trim() || "—";
  return date.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}

function urgencyRank(meta: ReturnType<typeof validityMeta>) {
  if (meta.tone === "danger") return 0;
  if (meta.tone === "warn") return 1;
  if (meta.tone === "ok") return 2;
  return 3;
}

export function VencimentosBoard({ items }: { items: VencimentoItem[] }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<UrgencyFilter>("atencao");
  const [typeFilter, setTypeFilter] = useState("todos");

  const types = useMemo(() => {
    const map = new Map<string, number>();
    for (const item of items) {
      const key = item.type.trim() || "Sem tipo";
      map.set(key, (map.get(key) || 0) + 1);
    }
    return [...map.entries()]
      .map(([type, count]) => ({ type, count }))
      .sort((a, b) => b.count - a.count || a.type.localeCompare(b.type, "pt-BR"));
  }, [items]);

  const counts = useMemo(() => {
    let emDia = 0;
    let aVencer = 0;
    let vencidos = 0;
    let semData = 0;
    for (const item of items) {
      const meta = validityMeta(item.validity);
      if (meta.tone === "ok") emDia += 1;
      else if (meta.tone === "warn") aVencer += 1;
      else if (meta.tone === "danger") vencidos += 1;
      else semData += 1;
    }
    return {
      total: items.length,
      emDia,
      aVencer,
      vencidos,
      semData,
      atencao: vencidos + aVencer,
    };
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items
      .filter((item) => {
        const typeKey = item.type.trim() || "Sem tipo";
        if (typeFilter !== "todos" && typeKey !== typeFilter) return false;
        const meta = validityMeta(item.validity);
        if (filter === "atencao" && meta.tone !== "danger" && meta.tone !== "warn") {
          return false;
        }
        if (filter === "vencidos" && meta.tone !== "danger") return false;
        if (filter === "a_vencer" && meta.tone !== "warn") return false;
        if (filter === "em_dia" && meta.tone !== "ok") return false;
        if (filter === "sem_data" && meta.tone !== "neutral") return false;
        if (!q) return true;
        return [
          item.name,
          item.type,
          item.serial,
          item.certificate,
          item.uncertainty,
          item.coverageK,
        ]
          .join(" ")
          .toLowerCase()
          .includes(q);
      })
      .sort((a, b) => {
        const ma = validityMeta(a.validity);
        const mb = validityMeta(b.validity);
        const rank = urgencyRank(ma) - urgencyRank(mb);
        if (rank !== 0) return rank;
        const da = ma.date?.getTime() ?? Number.POSITIVE_INFINITY;
        const db = mb.date?.getTime() ?? Number.POSITIVE_INFINITY;
        if (da !== db) return da - db;
        return a.name.localeCompare(b.name, "pt-BR");
      });
  }, [items, query, filter, typeFilter]);

  const nextDue = useMemo(() => {
    const dated = items
      .map((item) => ({ item, meta: validityMeta(item.validity) }))
      .filter((x) => x.meta.date && (x.meta.tone === "warn" || x.meta.tone === "danger"))
      .sort(
        (a, b) =>
          (a.meta.date?.getTime() ?? 0) - (b.meta.date?.getTime() ?? 0),
      );
    return dated[0] ?? null;
  }, [items]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Precisam de atenção", value: counts.atencao, hint: "Vencidos + ≤60d" },
          { label: "Vencidos", value: counts.vencidos, hint: "Recalibrar" },
          { label: "A vencer (≤60d)", value: counts.aVencer, hint: "Planejar" },
          { label: "Em dia", value: counts.emDia, hint: `De ${counts.total} padrões` },
        ].map((kpi) => (
          <div
            key={kpi.label}
            className="rounded-2xl border border-navy/10 bg-white px-4 py-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
          >
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              {kpi.label}
            </p>
            <p className="mt-2 font-serif text-3xl text-navy">{kpi.value}</p>
            <p className="mt-1 text-xs text-navy/45">{kpi.hint}</p>
          </div>
        ))}
      </div>

      {nextDue ? (
        <section className="rounded-3xl border border-navy/10 bg-gradient-to-br from-white via-white to-paper p-5 md:p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Próximo crítico
          </p>
          <div className="mt-2 flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h2 className="font-serif text-2xl text-navy">{nextDue.item.name}</h2>
              <p className="mt-1 text-sm text-navy/55">
                {[nextDue.item.type, nextDue.item.serial]
                  .filter(Boolean)
                  .join(" · ") || "Padrão de calibração"}
              </p>
            </div>
            <StatusPill label={nextDue.meta.label} tone={nextDue.meta.tone} />
          </div>
          <p className="mt-3 text-sm text-navy/70">
            Validade {formatValidity(nextDue.item.validity)}
            {nextDue.item.certificate
              ? ` · Cert. ${nextDue.item.certificate}`
              : ""}
          </p>
        </section>
      ) : (
        <section className="rounded-3xl border border-dashed border-navy/15 bg-white px-5 py-8 text-center">
          <p className="font-serif text-xl text-navy">Nada urgente no momento</p>
          <p className="mt-1 text-sm text-navy/55">
            Nenhum padrão vencido ou a vencer nos próximos {WARN_DAYS} dias.
          </p>
        </section>
      )}

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setTypeFilter("todos")}
          className={[
            "rounded-xl px-3.5 py-2 text-sm font-medium transition",
            typeFilter === "todos"
              ? "bg-navy text-brass"
              : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
          ].join(" ")}
        >
          Todos · {items.length}
        </button>
        {types.map((t) => (
          <button
            key={t.type}
            type="button"
            onClick={() => setTypeFilter(t.type)}
            className={[
              "rounded-xl px-3.5 py-2 text-sm font-medium transition",
              typeFilter === t.type
                ? "bg-navy text-brass"
                : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
            ].join(" ")}
          >
            {t.type} · {t.count}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["atencao", `Atenção · ${counts.atencao}`],
              ["vencidos", `Vencidos · ${counts.vencidos}`],
              ["a_vencer", `A vencer · ${counts.aVencer}`],
              ["em_dia", `Em dia · ${counts.emDia}`],
              ["sem_data", `Sem data · ${counts.semData}`],
              ["todos", "Todos"],
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
          placeholder="Buscar TAG, N/S, certificado, tipo…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
        <Link
          href="/padroes"
          className="rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
        >
          Cadastro de padrões
        </Link>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum padrão neste filtro.
          {filter === "atencao"
            ? " Tudo em dia — use “Em dia” ou “Todos” para ver o restante."
            : " Ajuste a busca ou o tipo."}
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.map((item) => {
            const meta = validityMeta(item.validity);
            return (
              <article
                key={item.id}
                className={[
                  "rounded-3xl border bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)]",
                  meta.tone === "danger"
                    ? "border-red-200"
                    : meta.tone === "warn"
                      ? "border-amber-200"
                      : "border-navy/10",
                ].join(" ")}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                      {item.type.trim() || "Padrão"}
                    </p>
                    <h3 className="mt-1 font-serif text-2xl text-navy">
                      {item.name}
                    </h3>
                    <p className="mt-1 text-sm text-navy/50">
                      {[item.serial && `N/S ${item.serial}`, item.certificate && `Cert. ${item.certificate}`]
                        .filter(Boolean)
                        .join(" · ") || "Sem N/S / certificado"}
                    </p>
                  </div>
                  <StatusPill label={meta.label} tone={meta.tone} />
                </div>

                <dl className="mt-4 grid gap-2 sm:grid-cols-3">
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Validade
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {formatValidity(item.validity)}
                    </dd>
                  </div>
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Dias
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {meta.days == null
                        ? "—"
                        : meta.days < 0
                          ? `−${Math.abs(meta.days)}`
                          : meta.days}
                    </dd>
                  </div>
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Incerteza
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {item.uncertainty.trim()
                        ? `${item.uncertainty}${item.coverageK ? ` (k=${item.coverageK})` : ""}`
                        : "—"}
                    </dd>
                  </div>
                </dl>

                <div className="mt-4 flex flex-wrap gap-2">
                  <Link
                    href="/padroes"
                    className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
                  >
                    Atualizar no cadastro
                  </Link>
                  <Link
                    href="/calibracao"
                    className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
                  >
                    Ir à calibração
                  </Link>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
