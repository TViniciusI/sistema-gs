/** Helpers de UI do Drive — seguros para Client Components (sem gate). */

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

export type DriveFileKind =
  | "rdo"
  | "certificate"
  | "book"
  | "label"
  | "photo"
  | "other";

function text(value: unknown) {
  return String(value ?? "").trim();
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

export function driveFileCoverUrl(file: CampoOsDriveFile) {
  const id = text(file.id);
  if (!id) return "";
  const mime = text(file.mimeType).toLowerCase();
  if (mime.startsWith("image/")) {
    return `https://drive.google.com/thumbnail?id=${encodeURIComponent(id)}&sz=w640`;
  }
  return "";
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
