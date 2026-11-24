"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { StatusPill } from "@/components/ui";
import { deletePadraoAction, savePadraoAction } from "@/app/(app)/padroes/actions";

export type PadraoBoardItem = {
  id: string;
  name: string;
  type: string;
  serial: string;
  certificate: string;
  validity: string;
  uncertainty: string;
  coverageK: string;
  updatedAt: string;
  updatedByName?: string;
};

const COMMON_TYPES = [
  "Proveta",
  "Medidor mássico",
  "Termômetro",
  "PT100",
  "Densímetro",
  "Manômetro",
  "Multímetro",
  "Balança",
  "Solução padrão",
  "Outro",
];

type ValidityFilter = "todos" | "em_dia" | "a_vencer" | "vencidos" | "sem_data";

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

function validityMeta(raw: string): {
  tone: "ok" | "warn" | "danger" | "neutral";
  label: string;
  days: number | null;
  date: Date | null;
} {
  const date = parseValidity(raw);
  if (!date) return { tone: "neutral", label: "Sem validade", days: null, date: null };
  const days = Math.ceil((date.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
  if (days < 0) return { tone: "danger", label: "Vencido", days, date };
  if (days <= 60) return { tone: "warn", label: `A vencer · ${days}d`, days, date };
  return { tone: "ok", label: "Em dia", days, date };
}

function formatValidity(raw: string) {
  const date = parseValidity(raw);
  if (!date) return raw.trim() || "—";
  return date.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm text-navy outline-none focus:border-brass";

function PadraoEditor({
  initial,
  onDone,
}: {
  initial?: Partial<PadraoBoardItem>;
  onDone?: () => void;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [type, setType] = useState(initial?.type || "");
  const isEdit = Boolean(initial?.id);

  return (
    <form
      className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        setError(null);
        setOk(false);
        startTransition(async () => {
          const result = await savePadraoAction({}, fd);
          if (result.error) {
            setError(result.error);
            return;
          }
          setOk(true);
          e.currentTarget.reset();
          if (!isEdit) setType("");
          onDone?.();
          router.refresh();
        });
      }}
    >
      {initial?.id ? <input type="hidden" name="id" value={initial.id} /> : null}
      {error ? (
        <p className="sm:col-span-2 lg:col-span-3 text-sm text-red-700">{error}</p>
      ) : null}
      {ok ? (
        <p className="sm:col-span-2 lg:col-span-3 text-sm text-ok">
          {isEdit ? "Padrão atualizado." : "Padrão salvo na planilha."}
        </p>
      ) : null}

      <label className="block text-sm lg:col-span-2">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Nome / TAG *
        </span>
        <input
          name="name"
          required
          defaultValue={initial?.name || ""}
          placeholder="Ex.: Proveta 20 L · P-01"
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Tipo
        </span>
        <input
          name="type"
          list="padrao-tipos"
          value={type}
          onChange={(e) => setType(e.target.value)}
          placeholder="Proveta, densímetro…"
          className={inputClass}
        />
        <datalist id="padrao-tipos">
          {COMMON_TYPES.map((t) => (
            <option key={t} value={t} />
          ))}
        </datalist>
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Nº de série
        </span>
        <input
          name="serial"
          defaultValue={initial?.serial || ""}
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Certificado do padrão
        </span>
        <input
          name="certificate"
          defaultValue={initial?.certificate || ""}
          placeholder="Nº do certificado RBC/lab"
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Validade
        </span>
        <input
          name="validity"
          type="date"
          defaultValue={(() => {
            const d = parseValidity(initial?.validity || "");
            if (!d) return "";
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const day = String(d.getDate()).padStart(2, "0");
            return `${y}-${m}-${day}`;
          })()}
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Incerteza
        </span>
        <input
          name="uncertainty"
          defaultValue={initial?.uncertainty || ""}
          placeholder="ex.: 0,05 %"
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Fator k
        </span>
        <input
          name="coverageK"
          defaultValue={initial?.coverageK || ""}
          placeholder="ex.: 2"
          className={inputClass}
        />
      </label>

      <div className="flex flex-wrap items-end gap-2 sm:col-span-2 lg:col-span-3">
        <button
          type="submit"
          disabled={pending}
          className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          {pending
            ? "Salvando…"
            : isEdit
              ? "Salvar alterações"
              : "Cadastrar padrão"}
        </button>
        {onDone && isEdit ? (
          <button
            type="button"
            onClick={onDone}
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Cancelar
          </button>
        ) : null}
      </div>
    </form>
  );
}

export function PadroesBoard({ items }: { items: PadraoBoardItem[] }) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [typeFilter, setTypeFilter] = useState("todos");
  const [validityFilter, setValidityFilter] =
    useState<ValidityFilter>("todos");
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [pendingDelete, startDelete] = useTransition();

  const types = useMemo(() => {
    const map = new Map<string, number>();
    for (const item of items) {
      const key = item.type.trim() || "Sem tipo";
      map.set(key, (map.get(key) || 0) + 1);
    }
    return [...map.entries()]
      .map(([type, count]) => ({ type, count }))
      .sort((a, b) => b.count - a.count || a.type.localeCompare(b.type));
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
    return { total: items.length, emDia, aVencer, vencidos, semData };
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items
      .filter((item) => {
        const typeKey = item.type.trim() || "Sem tipo";
        if (typeFilter !== "todos" && typeKey !== typeFilter) return false;
        const meta = validityMeta(item.validity);
        if (validityFilter === "em_dia" && meta.tone !== "ok") return false;
        if (validityFilter === "a_vencer" && meta.tone !== "warn") return false;
        if (validityFilter === "vencidos" && meta.tone !== "danger") return false;
        if (validityFilter === "sem_data" && meta.tone !== "neutral") return false;
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
        const da = parseValidity(a.validity)?.getTime() ?? Number.POSITIVE_INFINITY;
        const db = parseValidity(b.validity)?.getTime() ?? Number.POSITIVE_INFINITY;
        if (validityFilter === "vencidos" || validityFilter === "a_vencer") {
          return da - db;
        }
        return a.name.localeCompare(b.name, "pt-BR");
      });
  }, [items, query, typeFilter, validityFilter]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Padrões", value: counts.total },
          { label: "Em dia", value: counts.emDia },
          { label: "A vencer (≤60d)", value: counts.aVencer },
          { label: "Vencidos", value: counts.vencidos },
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

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Cadastro
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              {showForm ? "Novo padrão" : "Incluir padrão"}
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              Mesma planilha do GS Campo — usado nas calibrações e certificados.
            </p>
          </div>
          <button
            type="button"
            onClick={() => {
              setShowForm((v) => !v);
              setEditingId(null);
            }}
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            {showForm ? "Fechar formulário" : "+ Novo padrão"}
          </button>
        </div>
        {showForm ? (
          <div className="mt-4 border-t border-navy/10 pt-4">
            <PadraoEditor
              onDone={() => {
                setShowForm(false);
              }}
            />
          </div>
        ) : null}
      </section>

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
              ["todos", "Todos"],
              ["em_dia", "Em dia"],
              ["a_vencer", "A vencer"],
              ["vencidos", "Vencidos"],
              ["sem_data", "Sem data"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setValidityFilter(value)}
              className={[
                "rounded-lg px-3.5 py-2 text-sm font-medium transition",
                validityFilter === value
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
          href="/vencimentos"
          className="rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
        >
          Ver vencimentos
        </Link>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum padrão neste filtro. Cadastre o primeiro com “+ Novo padrão”.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.map((item) => {
            const meta = validityMeta(item.validity);
            const editing = editingId === item.id;
            return (
              <article
                key={item.id}
                className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)]"
              >
                {editing ? (
                  <PadraoEditor
                    initial={item}
                    onDone={() => setEditingId(null)}
                  />
                ) : (
                  <>
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                          {item.type || "Padrão"}
                        </p>
                        <h3 className="mt-1 font-serif text-2xl text-navy">
                          {item.name}
                        </h3>
                        <p className="mt-1 text-sm text-navy/55">
                          {[
                            item.serial && `N/S ${item.serial}`,
                            item.certificate && `Cert. ${item.certificate}`,
                          ]
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
                          Incerteza
                        </dt>
                        <dd className="mt-0.5 text-sm font-medium text-navy">
                          {item.uncertainty || "—"}
                        </dd>
                      </div>
                      <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                        <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                          k
                        </dt>
                        <dd className="mt-0.5 text-sm font-medium text-navy">
                          {item.coverageK || "—"}
                        </dd>
                      </div>
                    </dl>
                    {item.updatedByName ? (
                      <p className="mt-3 text-xs text-navy/45">
                        Última alteração por{" "}
                        <span className="font-medium text-navy/65">
                          {item.updatedByName}
                        </span>
                      </p>
                    ) : null}

                    <div className="mt-4 flex flex-wrap gap-2">
                      <button
                        type="button"
                        onClick={() => {
                          setShowForm(false);
                          setEditingId(item.id);
                        }}
                        className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
                      >
                        Editar
                      </button>
                      <button
                        type="button"
                        disabled={pendingDelete && deletingId === item.id}
                        onClick={() => {
                          if (!window.confirm(`Apagar ${item.name}?`)) return;
                          setDeletingId(item.id);
                          startDelete(async () => {
                            await deletePadraoAction(item.id);
                            setDeletingId(null);
                            router.refresh();
                          });
                        }}
                        className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-red-700 hover:border-red-300 disabled:opacity-60"
                      >
                        {pendingDelete && deletingId === item.id
                          ? "Apagando…"
                          : "Apagar"}
                      </button>
                    </div>
                  </>
                )}
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
