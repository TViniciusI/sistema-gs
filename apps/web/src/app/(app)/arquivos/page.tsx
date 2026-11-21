import Link from "next/link";
import { DataTable, PageHeader, Panel } from "@/components/ui";
import { getCampoDriveStatus, listCampoOrders } from "@/lib/campo-data";

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
        description="RDO, fotos, anexos e certificados na mesma pasta Drive do GS Campo."
      />

      <Panel>
        <h2 className="mb-2 font-serif text-lg text-navy">Google Drive</h2>
        <p className="text-sm text-navy/70">
          Conta: {drive.ownerEmail || "—"}. Cada OS grava em subpastas{" "}
          <code className="text-xs">RDO / Fotos / Anexos / Certificados</code>.
        </p>
        {drive.folderUrl ? (
          <p className="mt-3">
            <a
              href={drive.folderUrl}
              target="_blank"
              rel="noreferrer"
              className="text-sm font-medium text-navy hover:underline"
            >
              Abrir pasta raiz das OS →
            </a>
          </p>
        ) : (
          <p className="mt-3 text-sm text-red-700">
            {drive.error || "Drive indisponível."}
          </p>
        )}
      </Panel>

      <div className="mt-6">
        <h2 className="mb-3 font-serif text-lg text-navy">Por ordem de serviço</h2>
        <DataTable
          headers={["OS", "Cliente", "RDOs", "Arquivos", "Abrir"]}
          empty="Nenhuma OS."
          rows={orders.map((os) => [
            <Link
              key={os.id}
              href={`/os/${os.id}`}
              className="font-medium text-navy hover:underline"
            >
              GS {os.number}
            </Link>,
            os.clientName || "—",
            String(os.rdoCount),
            String(os.fileCount),
            drive.folderUrl ? (
              <a
                key={`${os.id}-drive`}
                href={drive.folderUrl}
                target="_blank"
                rel="noreferrer"
                className="text-sm text-navy/70 hover:underline"
              >
                Pasta Drive
              </a>
            ) : (
              "—"
            ),
          ])}
        />
      </div>
    </div>
  );
}
