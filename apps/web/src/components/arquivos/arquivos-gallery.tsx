"use client";

import { useMemo, useState } from "react";
import {
  driveFileKindLabel,
  type CampoOsDriveFile,
  type DriveFileKind,
} from "@/lib/campo-data";
import { DriveFileCard } from "./drive-file-card";

export type ArquivoGalleryItem = {
  file: CampoOsDriveFile;
  kind: DriveFileKind;
  osId: string;
  osNumber: string;
  clientName: string;
};

const FILTERS: Array<{ key: "all" | DriveFileKind; label: string }> = [
  { key: "all", label: "Todos" },
  { key: "rdo", label: "RDO" },
  { key: "certificate", label: "Certificados" },
  { key: "book", label: "Livro" },
  { key: "photo", label: "Fotos" },
  { key: "label", label: "Etiquetas" },
  { key: "other", label: "Anexos" },
];

export function ArquivosGallery({ items }: { items: ArquivoGalleryItem[] }) {
  const [filter, setFilter] = useState<"all" | DriveFileKind>("all");

  const counts = useMemo(() => {
    const map: Record<string, number> = { all: items.length };
    for (const item of items) {
      map[item.kind] = (map[item.kind] || 0) + 1;
    }
    return map;
  }, [items]);

  const visible = useMemo(
    () =>
      filter === "all" ? items : items.filter((item) => item.kind === filter),
    [items, filter],
  );

  if (items.length === 0) {
    return (
      <p className="rounded-2xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
        Ainda sem PDFs listados. Abra uma OS no Campo para gerar RDO/certificados
        ou use as pastas abaixo.
      </p>
    );
  }

  return (
    <div>
      <div className="mb-4 flex flex-wrap gap-2">
        {FILTERS.map((chip) => {
          const count = counts[chip.key] || 0;
          if (chip.key !== "all" && count === 0) return null;
          const active = filter === chip.key;
          return (
            <button
              key={chip.key}
              type="button"
              onClick={() => setFilter(chip.key)}
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

      <p className="mb-4 text-sm text-navy/55">
        {visible.length} arquivo(s)
        {filter !== "all" ? ` · ${driveFileKindLabel(filter)}` : ""} com capa do
        Drive.
      </p>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
        {visible.map((item) => (
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
    </div>
  );
}
