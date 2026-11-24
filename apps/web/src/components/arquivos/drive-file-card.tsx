"use client";

import { useState } from "react";
import {
  driveFileCoverUrl,
  driveFileKindLabel,
  type CampoOsDriveFile,
  type DriveFileKind,
} from "@/lib/campo-data";

const KIND_TONE: Record<DriveFileKind, string> = {
  rdo: "from-[#1a3a5c] to-[#0c1f33]",
  certificate: "from-[#3d4a2a] to-[#1f2814]",
  book: "from-[#4a3a1a] to-[#2a1f0c]",
  label: "from-[#4a2a3a] to-[#2a1420]",
  photo: "from-[#2a3a4a] to-[#142028]",
  other: "from-[#2a2a2a] to-[#141414]",
};

export function DriveFileCard({
  file,
  kind,
  osNumber,
  clientName,
  docsHref,
}: {
  file: CampoOsDriveFile;
  kind: DriveFileKind;
  osNumber: string;
  clientName: string;
  docsHref: string;
}) {
  const [broken, setBroken] = useState(false);
  const cover = driveFileCoverUrl(file);
  const label = driveFileKindLabel(kind);
  const shortName = file.name.replace(/\.[^.]+$/, "");

  return (
    <article className="group flex flex-col overflow-hidden rounded-2xl border border-navy/10 bg-white shadow-[0_10px_28px_rgba(12,31,51,0.06)] transition hover:-translate-y-0.5 hover:border-brass/35 hover:shadow-[0_16px_36px_rgba(12,31,51,0.1)]">
      <a
        href={file.url}
        target="_blank"
        rel="noreferrer"
        className="relative block aspect-[4/3] overflow-hidden bg-navy"
      >
        {!broken && cover ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={cover}
            alt=""
            className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]"
            loading="lazy"
            referrerPolicy="no-referrer"
            onError={() => setBroken(true)}
          />
        ) : (
          <div
            className={`flex h-full w-full flex-col justify-between bg-gradient-to-br p-4 text-paper ${KIND_TONE[kind]}`}
          >
            <span className="text-[10px] font-semibold uppercase tracking-[0.22em] text-brass">
              {label}
            </span>
            <p className="line-clamp-3 font-serif text-lg leading-snug">
              {shortName}
            </p>
          </div>
        )}
        <span className="absolute left-3 top-3 rounded-full bg-navy/85 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide text-brass backdrop-blur-sm">
          {label}
        </span>
      </a>

      <div className="flex flex-1 flex-col gap-2 px-4 py-3.5">
        <a
          href={file.url}
          target="_blank"
          rel="noreferrer"
          className="line-clamp-2 text-sm font-semibold leading-5 text-navy hover:text-navy-2"
          title={file.name}
        >
          {file.name}
        </a>
        <p className="text-xs text-navy/50">
          GS {osNumber}
          {clientName ? ` · ${clientName}` : ""}
        </p>
        <div className="mt-auto flex flex-wrap gap-2 pt-1">
          <a
            href={file.url}
            target="_blank"
            rel="noreferrer"
            className="rounded-lg bg-navy px-2.5 py-1.5 text-[11px] font-semibold text-paper hover:bg-navy-2"
          >
            Abrir ↗
          </a>
          <a
            href={docsHref}
            className="rounded-lg border border-navy/15 bg-paper px-2.5 py-1.5 text-[11px] font-semibold text-navy hover:border-brass/40"
          >
            Pasta OS
          </a>
        </div>
      </div>
    </article>
  );
}
