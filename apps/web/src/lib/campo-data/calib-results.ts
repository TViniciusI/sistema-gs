/** Resumo + bancada de leitura dos jobs getcalib (CalibrationJob). */

import {
  correctedMeterFactor,
  formatCalibNumber,
  formatPercent,
  meanOf,
  meterFactor,
  parseCalibNumber,
  repeatabilityPercent,
  volumetricErrorPercent,
} from "./calibration-math";

function text(value: unknown) {
  return String(value ?? "").trim();
}

function num(value: unknown): number | null {
  return parseCalibNumber(value);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
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

export type CalibRunDetail = {
  id: string;
  standardVolume: number | null;
  objectVolume: number | null;
  density: number | null;
  temperature: number | null;
  meterFactor: number | null;
  errorPct: number | null;
};

export type CalibFlowPointDetail = {
  id: string;
  label: string;
  flowRate: number | null;
  flowUnit: string;
  oldMeterFactor: number | null;
  verification: CalibRunDetail[];
  meanMf: number | null;
  repeatabilityPct: number | null;
  suggestedFactor: number | null;
  conferenceRuns: number;
};

export type CalibStandardUsed = {
  id: string;
  tag: string;
  description: string;
  certificate: string;
  validity: string;
  uncertainty: string;
  coverageK: string;
  serialNumber: string;
  manufacturer: string;
  model: string;
};

export type CalibWorkbench = {
  summary: CalibResultsSummary;
  status: string;
  kind: string;
  number: string;
  clientName: string;
  equipmentTag: string;
  equipmentType: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  technicianName: string;
  calibrationDate: string;
  nextCalibrationDate: string;
  site: string;
  procedure: string;
  ambientTemp: string;
  humidity: string;
  pressure: string;
  fluid: string;
  fluidDensity: string;
  fluidViscosity: string;
  productDensity: string;
  productTemperature: string;
  measurementUncertainty: string;
  coverageFactor: string;
  effectiveDof: string;
  meterKFactorFound: string;
  meterKFactorLeft: string;
  osId: string;
  osNumber: string;
  standards: CalibStandardUsed[];
  flowDetails: CalibFlowPointDetail[];
  genericPoints: CalibGenericPointRow[];
  linearityPct: number | null;
  hasAny: boolean;
};

function countFilledRuns(raw: unknown): number {
  if (!Array.isArray(raw)) return 0;
  let n = 0;
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    if (
      r.standardVolume != null ||
      r.meterVolume != null ||
      r.objectVolume != null ||
      r.isFilled === true
    ) {
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

function parseRun(raw: unknown, index: number): CalibRunDetail | null {
  const r = asRecord(raw);
  if (!r) return null;
  const standardVolume =
    num(r.standardVolume) ?? num(r.standard) ?? num(r.padrao);
  const objectVolume =
    num(r.objectVolume) ??
    num(r.meterVolume) ??
    num(r.instrument) ??
    num(r.objeto);
  if (standardVolume == null && objectVolume == null) return null;
  const mf = meterFactor(standardVolume, objectVolume);
  return {
    id: text(r.id) || `run-${index}`,
    standardVolume,
    objectVolume,
    density: num(r.density),
    temperature: num(r.temperature),
    meterFactor: mf,
    errorPct: volumetricErrorPercent(standardVolume, objectVolume),
  };
}

function parseStandards(raw: unknown): CalibStandardUsed[] {
  if (!Array.isArray(raw)) return [];
  const out: CalibStandardUsed[] = [];
  for (const [index, item] of raw.entries()) {
    const s = asRecord(item);
    if (!s) continue;
    out.push({
      id: text(s.id) || `std-${index}`,
      tag: text(s.tag) || text(s.name),
      description: text(s.description) || text(s.type),
      certificate: text(s.certificate),
      validity: text(s.validity),
      uncertainty: text(s.uncertainty),
      coverageK: text(s.coverageK) || text(s.coverageFactor),
      serialNumber: text(s.serialNumber) || text(s.serial),
      manufacturer: text(s.manufacturer),
      model: text(s.model),
    });
  }
  return out;
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
      flowRate: flow == null ? "—" : `${formatCalibNumber(flow, 2)} ${unit}`,
      oldMeterFactor: formatCalibNumber(num(p.oldMeterFactor), 6),
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
      oldFactor: formatCalibNumber(num(p.oldFactor), 6),
      newValue: formatCalibNumber(num(p.newValue), 6),
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

export function buildCalibrationWorkbench(
  raw: Record<string, unknown> | null | undefined,
): CalibWorkbench {
  const data = raw || {};
  const summary = summarizeCalibrationResults(data);
  const flowDetails: CalibFlowPointDetail[] = [];
  const meanFactors: number[] = [];

  const points = Array.isArray(data.points) ? data.points : [];
  for (const [index, item] of points.entries()) {
    const p = asRecord(item);
    if (!p) continue;
    const verificationRaw = Array.isArray(p.verification) ? p.verification : [];
    const verification = verificationRaw
      .map((run, i) => parseRun(run, i))
      .filter(Boolean) as CalibRunDetail[];
    const factors = verification
      .map((r) => r.meterFactor)
      .filter((v): v is number => v != null);
    const meanMf = meanOf(factors);
    const old = num(p.oldMeterFactor);
    const suggested =
      old != null && meanMf != null
        ? correctedMeterFactor(old, meanMf)
        : null;
    if (meanMf != null) meanFactors.push(meanMf);
    flowDetails.push({
      id: text(p.id) || `flow-${index}`,
      label: `Ponto ${index + 1}`,
      flowRate: num(p.flowRate),
      flowUnit: text(p.flowUnit) || "L/min",
      oldMeterFactor: old,
      verification,
      meanMf,
      repeatabilityPct: repeatabilityPercent(factors),
      suggestedFactor: suggested,
      conferenceRuns: conferenceFilledRuns(p.conferences),
    });
  }

  const fluidDensity =
    [text(data.fluidDensityMin), text(data.fluidDensityMax)]
      .filter(Boolean)
      .join(" – ") || text(data.productDensity);

  const fluidViscosity = [
    text(data.fluidViscosityMin),
    text(data.fluidViscosityMax),
  ]
    .filter(Boolean)
    .join(" – ");

  return {
    summary,
    status: text(data.status) || text(data.phase),
    kind: text(data.kind),
    number: text(data.number),
    clientName: text(data.clientName),
    equipmentTag: text(data.equipmentTag),
    equipmentType: text(data.equipmentType),
    manufacturer: text(data.manufacturer),
    model: text(data.model),
    serialNumber: text(data.serialNumber),
    technicianName:
      text(data.technicianName) || text(data.fieldTechnicianName),
    calibrationDate: text(data.calibrationDate),
    nextCalibrationDate: text(data.nextCalibrationDate),
    site: text(data.site),
    procedure: text(data.procedure),
    ambientTemp: text(data.ambientTemp),
    humidity: text(data.humidity),
    pressure: text(data.pressure),
    fluid: text(data.fluid),
    fluidDensity,
    fluidViscosity,
    productDensity: text(data.productDensity),
    productTemperature: text(data.productTemperature),
    measurementUncertainty: text(data.measurementUncertainty),
    coverageFactor: text(data.coverageFactor),
    effectiveDof: text(data.effectiveDof),
    meterKFactorFound:
      text(data.meterKFactorFound) || text(data.meterKFactor),
    meterKFactorLeft: text(data.meterKFactorLeft),
    osId: text(data.osId),
    osNumber: text(data.osNumber),
    standards: parseStandards(data.standards),
    flowDetails,
    genericPoints: summary.genericPoints,
    linearityPct:
      meanFactors.length >= 2
        ? (() => {
            const min = Math.min(...meanFactors);
            const max = Math.max(...meanFactors);
            return (max - min) * 100;
          })()
        : null,
    hasAny:
      summary.hasAny ||
      flowDetails.length > 0 ||
      parseStandards(data.standards).length > 0 ||
      Boolean(text(data.fluid) || text(data.clientName)),
  };
}

export { formatCalibNumber, formatPercent };
