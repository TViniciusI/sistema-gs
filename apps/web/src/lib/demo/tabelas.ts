import {
  ctlFromDensity20,
  density20FromAmbient,
} from "./derivados-tables";

export const GS_TABLES = [
  {
    id: "derivados",
    title: "Conversão de derivados de petróleo",
    standard: "ASTM / tabela GS · 20 °C",
    fileName: "GS- TABELA DE CONVERSÃO DOS DERIVADOS DE PETROLEO.xls",
    href: "/tabelas/conversao-derivados-petroleo.xls",
    description:
      "Densidade e volume corrigidos a 20 °C, fator CTL, peso e perda/sobra contra o DANFE.",
  },
  {
    id: "alcool",
    title: "Correção a 20 °C — álcool",
    standard: "NBR 5992 · misturas etanol-água",
    fileName: "Cópia de correção a 20 - Alcool.xls",
    href: "/tabelas/correcao-20-alcool.xls",
    description:
      "Conversão de densidade e volume a 20 °C para álcool, com a tabela INPM da GS.",
  },
  {
    id: "validacao",
    title: "Validação da calibração — derivados",
    standard: "Planilha operacional GS",
    fileName: "Correção volumétrica Derivados.xlsx",
    href: "/tabelas/correcao-volumetrica-derivados.xlsx",
    description:
      "Compara volume da base e do sistema (CTL, volume a 20 °C e perda/sobra).",
  },
] as const;

export type GsTableId = (typeof GS_TABLES)[number]["id"];

/** Conversão ASTM / tabela GS (DNS_20 + FCV_20 da planilha REV.01). */
export function convertDerivados(input: {
  densityAmbient: number;
  temperature: number;
  volumeAmbient: number;
  temperatureCt: number;
  volumeDanfe?: number;
}) {
  const density20 = density20FromAmbient(
    input.densityAmbient,
    input.temperature,
  );
  const ctl = round4(
    ctlFromDensity20(density20, input.temperatureCt),
  );
  const volume20 = round2(input.volumeAmbient * ctl);
  const weight = (volume20 * density20) / 1000;
  const variance =
    input.volumeDanfe === undefined ? undefined : volume20 - input.volumeDanfe;
  const variancePercent =
    variance === undefined ||
    input.volumeDanfe === undefined ||
    input.volumeDanfe === 0
      ? undefined
      : (variance / input.volumeDanfe) * 100;
  return { density20, ctl, volume20, weight, variance, variancePercent };
}

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

function round4(value: number) {
  return Math.round(value * 10000) / 10000;
}

export function parseBrNumber(raw: string): number | null {
  let text = raw.trim().replace(/\s/g, "").replace(/%/g, "");
  if (!text) return null;

  const lastComma = text.lastIndexOf(",");
  const lastDot = text.lastIndexOf(".");

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      text = text.replace(/\./g, "").replace(",", ".");
    } else {
      text = text.replace(/,/g, "");
    }
  } else if (lastComma >= 0) {
    const before = text.substring(0, lastComma);
    const after = text.substring(lastComma + 1);
    if (
      after.length === 3 &&
      (before.length <= 2 || after === "000")
    ) {
      text = before + after;
    } else {
      text = text.replace(",", ".");
    }
  } else if (lastDot >= 0) {
    const parts = text.split(".");
    if (
      parts.length > 1 &&
      parts[parts.length - 1].length === 3 &&
      parts.every((part) => part.length <= 3)
    ) {
      text = parts.join("");
    }
  }

  const value = Number(text);
  return Number.isFinite(value) ? value : null;
}

export function formatPt(value: number, digits = 2) {
  return value.toLocaleString("pt-BR", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}
