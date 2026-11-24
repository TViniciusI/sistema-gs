import {
  getCampoOrder,
  isFieldTechnicianUser,
  listCampoOrders,
  listCampoUsers,
  parseOsRdos,
  type CampoOrder,
  type CampoUser,
} from "@/lib/campo-data";
import {
  normalizePersonKey,
  parseClockMinutes,
  rdoWorkedMinutes,
} from "@/lib/campo-data/work-hours";
import type { HorasRow } from "@/components/equipe/equipe-horas-panel";

function orderMentionsTech(os: CampoOrder, keys: Set<string>) {
  const blob = normalizePersonKey(
    [
      os.technicianName,
      String(os.raw.technicianEmail || ""),
      String(os.raw.technicianEmails || ""),
    ].join(" "),
  );
  return [...keys].some((k) => k && blob.includes(k));
}

function inMonth(dateRaw: string, ym: string) {
  const d = new Date(dateRaw);
  if (Number.isNaN(d.getTime())) {
    return String(dateRaw || "").startsWith(ym);
  }
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  return `${y}-${m}` === ym;
}

function lunchLabel(rdo: {
  lunchStart: string;
  lunchEnd: string;
  clockIn: string;
  clockOut: string;
}) {
  const start = parseClockMinutes(rdo.lunchStart);
  const end = parseClockMinutes(rdo.lunchEnd);
  if (start != null && end != null && end !== start) {
    return `Almoço ${rdo.lunchStart}–${rdo.lunchEnd}`;
  }
  const cin = parseClockMinutes(rdo.clockIn);
  const cout = parseClockMinutes(rdo.clockOut);
  if (cin == null || cout == null) return "";
  const presence =
    (cout <= cin ? cout + 24 * 60 : cout) - cin;
  if (presence > 6 * 60) return "Almoço 1h (padrão)";
  return "";
}

export function currentYearMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

export function listFieldTechnicians(users: CampoUser[]) {
  return users
    .filter((u) => isFieldTechnicianUser(u))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
}

export async function buildEquipeHorasRows(input: {
  users: CampoUser[];
  techFilter?: string;
  month: string;
}): Promise<{
  technicians: CampoUser[];
  selected: CampoUser | null;
  rows: HorasRow[];
}> {
  const technicians = listFieldTechnicians(input.users);
  const selected =
    technicians.find(
      (u) =>
        normalizePersonKey(u.name) ===
          normalizePersonKey(input.techFilter || "") ||
        normalizePersonKey(u.email) ===
          normalizePersonKey(input.techFilter || "") ||
        normalizePersonKey(u.login) ===
          normalizePersonKey(input.techFilter || ""),
    ) ||
    technicians[0] ||
    null;

  if (!selected) {
    return { technicians, selected: null, rows: [] };
  }

  const selectedKeys = new Set(
    [selected.name, selected.email, selected.login]
      .map(normalizePersonKey)
      .filter(Boolean),
  );

  const orders = await listCampoOrders();
  const candidates = orders
    .filter((os) => orderMentionsTech(os, selectedKeys))
    .slice(0, 24);

  const needHydrate = candidates.filter(
    (os) =>
      os.payloadLight ||
      !Array.isArray(os.raw.rdos) ||
      os.raw.rdos.length === 0,
  );
  const hydratedMap = new Map<string, (typeof candidates)[number]>();
  // Hidrata em lotes de 6 para não saturar o Apps Script.
  for (let i = 0; i < needHydrate.length; i += 6) {
    const batch = needHydrate.slice(i, i + 6);
    const loaded = await Promise.all(
      batch.map(async (os) => [(await getCampoOrder(os.id)) || os, os.id] as const),
    );
    for (const [os, id] of loaded) hydratedMap.set(id, os);
  }
  const hydrated = candidates.map(
    (os) => hydratedMap.get(os.id) || os,
  );

  const rows: HorasRow[] = [];
  for (const os of hydrated) {
    if (normalizePersonKey(os.status) === "rascunho") continue;
    const teamHit = orderMentionsTech(os, selectedKeys);
    for (const rdo of parseOsRdos(os)) {
      if (!inMonth(rdo.date, input.month)) continue;
      const responsible = normalizePersonKey(rdo.responsibleName);
      const belongs =
        (responsible && selectedKeys.has(responsible)) ||
        (!responsible && teamHit) ||
        teamHit;
      if (!belongs) continue;
      const minutes = rdoWorkedMinutes(rdo);
      if (minutes <= 0 && !rdo.clockIn && !rdo.clockOut) continue;
      rows.push({
        osId: os.id,
        osNumber: os.number,
        client: os.clientName || "—",
        date: rdo.date,
        clockIn: rdo.clockIn || "—",
        clockOut: rdo.clockOut || "—",
        lunchLabel: lunchLabel(rdo),
        minutes,
        responsible: rdo.responsibleName || os.technicianName || "—",
      });
    }
  }

  rows.sort((a, b) => {
    const da = new Date(a.date).getTime() || 0;
    const db = new Date(b.date).getTime() || 0;
    return db - da;
  });

  return { technicians, selected, rows };
}
