import Link from "next/link";
import { DataTable, PageHeader, Panel } from "@/components/ui";
import {
  CAMPO_DRIVE_ROOT_URL,
  getCampoDriveStatus,
  getKnownOsDriveFolders,
  listCampoOrders,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function ArquivosPage() {
  const [drive, orders] = await Promise.all([
    getCampoDriveStatus(),
    listCampoOrders(),
  ]);

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Arquivos / Drive"
        description="RDO, fotos, anexos e certificados — mesmos arquivos gerados no GS Campo."
      />

      <Panel>
        <h2 className="mb-2 font-serif text-lg text-navy">Google Drive</h2>
        <p className="text-sm text-navy/70">
          Conta: {drive.ownerEmail || "—"}. Cada OS grava em subpastas{" "}
          <code className="text-xs">RDO / Fotos / Anexos / Certificados</code>.
        </p>
        <p className="mt-3">
          <a
            href={drive.folderUrl || CAMPO_DRIVE_ROOT_URL}
            target="_blank"
            rel="noreferrer"
            className="text-sm font-medium text-navy hover:underline"
          >
            Abrir pasta raiz das OS →
          </a>
        </p>
        {drive.error && !drive.folderUrl ? (
          <p className="mt-2 text-sm text-red-700">{drive.error}</p>
        ) : null}
      </Panel>

      <div className="mt-6">
        <h2 className="mb-3 font-serif text-lg text-navy">Por ordem de serviço</h2>
        <DataTable
          headers={["OS", "Cliente", "Status", "RDOs", "Abrir"]}
          empty="Nenhuma OS."
          rows={orders.map((os) => {
            const known = getKnownOsDriveFolders(os.number);
            const folderUrl = known?.url || "";
            return [
              <Link
                key={os.id}
                href={`/os/${os.id}/documentos`}
                className="font-medium text-navy hover:underline"
              >
                GS {os.number}
              </Link>,
              os.clientName || "—",
              os.status || "—",
              String(os.rdoCount),
              <span key={`${os.id}-links`} className="flex flex-wrap gap-2 text-sm">
                <Link
                  href={`/os/${os.id}/documentos`}
                  className="text-navy/70 hover:underline"
                >
                  Documentos
                </Link>
                {folderUrl ? (
                  <a
                    href={folderUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-navy/70 hover:underline"
                  >
                    Pasta OS →
                  </a>
                ) : drive.folderUrl ? (
                  <a
                    href={drive.folderUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-navy/70 hover:underline"
                  >
                    Raiz Drive →
                  </a>
                ) : (
                  "—"
                )}
              </span>,
            ];
          })}
        />
      </div>
    </div>
  );
}
