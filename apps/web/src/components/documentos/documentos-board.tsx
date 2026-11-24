"use client";

import { useMemo, useState } from "react";
import { StatusPill } from "@/components/ui";
import { SignDocButton } from "./sign-doc-button";

export type DocumentoBoardItem = {
  id: string;
  name: string;
  staffEmail: string;
  kind: string;
  createdAt: string;
  requiresSignature: boolean;
  signedAt: string;
  signedBy: string;
  path: string;
};

type Filter = "pendentes" | "assinados" | "sem_assinatura" | "todos";

function staffDocDriveUrl(fileId: string) {
  const id = fileId.trim();
  if (!id) return "";
  return `https://drive.google.com/file/d/${encodeURIComponent(id)}/view`;
}

function formatDatePt(raw: string) {
  if (!raw) return "—";
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return raw;
  return d.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}

function kindLabel(kind: string) {
  const k = kind.trim().toLowerCase();
  if (!k) return "Documento";
  if (k.includes("holerite") || k.includes("folha")) return "Holerite";
  if (k.includes("anexo")) return "Anexo";
  if (k.includes("contrato")) return "Contrato";
  if (k.includes("aso") || k.includes("exame")) return "ASO / exame";
  return kind;
}

function signatureState(doc: DocumentoBoardItem) {
  if (doc.signedAt) return "assinados" as const;
  if (doc.requiresSignature) return "pendentes" as const;
  return "sem_assinatura" as const;
}

export function DocumentosBoard({ docs }: { docs: DocumentoBoardItem[] }) {
  const pendingCount = docs.filter(
    (d) => signatureState(d) === "pendentes",
  ).length;
  const signedCount = docs.filter(
    (d) => signatureState(d) === "assinados",
  ).length;
  const freeCount = docs.filter(
    (d) => signatureState(d) === "sem_assinatura",
  ).length;

  const [filter, setFilter] = useState<Filter>(
    pendingCount > 0 ? "pendentes" : "todos",
  );
  const [query, setQuery] = useState("");
  const [kind, setKind] = useState<string>("all");

  const kinds = useMemo(() => {
    const map = new Map<string, number>();
    for (const doc of docs) {
      const label = kindLabel(doc.kind);
      map.set(label, (map.get(label) || 0) + 1);
    }
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0], "pt-BR"));
  }, [docs]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return docs.filter((doc) => {
      const state = signatureState(doc);
      if (filter === "pendentes" && state !== "pendentes") return false;
      if (filter === "assinados" && state !== "assinados") return false;
      if (filter === "sem_assinatura" && state !== "sem_assinatura") return false;
      if (kind !== "all" && kindLabel(doc.kind) !== kind) return false;
      if (!q) return true;
      return [doc.name, doc.staffEmail, doc.kind, doc.signedBy]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [docs, filter, kind, query]);

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Pendentes de assinatura", value: pendingCount },
          { label: "Assinados", value: signedCount },
          { label: "Sem assinatura", value: freeCount },
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
              ["pendentes", `Pendentes · ${pendingCount}`],
              ["assinados", `Assinados · ${signedCount}`],
              ["sem_assinatura", `Livres · ${freeCount}`],
              ["todos", `Todos · ${docs.length}`],
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
          placeholder="Buscar documento, e-mail, tipo…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
      </div>

      {kinds.length > 1 ? (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setKind("all")}
            className={[
              "rounded-xl px-3 py-1.5 text-sm font-medium",
              kind === "all"
                ? "bg-navy text-paper"
                : "border border-navy/12 bg-white text-navy hover:border-brass/40",
            ].join(" ")}
          >
            Tipos · todos
          </button>
          {kinds.map(([label, count]) => (
            <button
              key={label}
              type="button"
              onClick={() => setKind(label)}
              className={[
                "rounded-xl px-3 py-1.5 text-sm font-medium",
                kind === label
                  ? "bg-navy text-paper"
                  : "border border-navy/12 bg-white text-navy hover:border-brass/40",
              ].join(" ")}
            >
              {label}
              <span className={kind === label ? "text-brass" : "text-navy/40"}>
                {" "}
                · {count}
              </span>
            </button>
          ))}
        </div>
      ) : null}

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum documento neste filtro.
        </div>
      ) : (
        <div className="grid gap-3 lg:grid-cols-2">
          {filtered.map((doc) => {
            const url = staffDocDriveUrl(doc.path);
            const state = signatureState(doc);
            const canSign = state === "pendentes";
            return (
              <article
                key={doc.id}
                className="flex flex-col rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_10px_28px_rgba(12,31,51,0.04)]"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                      {kindLabel(doc.kind)}
                    </p>
                    <h3 className="mt-1 font-serif text-xl text-navy">
                      {doc.name}
                    </h3>
                    <p className="mt-1 text-sm text-navy/55">
                      {doc.staffEmail || "Colaborador —"}
                    </p>
                    <p className="mt-1 text-xs text-navy/40">
                      Criado {formatDatePt(doc.createdAt)}
                      {doc.signedAt
                        ? ` · assinado ${formatDatePt(doc.signedAt)}${
                            doc.signedBy ? ` por ${doc.signedBy}` : ""
                          }`
                        : ""}
                    </p>
                  </div>
                  <StatusPill
                    label={
                      state === "assinados"
                        ? "Assinado"
                        : state === "pendentes"
                          ? "Pendente"
                          : "Sem assinatura"
                    }
                    tone={
                      state === "assinados"
                        ? "ok"
                        : state === "pendentes"
                          ? "warn"
                          : "neutral"
                    }
                  />
                </div>

                <div className="mt-auto flex flex-wrap gap-2 pt-4">
                  {url ? (
                    <a
                      href={url}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-xl bg-navy px-3 py-2 text-sm font-semibold text-paper hover:bg-navy-2"
                    >
                      Abrir no Drive ↗
                    </a>
                  ) : (
                    <span className="rounded-xl border border-dashed border-navy/15 px-3 py-2 text-sm text-muted">
                      Sem arquivo
                    </span>
                  )}
                  {canSign ? <SignDocButton id={doc.id} /> : null}
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
