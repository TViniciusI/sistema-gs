import Link from "next/link";
import { formatWorkOrderNumber } from "@gs/shared";
import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listCertificates } from "@/lib/demo/queries";

export default function CertificadosPage() {
  const certificates = listCertificates();

  return (
    <div>
      <PageHeader
        title="Certificados de calibração"
        description="A planilha continua no Excel. O técnico anexa o arquivo no app e, ao sincronizar, o documento cai nesta lista."
      />
      <DataTable
        headers={["Número", "OS", "Instrumento", "Emissão", "Próxima", "Origem"]}
        empty="Nenhum certificado."
        rows={certificates.map((certificate) => [
          <Link
            key={certificate.id}
            href={`/certificados/${certificate.id}`}
            className="font-medium text-navy hover:underline"
          >
            {certificate.number}
          </Link>,
          certificate.workOrder
            ? formatWorkOrderNumber(
                certificate.workOrder.number,
                certificate.workOrder.year,
              )
            : "—",
          certificate.instrument,
          new Date(`${certificate.issuedAt}T00:00:00`).toLocaleDateString("pt-BR"),
          new Date(`${certificate.nextDue}T00:00:00`).toLocaleDateString("pt-BR"),
          <StatusPill
            key={`${certificate.id}-src`}
            label={certificate.source === "field" ? "Anexo do campo" : "Escritório"}
            tone={certificate.source === "field" ? "warn" : "neutral"}
          />,
        ])}
      />
    </div>
  );
}
