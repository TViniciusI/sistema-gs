"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";
import { StatusPill } from "@/components/ui";
import {
  deleteFluidoAction,
  saveFluidoAction,
} from "@/app/(app)/fluidos/actions";

export type FluidoBoardItem = {
  id: string;
  name: string;
  densityMin: string;
  densityMax: string;
  viscosityMin: string;
  viscosityMax: string;
  densityRefTemp: string;
  viscosityRefTemp: string;
  updatedAt: string;
  updatedByName?: string;
};

const COMMON_FLUIDS = [
  "Diesel S10",
  "Diesel S500",
  "Gasolina C",
  "Etanol hidratado",
  "Querosene de aviação (QAV)",
  "Óleo combustível",
  "Água",
  "Biodiesel",
];

type CompletenessFilter = "todos" | "completos" | "incompletos";

function text(value: string | undefined) {
  return String(value ?? "").trim();
}

function rangeLabel(min: string, max: string, unitHint = "") {
  const a = text(min);
  const b = text(max);
  if (a && b && a !== b) return `${a} a ${b}${unitHint ? ` ${unitHint}` : ""}`;
  if (a || b) return `${a || b}${unitHint ? ` ${unitHint}` : ""}`;
  return "—";
}

function isComplete(item: FluidoBoardItem) {
  return Boolean(
    text(item.densityMin) ||
      text(item.densityMax) ||
      text(item.viscosityMin) ||
      text(item.viscosityMax),
  );
}

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm text-navy outline-none focus:border-brass";

function FluidoEditor({
  initial,
  onDone,
}: {
  initial?: Partial<FluidoBoardItem>;
  onDone?: () => void;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [name, setName] = useState(initial?.name || "");
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
          const result = await saveFluidoAction({}, fd);
          if (result.error) {
            setError(result.error);
            return;
          }
          setOk(true);
          e.currentTarget.reset();
          if (!isEdit) setName("");
          onDone?.();
          router.refresh();
        });
      }}
    >
      {initial?.id ? <input type="hidden" name="id" value={initial.id} /> : null}
      {error ? (
        <p className="sm:col-span-2 lg:col-span-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}
      {ok ? (
        <p className="sm:col-span-2 lg:col-span-3 text-sm text-ok">
          {isEdit ? "Fluido atualizado." : "Fluido salvo na planilha."}
        </p>
      ) : null}

      <label className="block text-sm lg:col-span-3">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Nome do fluido *
        </span>
        <input
          name="name"
          required
          list="fluido-nomes"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ex.: Diesel S10"
          className={inputClass}
        />
        <datalist id="fluido-nomes">
          {COMMON_FLUIDS.map((f) => (
            <option key={f} value={f} />
          ))}
        </datalist>
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Densidade mín.
        </span>
        <input
          name="densityMin"
          defaultValue={initial?.densityMin || ""}
          placeholder="ex.: 820"
          className={inputClass}
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Densidade máx.
        </span>
        <input
          name="densityMax"
          defaultValue={initial?.densityMax || ""}
          placeholder="ex.: 860"
          className={inputClass}
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Temp. dens. (ref.)
        </span>
        <input
          name="densityRefTemp"
          defaultValue={initial?.densityRefTemp || "20 °C"}
          className={inputClass}
        />
      </label>

      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Viscosidade mín.
        </span>
        <input
          name="viscosityMin"
          defaultValue={initial?.viscosityMin || ""}
          placeholder="ex.: 2,0"
          className={inputClass}
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Viscosidade máx.
        </span>
        <input
          name="viscosityMax"
          defaultValue={initial?.viscosityMax || ""}
          placeholder="ex.: 4,5"
          className={inputClass}
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] uppercase tracking-wide text-navy/45">
          Temp. visc. (ref.)
        </span>
        <input
          name="viscosityRefTemp"
          defaultValue={initial?.viscosityRefTemp || "40 °C"}
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
              : "Cadastrar fluido"}
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

