import Link from "next/link";
import { PageHeader } from "@/components/ui";
import { listCampoOrders } from "@/lib/campo-data";
import { OsBoard } from "./os-board";

export const dynamic = "force-dynamic";

export default async function OsListPage() {
  const orders = await listCampoOrders();

  return (
    <div>
      <PageHeader
        eyebrow="Operação"
        title="Ordens de serviço"
        description="Mesmas OS do GS Campo — status, técnicos e RDOs da planilha."
        action={
          <Link
            href="/os/nova"
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Nova OS
          </Link>
        }
      />
      <OsBoard
        orders={orders.map((os) => ({
          id: os.id,
          number: os.number,
          status: os.status,
          clientName: os.clientName,
          technicianName: os.technicianName,
          startsAt: os.startsAt,
          rdoCount: os.rdoCount,
          fileCount: os.fileCount,
          payloadLight: os.payloadLight,
        }))}
      />
    </div>
  );
}
