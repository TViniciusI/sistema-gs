import { ArquivosBrowser } from "@/components/arquivos/arquivos-browser";
import type { ArquivoOsBundle } from "@/components/arquivos/arquivos-browser";
import type { ArquivoGalleryItem } from "@/components/arquivos/arquivos-gallery";
import { PageHeader } from "@/components/ui";
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

function isOpenStatus(status: string) {
  return normalizeStatus(status) !== "encerrada";
}

export default async function ArquivosPage() {
  const [drive, orders] = await Promise.all([
    getCampoDriveStatus(),
    listCampoOrders(),
  ]);

  // Abertas primeiro; limita listosdrive para não estourar o gate.
  const ranked = [...orders].sort((a, b) => {
    const aOpen = isOpenStatus(a.status) ? 0 : 1;
    const bOpen = isOpenStatus(b.status) ? 0 : 1;
    if (aOpen !== bOpen) return aOpen - bOpen;
    const aKnown = getKnownOsDriveFolders(a.number) ? 0 : 1;
    const bKnown = getKnownOsDriveFolders(b.number) ? 0 : 1;
    if (aKnown !== bKnown) return aKnown - bKnown;
    return b.number.localeCompare(a.number, "pt-BR");
  });

  const open = ranked.filter((os) => isOpenStatus(os.status));
  const closed = ranked.filter((os) => !isOpenStatus(os.status));
  // Até 10 abertas + 4 encerradas recentes com pasta conhecida.
  const sample = [
    ...open.slice(0, 10),
    ...closed
      .filter((os) => getKnownOsDriveFolders(os.number))
      .slice(0, 4),
  ];
  // Garante ids únicos se overlap.
  const seen = new Set<string>();
  const toFetch = sample.filter((os) => {
    if (seen.has(os.id)) return false;
    seen.add(os.id);
    return true;
  });

  const listings = await Promise.all(
    toFetch.map(async (os) => ({
      os,
      listing: await listCampoOsDriveFiles(os.number),
    })),
  );

  const bundles: ArquivoOsBundle[] = listings.map(({ os, listing }) => {
    const known = getKnownOsDriveFolders(os.number);
    const items: ArquivoGalleryItem[] = [];
    for (const file of listing.files) {
      const kind = classifyDriveFile(file);
      if (kind === "other" && file.name.toLowerCase().endsWith(".json")) {
        continue;
      }
      items.push({
        file,
        kind,
        osId: os.id,
        osNumber: os.number,
        clientName: os.clientName,
      });
    }
    items.sort((a, b) => {
      const kindRank = (k: string) =>
        ({ rdo: 0, certificate: 1, book: 2, photo: 3, label: 4, other: 5 }[k] ??
        9);
      const kr = kindRank(a.kind) - kindRank(b.kind);
      if (kr !== 0) return kr;
      return a.file.name.localeCompare(b.file.name, "pt-BR");
    });

    return {
      osId: os.id,
      osNumber: os.number,
      clientName: os.clientName,
      statusLabel: campoOsStatusLabel(os.status),
      statusTone: campoOsStatusTone(os.status),
      folderUrl: listing.folderUrl || known?.url || "",
      open: isOpenStatus(os.status),
      items,
    };
  });

  // Inclui OS abertas sem listing (só atalho documentos) no fim da lista.
  const fetchedIds = new Set(bundles.map((b) => b.osId));
  for (const os of open) {
    if (fetchedIds.has(os.id)) continue;
    const known = getKnownOsDriveFolders(os.number);
    bundles.push({
      osId: os.id,
      osNumber: os.number,
      clientName: os.clientName,
      statusLabel: campoOsStatusLabel(os.status),
      statusTone: campoOsStatusTone(os.status),
      folderUrl: known?.url || "",
      open: true,
      items: [],
    });
  }

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Arquivos / Drive"
        description="Escolha a OS no topo e veja RDO, certificados e fotos com capa — sem sidebar nem pastas soltas."
      />
      <ArquivosBrowser
        driveEmail={drive.ownerEmail || ""}
        driveRootUrl={drive.folderUrl || CAMPO_DRIVE_ROOT_URL}
        bundles={bundles}
      />
    </div>
  );
}