export function FluidosBoard({ items }: { items: FluidoBoardItem[] }) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<CompletenessFilter>("todos");
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [pendingDelete, startDelete] = useTransition();

  const counts = useMemo(() => {
    let withDensity = 0;
    let withViscosity = 0;
    let incompletos = 0;
    for (const item of items) {
      if (text(item.densityMin) || text(item.densityMax)) withDensity += 1;
      if (text(item.viscosityMin) || text(item.viscosityMax)) withViscosity += 1;
      if (!isComplete(item)) incompletos += 1;
    }
    return {
      total: items.length,
      withDensity,
      withViscosity,
      incompletos,
      completos: items.length - incompletos,
    };
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items
      .filter((item) => {
        if (filter === "completos" && !isComplete(item)) return false;
        if (filter === "incompletos" && isComplete(item)) return false;
        if (!q) return true;
        return [
          item.name,
          item.densityMin,
          item.densityMax,
          item.viscosityMin,
          item.viscosityMax,
          item.densityRefTemp,
          item.viscosityRefTemp,
        ]
          .join(" ")
          .toLowerCase()
          .includes(q);
      })
      .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
  }, [items, query, filter]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Fluidos", value: counts.total },
          { label: "Com densidade", value: counts.withDensity },
          { label: "Com viscosidade", value: counts.withViscosity },
          { label: "Incompletos", value: counts.incompletos },
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
              {showForm ? "Novo fluido" : "Incluir fluido"}
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              Mesma planilha do GS Campo — densidade e viscosidade usadas na
              calibração.
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
            {showForm ? "Fechar formulário" : "+ Novo fluido"}
          </button>
        </div>
        {showForm ? (
          <div className="mt-4 border-t border-navy/10 pt-4">
            <FluidoEditor onDone={() => setShowForm(false)} />
          </div>
        ) : null}
      </section>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap rounded-xl border border-navy/10 bg-white p-1">
          {(
            [
              ["todos", `Todos · ${counts.total}`],
              ["completos", `Completos · ${counts.completos}`],
              ["incompletos", `Incompletos · ${counts.incompletos}`],
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
          placeholder="Buscar nome, densidade, viscosidade…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
        <Link
          href="/calibracao"
          className="rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
        >
          Ir à calibração
        </Link>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum fluido neste filtro. Cadastre o primeiro com “+ Novo fluido”.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.map((item) => {
            const editing = editingId === item.id;
            const complete = isComplete(item);
            return (
              <article
                key={item.id}
                className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)]"
              >
                {editing ? (
                  <FluidoEditor
                    initial={item}
                    onDone={() => setEditingId(null)}
                  />
                ) : (
                  <>
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                          Fluido
                        </p>
                        <h3 className="mt-1 font-serif text-2xl text-navy">
                          {item.name}
                        </h3>
                      </div>
                      <StatusPill
                        label={complete ? "Completo" : "Incompleto"}
                        tone={complete ? "ok" : "warn"}
                      />
                    </div>

                    <dl className="mt-4 grid gap-2 sm:grid-cols-2">
                      <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                        <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                          Densidade
                        </dt>
                        <dd className="mt-0.5 text-sm font-medium text-navy">
                          {rangeLabel(item.densityMin, item.densityMax)}
                        </dd>
                        <dd className="mt-0.5 text-xs text-navy/45">
                          ref. {text(item.densityRefTemp) || "20 °C"}
                        </dd>
                      </div>
                      <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                        <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                          Viscosidade
                        </dt>
                        <dd className="mt-0.5 text-sm font-medium text-navy">
                          {rangeLabel(item.viscosityMin, item.viscosityMax)}
                        </dd>
                        <dd className="mt-0.5 text-xs text-navy/45">
                          ref. {text(item.viscosityRefTemp) || "40 °C"}
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
                            await deleteFluidoAction(item.id);
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
