import {
  getInpmDensitiesSync,
  inpmCount,
  inpmMax,
  inpmMin,
  inpmStep,
  tempCount,
  tempMax,
  tempMin,
  tempStep,
} from "./inpm-table";

export type AlcoolResult = {
  density20: number;
  ctl: number;
  volume20: number;
  weight: number;
  variance?: number;
  variancePercent?: number;
  inpm: number;
};

/**
 * Conversão NBR 5992 — mesmas fórmulas da aba Conversão do Excel GS / app Flutter.
 *
 * - DENS20(ρ,T) → densidade a 20 °C (tabela INPM)
 * - INPM(ρ,T) → grau INPM a partir da densidade a 20 °C
 * - CTL = ROUND(FCV/D9 × (1+0,000036×(Tct−20)), 4) com FCV = ρ(INPM, Tct)
 * - Volume L20 = ROUND(V × CTL, 0)
 */
export function convertAlcool(input: {
  densityAmbient: number;
  temperature: number;
  volumeAmbient: number;
  temperatureCt: number;
  volumeDanfe?: number;
  densities?: Float32Array;
}): AlcoolResult {
  const densities = input.densities ?? getInpmDensitiesSync();
  if (!densities) {
    throw new Error("Tabela INPM ainda não carregada.");
  }

  const inpmSample = roundInpm(
    findInpmAmbient(densities, input.densityAmbient, input.temperature),
  );
  const density20 = round2(densityAt(densities, inpmSample, 20));
  const inpm = roundInpm(findInpmAt(densities, density20, 20));
  const density20Final = round2(densityAt(densities, inpm, 20));

  const rhoCt = densityAt(densities, inpm, tableTemp(input.temperatureCt));
  const ctl = round4(
    (rhoCt / density20Final) *
      (1 + 0.000036 * (input.temperatureCt - 20)),
  );
  const volume20 = Math.round(input.volumeAmbient * ctl);
  const weight = (volume20 * density20Final) / 1000;
  const variance =
    input.volumeDanfe === undefined
      ? undefined
      : volume20 - input.volumeDanfe;
  const variancePercent =
    variance === undefined ||
    input.volumeDanfe === undefined ||
    input.volumeDanfe === 0
      ? undefined
      : (variance / input.volumeDanfe) * 100;

  return {
    density20: density20Final,
    ctl,
    volume20,
    weight,
    variance,
    variancePercent,
    inpm,
  };
}

function tableTemp(temp: number) {
  return Math.round(temp * 10) / 10;
}

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

function roundInpm(value: number) {
  return Math.round(value * 100) / 100;
}

function round4(value: number) {
  return Math.round(value * 10000) / 10000;
}

function densityAt(densities: Float32Array, inpm: number, temp: number) {
  const i0 = Math.min(Math.max(inpmIndex(inpm), 0), inpmCount - 1);
  const i = Math.floor(i0);
  if (i0 === i || i >= inpmCount - 1) {
    return rowDensity(densities, i, temp);
  }
  const frac = i0 - i;
  const d0 = rowDensity(densities, i, temp);
  const d1 = rowDensity(densities, i + 1, temp);
  return d0 + frac * (d1 - d0);
}

function rowDensity(densities: Float32Array, row: number, temp: number) {
  const offset = row * tempCount;
  if (temp <= tempMin) return densities[offset];
  if (temp >= tempMax) {
    const last = densities[offset + tempCount - 1];
    const prev = densities[offset + tempCount - 2];
    const slope = (last - prev) / tempStep;
    return last + slope * (temp - tempMax);
  }
  const t0 = Math.min(
    Math.max(Math.floor((temp - tempMin) / tempStep), 0),
    tempCount - 2,
  );
  const frac = (temp - (tempMin + t0 * tempStep)) / tempStep;
  return (
    densities[offset + t0] +
    frac * (densities[offset + t0 + 1] - densities[offset + t0])
  );
}

function inpmIndex(inpm: number) {
  if (inpm <= inpmMin) return 0;
  if (inpm >= inpmMax) return inpmCount - 1;
  return Math.min(
    Math.max((inpm - inpmMin) / inpmStep, 0),
    inpmCount - 1,
  );
}

function findInpmAmbient(
  densities: Float32Array,
  density: number,
  temp: number,
) {
  return findInpmAt(densities, density, tableTemp(temp));
}

function findInpmAt(
  densities: Float32Array,
  density: number,
  temp: number,
) {
  let lo = inpmMin;
  let hi = inpmMax;
  for (let i = 0; i < 80; i++) {
    const mid = (lo + hi) / 2;
    if (densityAt(densities, mid, temp) < density) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return Math.min(Math.max((lo + hi) / 2, inpmMin), inpmMax);
}
