import {
  CAMPO_DRIVE_ROOT_URL,
  driveFilesByKind,
  type CampoOsDriveListing,
} from "@/lib/campo-data";

function FileLink({
  href,
  label,
  hint,
}: {
  href: string;
  label: string;
  hint?: string;
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="flex items-center justify-between gap-3 rounded-xl border border-navy/10 bg-paper/70 px-3 py-2.5 text-sm text-navy transition hover:border-brass/40"
    >
      <span className="min-w-0 truncate font-medium">{label}</span>
      <span className="shrink-0 text-[11px] uppercase tracking-wide text-navy/45">
        {hint || "Abrir ↗"}
      </span>
    </a>
  );
}

export function OsDrivePanel({
  listing,
  focus = "all",
}: {
  listing: CampoOsDriveListing;
  focus?: "all" | "rdo" | "certificates" | "book";
}) {
  const groups = driveFilesByKind(listing.files);
  const showRdo = focus === "all" || focus === "rdo";
  const showCerts = focus === "all" || focus === "certificates";
  const showBook = focus === "all" || focus === "book";
  const showExtras = focus === "all";
  const totalShown =
    (showRdo ? groups.rdos.length : 0) +
    (showCerts ? groups.certificates.length : 0) +
    (showBook ? groups.books.length : 0) +
    (showExtras
      ? groups.labels.length + groups.photos.length + groups.other.length
      : 0);

  return (
    <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Google Drive
          </p>
          <h2 className="mt-1 font-serif text-xl text-navy">
            Arquivos oficiais da OS
          </h2>
          <p className="mt-2 text-sm leading-6 text-navy/60">
            Mesmos PDFs gerados no GS Campo
            {listing.source === "gate" && listing.files.length > 0
              ? ` · ${listing.files.length} arquivo(s) listados`
              : ""}
            .
          </p>
        </div>
        {listing.source === "gate" ? (
          <span className="rounded-full bg-ok/15 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-ok">
            Sincronizado
          </span>
        ) : null}
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        {listing.folderUrl ? (
          <a
            href={listing.folderUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-navy px-3 py-2 text-sm font-semibold text-paper hover:bg-navy-2"
          >
            Pasta da OS ↗
          </a>
        ) : (
          <a
            href={CAMPO_DRIVE_ROOT_URL}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-navy px-3 py-2 text-sm font-semibold text-paper hover:bg-navy-2"
          >
            Drive GS Campo ↗
          </a>
        )}
        {showRdo && listing.rdoFolderUrl ? (
          <a
            href={listing.rdoFolderUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm font-medium text-navy hover:border-brass/40"
          >
            Pasta RDO ↗
          </a>
        ) : null}
        {(showCerts || showBook) && listing.certificadosFolderUrl ? (
          <a
            href={listing.certificadosFolderUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm font-medium text-navy hover:border-brass/40"
          >
            Pasta certificados ↗
          </a>
        ) : null}
      </div>

      {totalShown === 0 ? (
        <p className="mt-4 rounded-2xl border border-dashed border-navy/15 px-4 py-6 text-sm text-muted">
          {listing.folderUrl
            ? "Ainda sem PDF nesta pasta (ou ainda não gerado no Campo). Abra a pasta da OS no Drive."
            : listing.error || "Nenhum arquivo nesta OS no Drive."}
        </p>
      ) : (
        <div className="mt-4 space-y-4">
          {showRdo && groups.rdos.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                RDO ({groups.rdos.length})
              </p>
              <div className="space-y-2">
                {groups.rdos.map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.name}
                    hint="PDF oficial"
                  />
                ))}
              </div>
            </div>
          ) : null}
          {showBook && groups.books.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Book ({groups.books.length})
              </p>
              <div className="space-y-2">
                {groups.books.map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.name}
                    hint="PDF oficial"
                  />
                ))}
              </div>
            </div>
          ) : null}
          {showCerts && groups.certificates.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Certificados ({groups.certificates.length})
              </p>
              <div className="space-y-2">
                {groups.certificates.slice(0, 80).map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.path !== file.name ? file.path : file.name}
                    hint="PDF oficial"
                  />
                ))}
                {groups.certificates.length > 80 ? (
                  <p className="text-xs text-navy/45">
                    +{groups.certificates.length - 80} no Drive
                  </p>
                ) : null}
              </div>
            </div>
          ) : null}
          {showExtras && groups.labels.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Etiquetas ({groups.labels.length})
              </p>
              <div className="space-y-2">
                {groups.labels.map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.name}
                    hint="Abrir ↗"
                  />
                ))}
              </div>
            </div>
          ) : null}
          {showExtras && groups.photos.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Fotos ({groups.photos.length})
              </p>
              <div className="space-y-2">
                {groups.photos.slice(0, 40).map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.name}
                    hint="Abrir ↗"
                  />
                ))}
              </div>
            </div>
          ) : null}
          {showExtras && groups.other.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Anexos / outros ({groups.other.length})
              </p>
              <div className="space-y-2">
                {groups.other.slice(0, 40).map((file) => (
                  <FileLink
                    key={file.id}
                    href={file.url}
                    label={file.path !== file.name ? file.path : file.name}
                    hint="Abrir ↗"
                  />
                ))}
              </div>
            </div>
          ) : null}
        </div>
      )}
    </section>
  );
}
