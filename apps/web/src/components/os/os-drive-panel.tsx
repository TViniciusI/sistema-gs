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

  return (
    <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
        Google Drive
      </p>
      <h2 className="mt-1 font-serif text-xl text-navy">
        Arquivos oficiais da OS
      </h2>
      <p className="mt-2 text-sm leading-6 text-navy/60">
        Os PDFs de certificado, book e RDO gerados no GS Campo são gravados
        nesta pasta — o escritório abre os mesmos arquivos.
      </p>

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
        {showCerts && listing.certificadosFolderUrl ? (
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

      {listing.files.length === 0 ? (
        <p className="mt-4 rounded-2xl border border-dashed border-navy/15 px-4 py-6 text-sm text-muted">
          {listing.source === "known-folders"
            ? "Abra a pasta no Drive para ver os PDFs gerados no app. Após republicar o Apps Script (listosdrive), a lista aparece aqui automaticamente."
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
          {showCerts && groups.certificates.length > 0 ? (
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-navy/45">
                Certificados ({groups.certificates.length})
              </p>
              <div className="space-y-2">
                {groups.certificates.slice(0, 40).map((file) => (
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
        </div>
      )}
    </section>
  );
}
