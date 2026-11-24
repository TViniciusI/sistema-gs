import { getKnownOsDriveFolders, osFolderKey } from "./drive-os-folders";
import { gateGet } from "./gate";
import {
  type CampoOsDriveFile,
  type CampoOsDriveListing,
} from "./os-drive-ui";

export type {
  CampoOsDriveFile,
  CampoOsDriveListing,
  DriveFileKind,
} from "./os-drive-ui";
export {
  classifyDriveFile,
  driveFileCoverUrl,
  driveFileKindLabel,
  driveFilesByKind,
  findDriveCertForNumber,
  findDriveRdoForDate,
} from "./os-drive-ui";

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
