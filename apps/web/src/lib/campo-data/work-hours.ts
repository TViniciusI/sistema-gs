/** Espelho simplificado de apps/mobile/lib/data/work_hours.dart */

const DEFAULT_LUNCH_MINUTES = 60;
const LUNCH_REQUIRED_AFTER = 6 * 60;
const MINUTES_PER_DAY = 24 * 60;

export function parseClockMinutes(raw: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(raw || "").trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

function clockOutOnTimeline(clockIn: number, clockOut: number) {
  return clockOut <= clockIn ? clockOut + MINUTES_PER_DAY : clockOut;
}

export function rdoWorkedMinutes(rdo: {
  clockIn: string;
  clockOut: string;
  lunchStart: string;
  lunchEnd: string;
}): number {
  const clockIn = parseClockMinutes(rdo.clockIn);
  const clockOut = parseClockMinutes(rdo.clockOut);
  if (clockIn == null || clockOut == null) return 0;
  const presence = clockOutOnTimeline(clockIn, clockOut) - clockIn;
  if (presence <= 0) return 0;

  const lunchStart = parseClockMinutes(rdo.lunchStart);
  const lunchEnd = parseClockMinutes(rdo.lunchEnd);
  let lunch = 0;
  if (lunchStart != null && lunchEnd != null && lunchEnd !== lunchStart) {
    lunch = clockOutOnTimeline(lunchStart, lunchEnd) - lunchStart;
    if (lunch > presence) lunch = presence;
  } else if (presence > LUNCH_REQUIRED_AFTER) {
    lunch = Math.min(DEFAULT_LUNCH_MINUTES, presence);
  }

  return Math.max(0, presence - lunch);
}

export function formatWorkedHours(minutes: number): string {
  if (!minutes || minutes <= 0) return "0:00";
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}:${String(m).padStart(2, "0")}`;
}

export function normalizePersonKey(value: string) {
  return String(value || "")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9@._+\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
