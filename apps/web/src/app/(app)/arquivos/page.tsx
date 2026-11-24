import Link from "next/link";
import { ArquivosGallery } from "@/components/arquivos/arquivos-gallery";
import type { ArquivoGalleryItem } from "@/components/arquivos/arquivos-gallery";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import {
  CAMPO_DRIVE_ROOT_URL,
  classifyDriveFile,
  getCampoDriveStatus,
  getKnownOsDriveFolders,
  listCampoOrders,
  listCampoOsDriveFiles,
} from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

function normalizeStatus(status: string) {
  return status.trim().toLowerCase().replace(/\s+/g, "");
}

export default async function ArquivosPage() {
  const [drive, orders] = await Promise.all([
    getCampoDriveStatus(),
    listCampoOrders(),
  ]);

  // Prioriza OS abertas / com pasta conhecida — limita chamadas ao gate.
  const ranked = [...orders].sort((a, b) => {
    const aOpen = normalizeStatus(a.status) !== "encerrada" ? 0 : 1;
    const bOpen = normalizeStatus(b.status) !== "encerrada" ? 0 : 1;
    if (aOpen !== bOpen) return aOpen - bOpen;
    const aKnown = getKnownOsDriveFolders(a.number) ? 0 : 1;
    const bKnown = getKnownOsDriveFolders(b.number) ? 0 : 1;
    if (aKnown !== bKnown) return aKnown - bKnown;
    return b.number.localeCompare(a.number, "pt-BR");
  });
  const sample = ranked.slice(0, 8);

  const listings = await Promise.all(
    sample.map(async (os) => ({
      os,
      listing: await listCampoOsDriveFiles(os.number),
    })),
  );

  const galleryItems: ArquivoGalleryItem[] = [];
  for (const { os, listing } of listings) {
    for (const file of listing.files) {
      const kind = classifyDriveFile(file);
      if (kind === "other" && file.name.toLowerCase().endsWith(".json")) {
        continue;
      }
      galleryItems.push({
        file,
        kind,
        osId: os.id,
        osNumber: os.number,
        clientName: os.clientName,
      });
    }
  }

  galleryItems.sort((a, b) => {
    const ta = a.file.updatedAt || a.file.name;
    const tb = b.file.updatedAt || b.file.name;
    return tb.localeCompare(ta, "pt-BR");
  });

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Arquivos / Drive"
        description="Capas dos PDFs e fotos gerados no GS Campo — clique para abrir no Drive."
      />

      <Panel>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="font-serif text-lg text-navy">Google Drive</h2>
            <p className="mt-1 text-sm text-navy/70">
              Conta: {drive.ownerEmail || "—"}. Pastas por OS:{" "}
              <code className="text-xs">RDO / Fotos / Anexos / Certificados</code>.
            </p>
          </div>
          <a
            href={drive.folderUrl || CAMPO_DRIVE_ROOT_URL}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-navy px-3 py-2 text-sm font-semibold text-paper hover:bg-navy-2"
          >
            Pasta raiz ↗
          </a>
        </div>
        {drive.error && !drive.folderUrl ? (
          <p className="mt-2 text-sm text-red-700">{drive.error}</p>
        ) : null}
      </Panel>

      <section className="mt-8">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Galeria
            </p>
            <h2 className="mt-1 font-serif text-2xl text-navy">
              Arquivos recentes
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              Amostra das {sample.length} OS mais relevantes ·{" "}
              {galleryItems.length} arquivo(s) com capa.
            </p>
          </div>
        </div>
        <ArquivosGallery items={galleryItems} />
      </section>

      <section className="mt-10">
        <div className="mb-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Pastas
          </p>
          <h2 className="mt-1 font-serif text-2xl text-navy">
            Por ordem de serviço
          </h2>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {orders.map((os) => {
            const known = getKnownOsDriveFolders(os.number);
            const folderUrl = known?.url || drive.folderUrl || "";
            const listing = listings.find((row) => row.os.id === os.id)?.listing;
            const fileCount = listing?.files.length ?? 0;
            return (
              <article
                key={os.id}
                className="flex flex-col rounded-2xl border border-navy/10 bg-white p-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <Link
                      href={`/os/${os.id}/documentos`}
                      className="font-serif text-xl text-navy hover:underline"
                    >
                      GS {os.number}
                    </Link>
                    <p className="mt-1 line-clamp-1 text-sm text-navy/55">
                      {os.clientName || "—"}
                    </p>
                  </div>
                  <StatusPill
                    label={campoOsStatusLabel(os.status)}
                    tone={campoOsStatusTone(os.status)}
                  />
                </div>
                <p className="mt-3 text-xs text-navy/45">
                  {fileCount > 0
                    ? `${fileCount} arquivo(s) listados`
                    : `${os.rdoCount} RDO no cadastro`}
                </p>
                <div className="mt-4 flex flex-wrap gap-2">
                  <Link
                    href={`/os/${os.id}/documentos`}
                    className="rounded-lg bg-navy px-2.5 py-1.5 text-[11px] font-semibold text-paper hover:bg-navy-2"
                  >
                    Documentos
                  </Link>
                  {folderUrl ? (
                    <a
                      href={folderUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="rounded-lg border border-navy/15 bg-paper px-2.5 py-1.5 text-[11px] font-semibold text-navy hover:border-brass/40"
                    >
                      Pasta ↗
                    </a>
                  ) : null}
                </div>
              </article>
            );
          })}
        </div>
      </section>
    </div>
  );
}
