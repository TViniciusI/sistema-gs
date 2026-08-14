import Link from "next/link";
import {
  WORK_ORDER_STATUS_LABELS,
  formatWorkOrderNumber,
  type WorkOrderStatus,
} from "@gs/shared";
import { Button, DataTable, PageHeader, StatusPill } from "@/components/ui";
import { getClient, listLocations, listWorkOrders } from "@/lib/demo/queries";

function tone(status: string) {
  if (status === "cancelled") return "danger" as const;
  if (["completed", "reviewed", "billed"].includes(status)) return "ok" as const;
  if (["in_progress", "traveling", "on_site"].includes(status)) return "warn" as const;
  return "neutral" as const;
}

export default function OsListPage() {
  const orders = listWorkOrders();
  const locations = listLocations();

  return (
    <div>
      <PageHeader
        title="Ordens de serviço"
        description="Numeração GS 036/26, equipe em campo e status em tempo real."
        action={<Button href="/os/nova">Nova OS</Button>}
      />
      <DataTable
        headers={["OS", "Cliente", "Local", "Data", "Status"]}
        empty="Nenhuma OS."
        rows={orders.map((os) => {
          const client = getClient(os.clientId);
          const location = locations.find((item) => item.id === os.locationId);
          return [
            <Link
              key={os.id}
              href={`/os/${os.id}`}
              className="font-medium text-navy hover:underline"
            >
              {formatWorkOrderNumber(os.number, os.year)}
            </Link>,
            client?.legalName ?? "—",
            location?.alias ?? "—",
            new Date(`${os.scheduledDate}T00:00:00`).toLocaleDateString("pt-BR"),
            <StatusPill
              key={`${os.id}-st`}
              label={WORK_ORDER_STATUS_LABELS[os.status as WorkOrderStatus]}
              tone={tone(os.status)}
            />,
          ];
        })}
      />
    </div>
  );
}
