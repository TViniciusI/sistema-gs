/** Espelho de apps/mobile/lib/data/calibration_math.dart (núcleo). */

export function parseCalibNumber(raw: unknown): number | null {
  if (raw == null || raw === "") return null;
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : null;
  const s = String(raw)
    .trim()
    .replace(/\s/g, "")
    .replace("%", "")
    .replace(",", ".");
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

/** Meter factor Mf = padrão / objeto (ou invertido). */
export function meterFactor(
  standardVolume: number | null,
  objectVolume: number | null,
  inverted = false,
): number | null {
  if (standardVolume == null || objectVolume == null) return null;
  if (inverted) {
    if (standardVolume === 0) return null;
    return objectVolume / standardVolume;
  }
  if (objectVolume === 0) return null;
  return standardVolume / objectVolume;
}

export function volumetricErrorPercent(
  standardVolume: number | null,
  objectVolume: number | null,
  inverted = false,
): number | null {
  const factor = meterFactor(standardVolume, objectVolume, inverted);
  if (factor == null) return null;
  return (1 - factor) * 100;
}

export function meanOf(values: number[]): number | null {
  if (!values.length) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

export function sampleStdev(values: number[]): number | null {
  if (values.length < 2) return null;
  const mean = meanOf(values);
  if (mean == null) return null;
  let sum = 0;
  for (const value of values) {
    const d = value - mean;
    sum += d * d;
  }
  return Math.sqrt(sum / (values.length - 1));
}

/** Repetibilidade % = (Máx − Mín) / Mín × 100 */
export function repeatabilityPercent(factors: number[]): number | null {
  if (factors.length < 2) return null;
  const min = Math.min(...factors);
  const max = Math.max(...factors);
  if (min === 0) return null;
  return ((max - min) / min) * 100;
}

/** Linearidade % = (Maior − Menor) × 100 entre fatores das vazões */
export function linearityPercent(factors: number[]): number | null {
  if (factors.length < 2) return null;
  const min = Math.min(...factors);
  const max = Math.max(...factors);
  return (max - min) * 100;
}

export function correctedMeterFactor(oldFactor: number, meanFactor: number) {
  return oldFactor * meanFactor;
}

export function formatCalibNumber(
  value: number | null | undefined,
  digits = 4,
): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return value.toLocaleString("pt-BR", {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0,
  });
}

export function formatPercent(
  value: number | null | undefined,
  digits = 3,
): string {
  if (value == null || !Number.isFinite(value)) return "—";
  return `${formatCalibNumber(value, digits)} %`;
}
