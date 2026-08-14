import type { WorkOrderStatus } from "@gs/shared";
import { getDemo } from "./store";

export function listClients() {
  return getDemo().clients;
}

export function getClient(id: string) {
  return getDemo().clients.find((item) => item.id === id) ?? null;
}

export function listLocations() {
  return getDemo().locations.map((location) => ({
    ...location,
    client: getDemo().clients.find((client) => client.id === location.clientId),
  }));
}

export function locationsForClient(clientId: string) {
  return getDemo().locations.filter((location) => location.clientId === clientId);
}

export function listEmployees() {
  return getDemo().employees;
}

export function listTechnicians() {
  return getDemo().employees.filter((employee) => employee.field);
}

export function technicianName(id: string) {
  return (
    getDemo().employees.find((employee) => employee.technicianId === id)?.name ??
    "Técnico"
  );
}

export function listWorkOrders() {
  return [...getDemo().workOrders].sort((a, b) => b.number - a.number);
}

export function getWorkOrder(id: string) {
  const os = getDemo().workOrders.find((item) => item.id === id);
  if (!os) return null;
  const client = getDemo().clients.find((item) => item.id === os.clientId);
  const location = getDemo().locations.find((item) => item.id === os.locationId);
  return { ...os, client, location };
}

export function dashboardStats() {
  const orders = getDemo().workOrders;
  const today = "2026-08-14";
  const open = orders.filter(
    (os) => !["completed", "reviewed", "billed", "cancelled"].includes(os.status),
  );
  return {
    open: open.length,
    today: orders.filter((os) => os.scheduledDate === today).length,
    clients: getDemo().clients.length,
    dueStandards: getDemo().standards.filter((item) => item.status !== "ok").length,
    byStatus: orders.reduce<Record<string, number>>((acc, os) => {
      acc[os.status] = (acc[os.status] ?? 0) + 1;
      return acc;
    }, {}),
    recent: [...orders].sort((a, b) => b.number - a.number).slice(0, 6),
  };
}

export function updateWorkOrderStatus(id: string, status: WorkOrderStatus) {
  const os = getDemo().workOrders.find((item) => item.id === id);
  if (!os) return;
  os.status = status;
  os.events.unshift({
    type: "Status alterado",
    at: new Date().toISOString(),
    detail: status,
  });
}

export function listCertificates() {
  return getDemo().certificates.map((certificate) => ({
    ...certificate,
    workOrder: getDemo().workOrders.find((os) => os.id === certificate.workOrderId),
    client: getDemo().clients.find((client) => {
      const os = getDemo().workOrders.find((item) => item.id === certificate.workOrderId);
      return os ? client.id === os.clientId : false;
    }),
  }));
}

export function getCertificate(id: string) {
  return listCertificates().find((item) => item.id === id) ?? null;
}

function addOneYear(isoDate: string) {
  const [year, month, day] = isoDate.split("-");
  return `${Number(year) + 1}-${month}-${day}`;
}

export function ingestFieldCertificate(input: {
  number: string;
  workOrderId: string;
  instrument: string;
  tag: string;
  principle: string;
  standard: string;
  signer: string;
  issuedAt: string;
  fileName?: string;
  contentType?: string;
  fileBase64?: string;
}) {
  const demo = getDemo();
  const workOrder =
    demo.workOrders.find((os) => os.id === input.workOrderId) ??
    demo.workOrders.find((os) => `GS ${String(os.number).padStart(3, "0")}/${String(os.year).slice(-2)}` === input.workOrderId);

  if (!workOrder) {
    return { ok: false as const, error: "OS não encontrada no escritório." };
  }

  const existing = demo.certificates.find((item) => item.number === input.number);
  const certificate = {
    id: existing?.id ?? `cert-${input.number}`,
    number: input.number,
    workOrderId: workOrder.id,
    issuedAt: input.issuedAt,
    nextDue: addOneYear(input.issuedAt),
    instrument: input.instrument,
    tag: input.tag,
    principle: input.principle,
    standard: input.standard,
    signer: input.signer,
    source: "field" as const,
    fileName: input.fileName ?? existing?.fileName,
    contentType: input.contentType ?? existing?.contentType,
    fileBase64: input.fileBase64 ?? existing?.fileBase64,
  };

  if (existing) {
    Object.assign(existing, certificate);
  } else {
    demo.certificates.unshift(certificate);
  }

  workOrder.events.unshift({
    type: "Certificado anexado do campo",
    at: new Date().toISOString(),
    detail: `${input.fileName ?? "Planilha"} · certificado ${input.number}`,
  });

  if (!["reviewed", "billed", "cancelled"].includes(workOrder.status)) {
    workOrder.status = "completed";
  }

  return { ok: true as const, certificate };
}

export function listEquipment() {
  return getDemo().equipment.map((item) => ({
    ...item,
    location: getDemo().locations.find((location) => location.id === item.locationId),
  }));
}

export function listStandards() {
  return getDemo().standards;
}

export function agendaDays() {
  const start = new Date("2026-08-10T00:00:00");
  return Array.from({ length: 14 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    const key = date.toISOString().slice(0, 10);
    return {
      date: key,
      label: date.toLocaleDateString("pt-BR", {
        weekday: "short",
        day: "2-digit",
        month: "2-digit",
      }),
      orders: getDemo().workOrders.filter((os) => os.scheduledDate === key),
    };
  });
}
