import { getKnownOsDriveFolders, osFolderKey } from "./drive-os-folders";
import { gateGet } from "./gate";

export type CampoOsDriveFile = {
  id: string;
  name: string;
  path: string;
  folder: string;
  mimeType: string;
  url: string;
  downloadUrl: string;
  updatedAt: string;
};

export type CampoOsDriveListing = {
  ok: boolean;
  osNumber: string;
  folderKey: string;
  folderUrl: string;
  rdoFolderUrl?: string;
  certificadosFolderUrl?: string;
  files: CampoOsDriveFile[];
  error?: string;
  source: "gate" | "known-folders";
};

function text(value: unknown) {
  return String(value ?? "").trim();
}

function knownFoldersFallback(number: string): CampoOsDriveListing {
  const known = getKnownOsDriveFolders(number);
  if (!known) {
    return {
      ok: false,
      osNumber: number,
      folderKey: osFolderKey(number),
      folderUrl: "",
      files: [],
      error:
        "Pasta da OS ainda não indexada. Abra o Drive raiz ou gere/salve no GS Campo.",
      source: "known-folders",
    };
  }
  return {
    ok: true,
    osNumber: number,
    folderKey: osFolderKey(number),
    folderUrl: known.url,
    rdoFolderUrl: known.rdoUrl,
    certificadosFolderUrl: known.certificadosUrl,
    files: [],
    source: "known-folders",
  };
}

export async function listCampoOsDriveFiles(
  osNumber: string,
): Promise<CampoOsDriveListing> {
  const number = text(osNumber);
  if (!number) {
    return {
      ok: false,
      osNumber: "",
      folderKey: "",
      folderUrl: "",
      files: [],
      error: "OS sem número",
      source: "known-folders",
    };
  }

  const payload = await gateGet(
    { action: "listosdrive", osNumber: number },
    { withToken: true, timeoutMs: 60_000 },
  );

  const known = getKnownOsDriveFolders(number);

  if (!payload || payload.ok !== true) {
    const fallback = knownFoldersFallback(number);
    if (!payload) {
      return {
        ...fallback,
        error: fallback.error || "Sem resposta do gate (rede/Apps Script).",
      };
    }
    const err = text(payload.error);
    // Gate antigo ainda não tem listosdrive — usa pastas conhecidas.
    if (/a[cç][aã]o inv[aá]lida/i.test(err) || /invalid/i.test(err)) {
      return fallback;
    }
    return {
      ...fallback,
      error: err || fallback.error || "Falha ao listar Drive da OS.",
    };
  }

  const raw = Array.isArray(payload.files) ? payload.files : [];
  const files = raw
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const f = item as Record<string, unknown>;
      const id = text(f.id);
      if (!id) return null;
      return {
        id,
        name: text(f.name) || id,
        path: text(f.path) || text(f.name),
        folder: text(f.folder),
        mimeType: text(f.mimeType),
        url: text(f.url) || `https://drive.google.com/file/d/${id}/view`,
        downloadUrl:
          text(f.downloadUrl) ||
          `https://drive.google.com/uc?export=download&id=${id}`,
        updatedAt: text(f.updatedAt),
      } satisfies CampoOsDriveFile;
    })
    .filter(Boolean) as CampoOsDriveFile[];

  return {
    ok: true,
    osNumber: text(payload.osNumber) || number,
    folderKey: text(payload.folderKey) || osFolderKey(number),
    folderUrl: text(payload.folderUrl) || known?.url || "",
    rdoFolderUrl: known?.rdoUrl,
    certificadosFolderUrl: known?.certificadosUrl,
    files,
    source: "gate",
  };
}

export function driveFilesByKind(files: CampoOsDriveFile[]) {
  const rdos: CampoOsDriveFile[] = [];
  const certificates: CampoOsDriveFile[] = [];
  const books: CampoOsDriveFile[] = [];
  const labels: CampoOsDriveFile[] = [];
  const photos: CampoOsDriveFile[] = [];
  const other: CampoOsDriveFile[] = [];

  for (const file of files) {
    const path = `${file.folder}/${file.name}`.toLowerCase();
    const name = file.name.toLowerCase();
    if (path.includes("/rdo") || path.startsWith("rdo") || name.startsWith("rdo_")) {
      rdos.push(file);
    } else if (path.includes("etiqueta") || name.includes("adesivo")) {
      labels.push(file);
    } else if (path.includes("/book") || name.includes("livro") || name.includes("book")) {
      books.push(file);
    } else if (
      path.includes("certificado") ||
      name.startsWith("gs-vol") ||
      name.startsWith("gs-temp") ||
      name.startsWith("gs-dens") ||
      name.startsWith("gs-press") ||
      name.startsWith("gs-cond") ||
      name.startsWith("gs-tel")
    ) {
      certificates.push(file);
    } else if (path.includes("foto") || file.mimeType.startsWith("image/")) {
      photos.push(file);
    } else {
      other.push(file);
    }
  }

  return { rdos, certificates, books, labels, photos, other };
}

export function findDriveCertForNumber(
  files: CampoOsDriveFile[],
  certificateNumber: string,
) {
  const needle = text(certificateNumber).toLowerCase();
  if (!needle) return null;
  const { certificates, books, other } = driveFilesByKind(files);
  const pool = [...certificates, ...books, ...other];
  return (
    pool.find((f) => f.name.toLowerCase().includes(needle)) ||
    pool.find((f) => f.path.toLowerCase().includes(needle)) ||
    null
  );
}
