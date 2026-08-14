export const ROLES = [
  "admin",
  "office",
  "lead_tech",
  "technician",
  "viewer",
] as const;

export type Role = (typeof ROLES)[number];

export const ROLE_LABELS: Record<Role, string> = {
  admin: "Administrador",
  office: "Escritório",
  lead_tech: "Responsável técnico",
  technician: "Técnico",
  viewer: "Visualização",
};

export const WORK_ORDER_STATUSES = [
  "draft",
  "scheduled",
  "assigned",
  "accepted",
  "traveling",
  "on_site",
  "in_progress",
  "awaiting_signature",
  "completed",
  "reviewed",
  "billed",
  "cancelled",
] as const;

export type WorkOrderStatus = (typeof WORK_ORDER_STATUSES)[number];

export const WORK_ORDER_STATUS_LABELS: Record<WorkOrderStatus, string> = {
  draft: "Rascunho",
  scheduled: "Agendada",
  assigned: "Atribuída",
  accepted: "Aceita",
  traveling: "Em deslocamento",
  on_site: "No local",
  in_progress: "Em atendimento",
  awaiting_signature: "Aguardando assinatura",
  completed: "Concluída",
  reviewed: "Revisada",
  billed: "Faturada",
  cancelled: "Cancelada",
};

export const SERVICE_TYPES = [
  "calibracao",
  "manutencao",
  "comissionamento",
  "startup",
  "outro",
] as const;

export type ServiceType = (typeof SERVICE_TYPES)[number];

export const SERVICE_TYPE_LABELS: Record<ServiceType, string> = {
  calibracao: "Calibração",
  manutencao: "Manutenção",
  comissionamento: "Comissionamento",
  startup: "Start-up",
  outro: "Outro",
};

export const SYSTEM_TYPES = [
  "carregamento",
  "descarregamento",
  "telemetria",
  "aditivacao",
  "outro",
] as const;

export type SystemType = (typeof SYSTEM_TYPES)[number];

export const SYSTEM_TYPE_LABELS: Record<SystemType, string> = {
  carregamento: "Carregamento",
  descarregamento: "Descarregamento",
  telemetria: "Telemetria",
  aditivacao: "Aditivação",
  outro: "Outro",
};

export const TECHNICIAN_FUNCTIONS = [
  "responsavel_tecnico",
  "suporte_tecnico",
] as const;

export type TechnicianFunction = (typeof TECHNICIAN_FUNCTIONS)[number];

export const TECHNICIAN_FUNCTION_LABELS: Record<TechnicianFunction, string> = {
  responsavel_tecnico: "Responsável técnico",
  suporte_tecnico: "Suporte técnico",
};

const TRANSITIONS: Record<WorkOrderStatus, WorkOrderStatus[]> = {
  draft: ["scheduled", "assigned", "cancelled"],
  scheduled: ["assigned", "cancelled"],
  assigned: ["accepted", "traveling", "cancelled"],
  accepted: ["traveling", "cancelled"],
  traveling: ["on_site", "cancelled"],
  on_site: ["in_progress", "cancelled"],
  in_progress: ["awaiting_signature", "completed", "cancelled"],
  awaiting_signature: ["completed", "cancelled"],
  completed: ["reviewed"],
  reviewed: ["billed"],
  billed: [],
  cancelled: [],
};

export function canTransition(
  from: WorkOrderStatus,
  to: WorkOrderStatus,
): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function formatWorkOrderNumber(number: number, year: number): string {
  return `GS ${String(number).padStart(3, "0")}/${String(year).slice(-2)}`;
}

export function digitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

export function formatCnpj(value: string): string {
  const d = digitsOnly(value).slice(0, 14);
  if (d.length !== 14) return value;
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`;
}

export function maskCnpj(value: string): string {
  const d = digitsOnly(value).slice(0, 14);
  if (d.length <= 2) return d;
  if (d.length <= 5) return `${d.slice(0, 2)}.${d.slice(2)}`;
  if (d.length <= 8) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5)}`;
  if (d.length <= 12) {
    return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8)}`;
  }
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`;
}
