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
    if (path.includes("/backup") || name.endsWith(".json")) {
      other.push(file);
      continue;
    }
    if (path.includes("/rdo") || path.startsWith("rdo/") || name.startsWith("rdo_")) {
      rdos.push(file);
    } else if (path.includes("etiqueta") || name.includes("adesivo")) {
      labels.push(file);
    } else if (
      path.includes("/book") ||
      name.includes("livro") ||
      name.startsWith("book_")
    ) {
      books.push(file);
    } else if (
      name.startsWith("certificado_") ||
      path.includes("certificados de calibração") ||
      /gs-(vol|temp|dens|press|cond|tel)/i.test(name)
    ) {
      certificates.push(file);
    } else if (path.includes("/fotos") || file.mimeType.startsWith("image/")) {
      photos.push(file);
    } else {
      other.push(file);
    }
  }

  const byName = (a: CampoOsDriveFile, b: CampoOsDriveFile) =>
    a.name.localeCompare(b.name, "pt-BR");
  rdos.sort(byName);
  certificates.sort(byName);
  books.sort(byName);

  return { rdos, certificates, books, labels, photos, other };
}

export type DriveFileKind =
  | "rdo"
  | "certificate"
  | "book"
  | "label"
  | "photo"
  | "other";

export function classifyDriveFile(file: CampoOsDriveFile): DriveFileKind {
  const path = `${file.folder}/${file.name}`.toLowerCase();
  const name = file.name.toLowerCase();
  if (path.includes("/backup") || name.endsWith(".json")) return "other";
  if (path.includes("/rdo") || path.startsWith("rdo/") || name.startsWith("rdo_")) {
    return "rdo";
  }
  if (path.includes("etiqueta") || name.includes("adesivo")) return "label";
  if (path.includes("/book") || name.includes("livro") || name.startsWith("book_")) {
    return "book";
  }
  if (
    name.startsWith("certificado_") ||
    path.includes("certificados de calibração") ||
    /gs-(vol|temp|dens|press|cond|tel)/i.test(name)
  ) {
    return "certificate";
  }
  if (path.includes("/fotos") || file.mimeType.startsWith("image/")) {
    return "photo";
  }
  return "other";
}

export function driveFileKindLabel(kind: DriveFileKind) {
  const map: Record<DriveFileKind, string> = {
    rdo: "RDO",
    certificate: "Certificado",
    book: "Livro",
    label: "Etiqueta",
    photo: "Foto",
    other: "Anexo",
  };
  return map[kind];
}

/** Capa / preview do Drive (PDF e imagens). */
export function driveFileCoverUrl(file: CampoOsDriveFile) {
  const id = text(file.id);
  if (!id) return "";
  if (file.mimeType.startsWith("image/")) {
    return (
      text(file.url) ||
      `https://drive.google.com/thumbnail?id=${encodeURIComponent(id)}&sz=w640`
    );
  }
  return `https://drive.google.com/thumbnail?id=${encodeURIComponent(id)}&sz=w640`;
}

export function findDriveCertForNumber(
  files: CampoOsDriveFile[],
  certificateNumber: string,
) {
  const needle = text(certificateNumber).toLowerCase();
  if (!needle) return null;
  const { certificates } = driveFilesByKind(files);
  return (
    certificates.find((f) => f.name.toLowerCase().includes(needle)) ||
    certificates.find((f) => f.path.toLowerCase().includes(needle)) ||
    null
  );
}

/** RDO_OS_046-26_221126.pdf → casa com data 22/11/2026. */
export function findDriveRdoForDate(
  files: CampoOsDriveFile[],
  dateRaw: string,
) {
  const { rdos } = driveFilesByKind(files);
  if (!rdos.length || !text(dateRaw)) return null;
  const d = new Date(dateRaw);
  if (Number.isNaN(d.getTime())) return null;
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const yy = String(d.getUTCFullYear()).slice(-2);
  // App usa fuso local; tenta UTC e America/Sao_Paulo.
  const local = new Date(
    d.toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }),
  );
  const ldd = String(local.getDate()).padStart(2, "0");
  const lmm = String(local.getMonth() + 1).padStart(2, "0");
  const lyy = String(local.getFullYear()).slice(-2);
  const needles = [`_${dd}${mm}${yy}`, `_${ldd}${lmm}${lyy}`];
  return (
    rdos.find((f) =>
      needles.some((n) => f.name.toLowerCase().includes(n.toLowerCase())),
    ) || null
  );
}

