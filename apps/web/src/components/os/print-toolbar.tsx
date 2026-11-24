"use client";

import type { ReactNode } from "react";

export function PrintToolbar({
  title,
  extra,
}: {
  title: string;
  extra?: ReactNode;
}) {
  return (
    <div className="no-print mb-6 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-navy/10 bg-white px-4 py-3">
      <div>
        <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
          Impressão
        </p>
        <p className="font-serif text-lg text-navy">{title}</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {extra}
        <button
          type="button"
          onClick={() => window.print()}
          className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
        >
          Imprimir / salvar PDF
        </button>
      </div>
    </div>
  );
}
