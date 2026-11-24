/** Metadados da tabela INPM (NBR 5992) — mesmos limites do app Flutter. */

export const inpmMin = 89.99999999999488;
export const inpmMax = 100.0;
export const inpmStep = 0.01;
export const tempMin = 10.0;
export const tempMax = 40.0;
export const tempStep = 0.1;
export const tempCount = 301;
export const inpmCount = 1001;

const EXPECTED_FLOATS = inpmCount * tempCount;

let cached: Float32Array | null = null;
let loading: Promise<Float32Array> | null = null;

function assertTable(densities: Float32Array) {
  if (densities.length !== EXPECTED_FLOATS) {
    throw new Error(
      `Tabela INPM inválida: ${densities.length} valores (esperado ${EXPECTED_FLOATS}).`,
    );
  }
  return densities;
}

/** Carrega a tabela INPM (binário estático, mesma matriz do app). */
export async function loadInpmDensities(
  source: string | ArrayBuffer | Float32Array = "/tabelas/inpm-densities.bin",
): Promise<Float32Array> {
  if (cached) return cached;
  if (source instanceof Float32Array) {
    cached = assertTable(source);
    return cached;
  }
  if (source instanceof ArrayBuffer) {
    cached = assertTable(new Float32Array(source));
    return cached;
  }
  if (!loading) {
    loading = (async () => {
      if (typeof window === "undefined") {
        const { readFile } = await import("fs/promises");
        const { join } = await import("path");
        const path = join(
          process.cwd(),
          "public",
          "tabelas",
          "inpm-densities.bin",
        );
        const buf = await readFile(path);
        cached = assertTable(
          new Float32Array(buf.buffer, buf.byteOffset, buf.byteLength / 4),
        );
        return cached;
      }
      const res = await fetch(source);
      if (!res.ok) throw new Error(`Falha ao carregar tabela INPM (${res.status}).`);
      const buf = await res.arrayBuffer();
      cached = assertTable(new Float32Array(buf));
      return cached;
    })().finally(() => {
      loading = null;
    });
  }
  return loading;
}

export function getInpmDensitiesSync(): Float32Array | null {
  return cached;
}

export function setInpmDensitiesForTests(densities: Float32Array) {
  cached = assertTable(densities);
}
