/** Resumo leitura dos pontos gravados no job (getcalib / CalibrationJob). */

function text(value: unknown) {
  return String(value ?? "").trim();
}

function num(value: unknown): number | null {
  if (value == null || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function formatNum(value: number | null, digits = 4) {
  if (value == null) return "—";
  return value.toLocaleString("pt-BR", {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0,
  });
}

export type CalibFlowPointRow = {
  id: string;
  label: string;
  flowRate: string;
  oldMeterFactor: string;
  verificationRuns: number;
  conferenceRuns: number;
};

export type CalibGenericPointRow = {
  id: string;
  label: string;
  oldFactor: string;
  newValue: string;
  cyclesFilled: number;
  cyclesTotal: number;
};

export type CalibResultsSummary = {
  kFactorFound: string;
  kFactorLeft: string;
  uncertainty: string;
  coverageFactor: string;
  flowPoints: CalibFlowPointRow[];
  genericPoints: CalibGenericPointRow[];
  hasAny: boolean;
};

function countFilledRuns(raw: unknown): number {
  if (!Array.isArray(raw)) return 0;
  let n = 0;
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    if (r.standardVolume != null || r.meterVolume != null || r.isFilled === true) {
      n += 1;
      continue;
    }
    if (num(r.standard) != null || num(r.instrument) != null) n += 1;
  }
  return n;
}

function conferenceFilledRuns(conferences: unknown): number {
  if (!Array.isArray(conferences)) return 0;
  let total = 0;
  for (const attempt of conferences) {
    if (!attempt || typeof attempt !== "object") continue;
    const a = attempt as Record<string, unknown>;
    total += countFilledRuns(a.runs);
  }
  return total;
}

export function summarizeCalibrationResults(
  raw: Record<string, unknown> | null | undefined,
): CalibResultsSummary {
  const data = raw || {};
  const flowPoints: CalibFlowPointRow[] = [];
  const points = Array.isArray(data.points) ? data.points : [];
  for (const [index, item] of points.entries()) {
    if (!item || typeof item !== "object") continue;
    const p = item as Record<string, unknown>;
    const flow = num(p.flowRate);
    const unit = text(p.flowUnit) || "L/min";
    flowPoints.push({
      id: text(p.id) || `flow-${index}`,
      label: `Ponto ${index + 1}`,
      flowRate: flow == null ? "—" : `${formatNum(flow, 2)} ${unit}`,
      oldMeterFactor: formatNum(num(p.oldMeterFactor), 6),
      verificationRuns: countFilledRuns(p.verification),
      conferenceRuns: conferenceFilledRuns(p.conferences),
    });
  }

  const genericPoints: CalibGenericPointRow[] = [];
  const generics = Array.isArray(data.genericPoints) ? data.genericPoints : [];
  for (const [index, item] of generics.entries()) {
    if (!item || typeof item !== "object") continue;
    const p = item as Record<string, unknown>;
    const cycles = Array.isArray(p.cycles) ? p.cycles : [];
    const filled = countFilledRuns(cycles);
    genericPoints.push({
      id: text(p.id) || `gen-${index}`,
      label: text(p.label) || `Ponto ${index + 1}`,
      oldFactor: formatNum(num(p.oldFactor), 6),
      newValue: formatNum(num(p.newValue), 6),
      cyclesFilled: filled,
      cyclesTotal: cycles.length,
    });
  }

  const kFactorFound =
    text(data.meterKFactorFound) || text(data.meterKFactor) || "";
  const kFactorLeft = text(data.meterKFactorLeft);
  const uncertainty = text(data.measurementUncertainty);
  const coverageFactor = text(data.coverageFactor);

  return {
    kFactorFound,
    kFactorLeft,
    uncertainty,
    coverageFactor,
    flowPoints,
    genericPoints,
    hasAny:
      flowPoints.length > 0 ||
      genericPoints.length > 0 ||
      Boolean(kFactorFound || kFactorLeft || uncertainty),
  };
}
