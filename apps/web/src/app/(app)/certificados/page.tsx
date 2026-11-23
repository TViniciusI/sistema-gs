import Link from "next/link";
import { DataTable, PageHeader } from "@/components/ui";
import { kindLabel, listCampoCalibrations } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function CertificadosPage() {
  const items = await listCampoCalibrations();
  const withNumber = items.filter((item) => item.number.trim().length > 0);

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Certificados"
        description="Calibrações sincronizadas do GS Campo (volumétrica, temperatura, densidade e demais tipos)."
      />
      <DataTable
        headers={["Cert. / nº", "Cliente", "Tipo", "Status", "Atualizado"]}
        empty="Nenhum certificado sincronizado do Campo."
        rows={withNumber.slice(0, 200).map((item) => {
          const osId = String(item.raw.osId || "").trim();
          const href = osId
            ? `/os/${osId}/certificados`
            : `/certificados/${encodeURIComponent(item.id)}`;
          return [
            <Link
              key={item.id}
              href={href}
              className="font-medium text-navy hover:underline"
            >
              {item.number}
            </Link>,
            item.clientName || "—",
            kindLabel(item.kind),
            item.status || "—",
            item.updatedAt
              ? new Date(item.updatedAt).toLocaleDateString("pt-BR")
              : "—",
          ];
        })}
      />
    </div>
  );
}
