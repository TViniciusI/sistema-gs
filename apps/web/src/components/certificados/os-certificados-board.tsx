"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { kindLabel } from "@/lib/campo-data/kind-labels";

export type OsCertRow = {
  slotId: string;
  jobId: string;
  kind: string;
  certificateNumber: string;
  equipmentTag: string;
  equipmentType: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
  installLocation: string;
  jobStatus: string;
  hasCalibration: boolean;
  hasPdf: boolean;
  pdfUrl: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  technicianName: string;
};

export type OsCertGroup = {
  kind: string;
  label: string;
  stats: string;
  items: OsCertRow[];
};

export function OsCertificadosBoard({
  osId,
  groups,
  initialKind = "",
}: {
  osId: string;
  groups: OsCertGroup[];
  initialKind?: string;
}) {
  const [kind, setKind] = useState(initialKind);
  const [query, setQuery] = useState("");
  const [onlyMissing, setOnlyMissing] = useState(false);

  const allItems = useMemo(
    () => groups.flatMap((g) => g.items.map((item) => ({ ...item, kind: item.kind || g.kind }))),
    [groups],
  );

  const counts = useMemo(() => {
    let withCalib = 0;
    let withPdf = 0;
    let missing = 0;
    for (const item of allItems) {
      if (item.hasCalibration) withCalib += 1;
      else missing += 1;
      if (item.hasPdf) withPdf += 1;
    }
    return {
      total: allItems.length,
      withCalib,
      withPdf,
      missing,
      kinds: groups.length,
    };
  }, [allItems, groups.length]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return allItems.filter((item) => {
      if (kind && (item.kind || "") !== kind) return false;
      if (onlyMissing && item.hasCalibration) return false;
      if (!q) return true;
      return [
        item.certificateNumber,
        item.equipmentTag,
        item.equipmentType,
        item.serialNumber,
        item.manufacturer,
        item.model,
        item.installLocation,
        item.technicianName,
        kindLabel(item.kind),
        item.jobStatus,
      ]
        .join(" ")
        .toLowerCase()
        .includes(q);
    });
  }, [allItems, kind, onlyMissing, query]);

  if (groups.length === 0) {
    return (
      <p className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
        Nenhum certificado nesta OS. Crie os slots no GS Campo (volumétrica,
        temperatura, densidade…).
      </p>
    );
  }

  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: "Certificados", value: counts.total },
          { label: "Tipos", value: counts.kinds },
          { label: "Com calibração", value: counts.withCalib },
          { label: "PDF no Drive", value: counts.withPdf },
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
          onClick={() => setKind("")}
          className={[
            "rounded-xl px-3.5 py-2 text-sm font-medium transition",
            !kind
              ? "bg-navy text-brass"
              : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
          ].join(" ")}
        >
          Todos · {counts.total}
        </button>
        {groups.map((group) => (
          <button
            key={group.kind}
            type="button"
            onClick={() => setKind(group.kind)}
            className={[
              "rounded-xl px-3.5 py-2 text-sm font-medium transition",
              kind === group.kind
                ? "bg-navy text-brass"
                : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
            ].join(" ")}
            title={group.stats}
          >
            {group.label} · {group.items.length}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar nº, TAG, N/S, fabricante…"
          className="min-w-[220px] flex-1 rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm outline-none focus:border-brass"
        />
        <button
          type="button"
          onClick={() => setOnlyMissing((v) => !v)}
          className={[
            "rounded-xl px-3.5 py-2.5 text-sm font-medium transition",
            onlyMissing
              ? "bg-warn/15 text-navy"
              : "border border-navy/10 bg-white text-navy/65 hover:text-navy",
          ].join(" ")}
        >
          Só sem calibração
          {counts.missing ? ` · ${counts.missing}` : ""}
        </button>
        <Link
          href={`/os/${osId}/livro`}
          className="rounded-xl border border-navy/10 bg-white px-3.5 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
        >
          Livro da OS
        </Link>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-14 text-center text-sm text-muted">
          Nenhum certificado neste filtro.
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((item) => {
            const detailHref = `/os/${osId}/certificados/${encodeURIComponent(item.slotId)}`;
            return (
              <article
                key={item.slotId}
                className="rounded-3xl border border-navy/10 bg-white p-5 shadow-[0_8px_24px_rgba(12,31,51,0.04)] transition hover:border-brass/35"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
                      {kindLabel(item.kind)}
                    </p>
                    <Link
                      href={detailHref}
                      className="mt-1 block font-serif text-2xl text-navy hover:text-navy-2"
                    >
                      {item.certificateNumber || "Sem número"}
                    </Link>
                    <p className="mt-1 text-sm text-navy/55">
                      {[
                        item.equipmentTag && `TAG ${item.equipmentTag}`,
                        item.equipmentType,
                        item.serialNumber && `N/S ${item.serialNumber}`,
                      ]
                        .filter(Boolean)
                        .join(" · ") || "Instrumento sem identificação"}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <span
                      className={[
                        "rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-wide",
                        item.hasCalibration
                          ? "bg-ok/15 text-ok"
                          : "bg-warn/15 text-warn",
                      ].join(" ")}
                    >
                      {item.hasCalibration
                        ? item.jobStatus || "Com calibração"
                        : "Sem calibração"}
                    </span>
                    {item.hasPdf ? (
                      <span className="rounded-full bg-navy/10 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-navy">
                        PDF
                      </span>
                    ) : null}
                  </div>
                </div>

                <dl className="mt-4 grid gap-2 sm:grid-cols-3">
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Fabricante / modelo
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {[item.manufacturer, item.model].filter(Boolean).join(" ") ||
                        "—"}
                    </dd>
                  </div>
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Calibrado → próxima
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {[item.calibrationDate || "—", item.nextCalibrationDate || "—"].join(
                        " → ",
                      )}
                    </dd>
                  </div>
                  <div className="rounded-2xl bg-paper/80 px-3 py-2.5">
                    <dt className="text-[10px] uppercase tracking-wide text-navy/40">
                      Local / técnico
                    </dt>
                    <dd className="mt-0.5 text-sm font-medium text-navy">
                      {[item.installLocation, item.technicianName]
                        .filter(Boolean)
                        .join(" · ") || "—"}
                    </dd>
                  </div>
                </dl>

                <div className="mt-4 flex flex-wrap gap-2">
                  <Link
                    href={detailHref}
                    className="rounded-xl bg-navy px-3.5 py-2 text-xs font-semibold text-brass hover:bg-navy-2"
                  >
                    Detalhe / bancada
                  </Link>
                  {item.hasPdf && item.pdfUrl ? (
                    <a
                      href={item.pdfUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-xl bg-brass px-3.5 py-2 text-xs font-semibold text-navy hover:bg-brass-2"
                    >
                      PDF Drive ↗
                    </a>
                  ) : null}
                  {item.hasCalibration && item.jobId ? (
                    <Link
                      href={`/calibracao/${encodeURIComponent(item.jobId)}`}
                      className="rounded-xl border border-navy/12 bg-white px-3.5 py-2 text-xs font-medium text-navy hover:border-brass/40"
                    >
                      Abrir calibração
                    </Link>
                  ) : null}
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}
