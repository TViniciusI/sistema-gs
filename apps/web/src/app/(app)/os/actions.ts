"use server";

import { redirect } from "next/navigation";
import type { ServiceType, SystemType, WorkOrderStatus } from "@gs/shared";
import { getDemo } from "@/lib/demo/store";

export async function createWorkOrder(formData: FormData) {
  const scheduled = String(formData.get("scheduled_date") ?? "2026-08-14");
  const year = new Date(`${scheduled}T00:00:00`).getFullYear();
  const demo = getDemo();
  const last = demo.workOrders.reduce((max, os) => Math.max(max, os.number), 0);
  const id = `os-${last + 1}`;
  const techIds = formData.getAll("technician_id").map(String).filter(Boolean);
  const ownerId = String(formData.get("owner_technician_id") ?? "");

  demo.workOrders.unshift({
    id,
    number: last + 1,
    year,
    purchaseOrder: String(formData.get("purchase_order") ?? "").trim(),
    clientId: String(formData.get("client_id")),
    locationId: String(formData.get("location_id") || demo.locations[0]?.id),
    serviceType: String(formData.get("service_type")) as ServiceType,
    systemType: (String(formData.get("system_type") || "outro") as SystemType),
    status: techIds.length ? "assigned" : "scheduled",
    scheduledDate: scheduled,
    notes: String(formData.get("notes") ?? "").trim(),
    team: techIds.map((technicianId) => ({
      technicianId,
      function:
        technicianId === ownerId ? "responsavel_tecnico" : "suporte_tecnico",
      owner: technicianId === ownerId,
    })),
    events: [
      {
        type: "OS criada (demonstração)",
        at: new Date().toISOString(),
        detail: "Numeração gerada na sessão local",
      },
    ],
    timeEntries: [],
    photos: [],
  });

  redirect(`/os/${id}`);
}

export async function updateWorkOrderStatus(formData: FormData) {
  const id = String(formData.get("work_order_id"));
  const status = String(formData.get("status")) as WorkOrderStatus;
  const os = getDemo().workOrders.find((item) => item.id === id);
  if (os) {
    os.status = status;
    os.events.unshift({
      type: "Status alterado",
      at: new Date().toISOString(),
      detail: status,
    });
  }
  redirect(`/os/${id}`);
}

export async function addTimeEntry() {
  redirect("/");
}
