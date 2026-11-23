import { campoOsStatusLabel } from "./labels";
import { isExcludedFromTechLoad } from "./office-filters";
import type { CampoOrder } from "./types";

export { isExcludedFromTechLoad } from "./office-filters";

export type DashboardOrderLite = {
  id: string;
  number: string;
  status: string;
  clientName: string;
  technicianName: string;
  startsAt: string;
  updatedAt: string;
};

function normalizeStatus(status: string) {
  return status.trim().toLowerCase().replace(/\s+/g, "");
}

function weekKey(d: Date) {
  const copy = new Date(d);
  const day = copy.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  copy.setHours(0, 0, 0, 0);
  copy.setDate(copy.getDate() + diff);
  return copy.toISOString().slice(0, 10);
}

function parseOrderDay(os: CampoOrder): Date | null {
  const raw = (os.startsAt || os.updatedAt || "").slice(0, 10);
  if (!raw) return null;
  const t = Date.parse(`${raw}T12:00:00`);
  return Number.isFinite(t) ? new Date(t) : null;
}

export function toDashboardOrders(orders: CampoOrder[]): DashboardOrderLite[] {
  return orders.map((os) => ({
    id: os.id,
    number: os.number,
    status: os.status,
    clientName: os.clientName,
    technicianName: os.technicianName,
    startsAt: os.startsAt,
    updatedAt: os.updatedAt,
  }));
}

export function buildStatusSlices(orders: CampoOrder[]) {
  const buckets: { key: string; match: (s: string) => boolean; color: string }[] =
    [
      {
        key: "abertas",
        match: (s) =>
          s === "comtecnico" || s === "emandamento" || s === "rascunho",
        color: "#c59e39",
      },
      {
        key: "servicoencerrado",
        match: (s) => s === "servicoencerrado",
        color: "#9a5b12",
      },
      {
        key: "encerrada",
        match: (s) => s === "encerrada",
        color: "#2f6b4f",
      },
      {
        key: "outras",
        match: () => false,
        color: "#5c6b7a",
      },
    ];

  const counts = new Map<string, number>();
  for (const b of buckets) counts.set(b.key, 0);

  for (const os of orders) {
    const s = normalizeStatus(os.status);
    const hit = buckets.find((b) => b.key !== "outras" && b.match(s));
    const key = hit?.key ?? "outras";
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  return buckets
    .map((b) => ({
      key: b.key,
      label:
        b.key === "abertas"
          ? "Em campo / abertas"
          : b.key === "outras"
            ? "Outras"
            : campoOsStatusLabel(b.key),
      count: counts.get(b.key) ?? 0,
      color: b.color,
    }))
    .filter((b) => b.count > 0 || b.key !== "outras");
}

export function buildWeekBuckets(orders: CampoOrder[], weeks = 8) {
  const now = new Date();
  const keys: string[] = [];
  for (let i = weeks - 1; i >= 0; i -= 1) {
    const d = new Date(now);
    d.setDate(d.getDate() - i * 7);
    keys.push(weekKey(d));
  }

  const counts = new Map(keys.map((k) => [k, 0]));
  for (const os of orders) {
    const day = parseOrderDay(os);
    if (!day) continue;
    const key = weekKey(day);
    if (counts.has(key)) counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  return keys.map((key) => {
    const start = new Date(`${key}T12:00:00`);
    return {
      key,
      label: start.toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "short",
      }),
      count: counts.get(key) ?? 0,
    };
  });
}

export function buildTechLoad(orders: CampoOrder[], limit = 6) {
  const open = orders.filter((os) => normalizeStatus(os.status) !== "encerrada");
  const map = new Map<string, number>();
  for (const os of open) {
    const name = (os.technicianName || "").trim() || "Sem técnico";
    if (isExcludedFromTechLoad(name)) continue;
    map.set(name, (map.get(name) ?? 0) + 1);
  }
  return [...map.entries()]
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, limit);
}
