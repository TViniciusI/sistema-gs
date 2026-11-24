"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import {
  driveFileKindLabel,
  type DriveFileKind,
} from "@/lib/campo-data";
import { DriveFileCard } from "./drive-file-card";
import type { ArquivoGalleryItem } from "./arquivos-gallery";

export type ArquivoOsBundle = {
  osId: string;
  osNumber: string;
  clientName: string;
  statusLabel: string;
  statusTone: "ok" | "warn" | "danger" | "neutral";
  folderUrl: string;
  open: boolean;
  items: ArquivoGalleryItem[];
};

const KIND_FILTERS: Array<{ key: "all" | DriveFileKind; label: string }> = [
  { key: "all", label: "Todos" },
  { key: "rdo", label: "RDO" },
  { key: "certificate", label: "Certificados" },
  { key: "book", label: "Livro" },
  { key: "photo", label: "Fotos" },
  { key: "label", label: "Etiquetas" },
  { key: "other", label: "Anexos" },
];

const PAGE_SIZE = 12;
const OS_PAGE_SIZE = 6;

export function ArquivosBrowser({
  driveEmail,
  driveRootUrl,
  bundles,
}: {
  driveEmail: string;
  driveRootUrl: string;
  bundles: ArquivoOsBundle[];
}) {
  const withFiles = bundles.filter((b) => b.items.length > 0);
  const initial =
    withFiles.find((b) => b.open)?.osId ||
    withFiles[0]?.osId ||
    bundles[0]?.osId ||
    "";

  const [osId, setOsId] = useState(initial);
  const [kind, setKind] = useState<"all" | DriveFileKind>("all");
  const [showClosed, setShowClosed] = useState(false);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const [osVisibleCount, setOsVisibleCount] = useState(OS_PAGE_SIZE);

  const osList = useMemo(() => {
    const open = bundles.filter((b) => b.open);
    const closed = bundles.filter((b) => !b.open);
    return showClosed ? [...open, ...closed] : open.length ? open : bundles;
  }, [bundles, showClosed]);

  const shownOs = osList.slice(0, osVisibleCount);

  const selected =
    bundles.find((b) => b.osId === osId) ||
    shownOs[0] ||
    bundles[0] ||
    null;

  const kindCounts = useMemo(() => {
    const map: Record<string, number> = { all: selected?.items.length || 0 };
    for (const item of selected?.items || []) {
      map[item.kind] = (map[item.kind] || 0) + 1;
    }
    return map;
  }, [selected]);

  const filtered = useMemo(() => {
    if (!selected) return [];
    return kind === "all"
      ? selected.items
      : selected.items.filter((item) => item.kind === kind);
  }, [selected, kind]);

  const shown = filtered.slice(0, visibleCount);

  function pickOs(id: string) {
    setOsId(id);
    setKind("all");
    setVisibleCount(PAGE_SIZE);
  }

  return (
    <div className="space-y-5">
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Google Drive
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Arquivos por OS
            </h2>
            <p className="mt-2 max-w-xl text-sm leading-6 text-navy/60">
              Conta {driveEmail || "—"}. Escolha a ordem abaixo e veja RDO,
              certificados e fotos com capa.
            </p>
          </div>
          <a
            href={driveRootUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
          >
            Drive raiz ↗
          </a>
        </div>

        <div className="mt-5 border-t border-navy/10 pt-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
              Ordens
            </p>
            <button
              type="button"
              onClick={() => {
                setShowClosed((v) => !v);
                setOsVisibleCount(OS_PAGE_SIZE);
              }}
              className="text-[11px] font-medium text-navy/50 hover:text-navy"
            >
              {showClosed ? "Só abertas" : "Ver encerradas"}
            </button>
          </div>

          {osList.length === 0 ? (
            <p className="py-4 text-sm text-muted">Nenhuma OS.</p>
          ) : (
            <div className="flex flex-wrap gap-2">
              {shownOs.map((bundle) => {
                const active = bundle.osId === selected?.osId;
                return (
                  <button
                    key={bundle.osId}
                    type="button"
                    onClick={() => pickOs(bundle.osId)}
                    title={bundle.clientName || undefined}
                    className={[
                      "rounded-2xl px-3.5 py-2.5 text-left transition",
                      active
                        ? "bg-navy text-paper"
                        : "border border-navy/12 bg-paper text-navy hover:border-brass/40",
                    ].join(" ")}
                  >
                    <span className="flex items-baseline gap-2">
                      <span className="font-serif text-base leading-none">
                        GS {bundle.osNumber}
                      </span>
                      <span
                        className={[
                          "text-[10px] font-semibold",
                          active ? "text-brass" : "text-navy/40",
                        ].join(" ")}
                      >
                        {bundle.items.length}
                      </span>
                    </span>
                    <span
                      className={[
                        "mt-1 block max-w-[11rem] truncate text-[11px]",
                        active ? "text-paper/65" : "text-navy/50",
                      ].join(" ")}
                    >
                      {bundle.clientName || "—"}
                    </span>
                  </button>
                );
              })}
              {shownOs.length < osList.length ? (
                <button
                  type="button"
                  onClick={() =>
                    setOsVisibleCount((n) => n + OS_PAGE_SIZE)
                  }
                  className="rounded-2xl border border-dashed border-navy/20 bg-white px-3.5 py-2.5 text-xs font-semibold text-navy/70 hover:border-brass/40 hover:text-navy"
                >
                  Mais OS
                  <span className="mt-1 block text-[10px] font-medium text-navy/40">
                    +{osList.length - shownOs.length}
                  </span>
                </button>
              ) : null}
            </div>
          )}
        </div>
      </section>

      {selected ? (
        <section className="space-y-4">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
                {selected.statusLabel}
              </p>
              <h2 className="mt-1 font-serif text-2xl text-navy">
                GS {selected.osNumber}
              </h2>
              <p className="mt-1 text-sm text-navy/55">
                {selected.clientName || "—"} · {selected.items.length}{" "}
                arquivo(s)
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Link
                href={`/os/${selected.osId}/documentos`}
                className="rounded-xl bg-navy px-3 py-2 text-sm font-semibold text-paper hover:bg-navy-2"
              >
                Documentos da OS
              </Link>
              {selected.folderUrl ? (
                <a
                  href={selected.folderUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
                >
                  Pasta no Drive ↗
                </a>
              ) : null}
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            {KIND_FILTERS.map((chip) => {
              const count = kindCounts[chip.key] || 0;
              if (chip.key !== "all" && count === 0) return null;
              const active = kind === chip.key;
              return (
                <button
                  key={chip.key}
                  type="button"
                  onClick={() => {
                    setKind(chip.key);
                    setVisibleCount(PAGE_SIZE);
                  }}
                  className={[
                    "rounded-xl px-3 py-2 text-sm font-medium transition",
                    active
                      ? "bg-navy text-paper"
                      : "border border-navy/15 bg-white text-navy hover:border-brass/40",
                  ].join(" ")}
                >
                  {chip.label}
                  <span className={active ? "text-brass" : "text-navy/40"}>
                    {" "}
                    · {count}
                  </span>
                </button>
              );
            })}
          </div>

          {filtered.length === 0 ? (
            <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
              Sem arquivos deste tipo nesta OS.
              {selected.folderUrl ? (
                <>
                  {" "}
                  <a
                    href={selected.folderUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="font-medium text-navy underline"
                  >
                    Abrir pasta no Drive
                  </a>
                </>
              ) : null}
            </p>
          ) : (
            <>
              <p className="text-sm text-navy/55">
                {filtered.length}{" "}
                {kind === "all"
                  ? "arquivo(s)"
                  : driveFileKindLabel(kind).toLowerCase()}
                {shown.length < filtered.length
                  ? ` · mostrando ${shown.length}`
                  : ""}
              </p>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {shown.map((item) => (
                  <DriveFileCard
                    key={`${item.osId}-${item.file.id}`}
                    file={item.file}
                    kind={item.kind}
                    osNumber={item.osNumber}
                    clientName={item.clientName}
                    docsHref={`/os/${item.osId}/documentos`}
                  />
                ))}
              </div>
              {shown.length < filtered.length ? (
                <div className="pt-1">
                  <button
                    type="button"
                    onClick={() => setVisibleCount((n) => n + PAGE_SIZE)}
                    className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-semibold text-navy hover:border-brass/40"
                  >
                    Mostrar mais ({filtered.length - shown.length})
                  </button>
                </div>
              ) : null}
            </>
          )}
        </section>
      ) : (
        <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
          Nenhuma OS com pasta/arquivos para listar.
        </p>
      )}
    </div>
  );
}
