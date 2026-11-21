import Link from "next/link";
import { DataTable, PageHeader } from "@/components/ui";
import { listCampoCalibrations } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function CertificadosPage() {
  const items = await listCampoCalibrations();
  const withNumber = items.filter((item) => item.number.trim().length > 0);

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Certificados"
        description="Registros de calibração do Campo — base para emissão e conferência."
      />
      <DataTable
        headers={["Cert. / nº", "Cliente", "Equipamento", "Tipo", "Atualizado"]}
        empty="Nenhum certificado/calibração encontrado."
        rows={withNumber.slice(0, 150).map((item) => [
          <Link
            key={item.id}
            href={`/calibracao`}
            className="font-medium text-navy hover:underline"
          >
            {item.number}
          </Link>,
          item.clientName || "—",
          [item.equipmentTag, item.equipmentType].filter(Boolean).join(" · ") ||
            "—",
          item.kind || "—",
          item.updatedAt
            ? new Date(item.updatedAt).toLocaleDateString("pt-BR")
            : "—",
        ])}
      />
    </div>
  );
}
