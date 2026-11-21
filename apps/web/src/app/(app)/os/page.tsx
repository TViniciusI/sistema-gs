import Link from "next/link";
import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listCampoOrders } from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function OsListPage() {
  const orders = await listCampoOrders();

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Ordens de serviço"
        description="Mesmas OS do GS Campo — status, técnicos e RDOs da planilha."
      />
      <DataTable
        headers={["OS", "Cliente", "Técnico", "Início", "RDO", "Status"]}
        empty="Nenhuma OS na planilha."
        rows={orders.map((os) => [
          <Link
            key={os.id}
            href={`/os/${os.id}`}
            className="font-medium text-navy hover:underline"
          >
            GS {os.number}
            {os.payloadLight ? (
              <span className="ml-2 text-[11px] font-normal text-muted">
                (resumo)
              </span>
            ) : null}
          </Link>,
          os.clientName || "—",
          os.technicianName || "—",
          os.startsAt
            ? new Date(os.startsAt).toLocaleDateString("pt-BR")
            : "—",
          String(os.rdoCount),
          <StatusPill
            key={`${os.id}-st`}
            label={campoOsStatusLabel(os.status)}
            tone={campoOsStatusTone(os.status)}
          />,
        ])}
      />
    </div>
  );
}
