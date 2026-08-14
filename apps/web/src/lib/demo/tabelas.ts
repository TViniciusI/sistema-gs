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

/** Aproximação operacional a partir das faixas DNS_20 / FCV_20 da planilha GS. */
export function convertDerivados(input: {
  densityAmbient: number;
  temperature: number;
  volumeAmbient: number;
  temperatureCt: number;
  volumeDanfe?: number;
}) {
  const dt = input.temperature - 20;
  const alpha = 0.00082 + Math.max(0, 900 - input.densityAmbient) * 0.00000125;
  const density20 =
    input.densityAmbient * (1 + alpha * dt + 0.00000035 * dt * dt);
  const dtCt = input.temperatureCt - 20;
  const ctl = round4(
    1 / (1 + alpha * dtCt + 0.00000035 * dtCt * dtCt),
  );
  const volume20 = input.volumeAmbient * ctl;
  const weight = (volume20 * density20) / 1000;
  const variance =
    input.volumeDanfe === undefined ? undefined : volume20 - input.volumeDanfe;
  return { density20, ctl, volume20, weight, variance };
}

function round4(value: number) {
  return Math.round(value * 10000) / 10000;
}

export function formatPt(value: number, digits = 2) {
  return value.toLocaleString("pt-BR", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}
