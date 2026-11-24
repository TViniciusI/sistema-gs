/** Tipos e defaults alinhados ao `CalibrationKind` do GS Campo. */

export const CALIBRATION_KINDS = [
  { value: "volumetric", label: "Volumétrica / vazão" },
  { value: "volumetricInverted", label: "Volumétrica invertida" },
  { value: "temperature", label: "Temperatura" },
  { value: "temperatureMesh", label: "Malha de temperatura" },
  { value: "density", label: "Densidade" },
  { value: "pressure", label: "Pressão" },
  { value: "conductivity", label: "Condutividade" },
  { value: "telemetry", label: "Telemetria" },
] as const;

export type CalibrationKindValue = (typeof CALIBRATION_KINDS)[number]["value"];

export function normalizeCalibrationKind(raw: string): CalibrationKindValue {
  const v = raw.trim();
  switch (v) {
    case "volumetricInverted":
    case "volumetricaInvertida":
      return "volumetricInverted";
    case "temperature":
      return "temperature";
    case "temperatureMesh":
    case "malha":
      return "temperatureMesh";
    case "density":
      return "density";
    case "pressure":
      return "pressure";
    case "conductivity":
    case "condutividade":
      return "conductivity";
    case "telemetry":
      return "telemetry";
    default:
      return "volumetric";
  }
}

export function isVolumetricKind(kind: string) {
  const k = normalizeCalibrationKind(kind);
  return k === "volumetric" || k === "volumetricInverted";
}

export function isTelemetryKind(kind: string) {
  return normalizeCalibrationKind(kind) === "telemetry";
}

export function isGenericKind(kind: string) {
  return !isVolumetricKind(kind) && !isTelemetryKind(kind);
}

export function isTemperatureFamily(kind: string) {
  const k = normalizeCalibrationKind(kind);
  return k === "temperature" || k === "temperatureMesh";
}

const TEMP_UNITS = ["°C", "K", "°F"];
const LENGTH_UNITS = ["mm", "cm", "m"];
const PRESSURE_UNITS = ["bar", "kPa", "psi", "mmH₂O", "kgf/cm²"];
const DENSITY_UNITS = ["kg/m³", "g/cm³", "°API"];
const CONDUCTIVITY_UNITS = ["µS/cm", "mS/cm", "S/m", "µS/m", "mS/m"];
const FLOW_UNITS = ["L/min", "m³/h", "L/h", "gpm"];

export function defaultMeasurementUnit(kind: string) {
  switch (normalizeCalibrationKind(kind)) {
    case "temperature":
    case "temperatureMesh":
      return "°C";
    case "density":
      return "kg/m³";
    case "pressure":
      return "bar";
    case "conductivity":
      return "µS/cm";
    case "telemetry":
      return "mm";
    case "volumetric":
    case "volumetricInverted":
      return "L/min";
  }
}

export function suggestedMeasurementUnits(kind: string): string[] {
  switch (normalizeCalibrationKind(kind)) {
    case "temperature":
    case "temperatureMesh":
    case "density":
    case "pressure":
      return [...TEMP_UNITS, ...LENGTH_UNITS, ...PRESSURE_UNITS, ...DENSITY_UNITS];
    case "conductivity":
      return CONDUCTIVITY_UNITS;
    case "telemetry":
      return [...LENGTH_UNITS, ...TEMP_UNITS];
    case "volumetric":
    case "volumetricInverted":
      return FLOW_UNITS;
  }
}

export function defaultWorkingPrinciple(kind: string, equipmentType = "") {
  if (isVolumetricKind(kind)) {
    return equipmentType.toLowerCase().includes("coriolis")
      ? "Coriolis"
      : "Medição Volumétrica";
  }
  switch (normalizeCalibrationKind(kind)) {
    case "temperature":
      return "Termorresistência";
    case "temperatureMesh":
      return "Malha de temperatura";
    case "density":
      return "Tubo Vibratório";
    case "conductivity":
      return "Célula de condutividade";
    case "telemetry":
      return "Servo Operado";
    default:
      return "";
  }
}

export function pointsSectionTitle(kind: string) {
  if (isVolumetricKind(kind)) return "Pontos de vazão";
  if (isTelemetryKind(kind)) return "Canais de telemetria";
  if (isTemperatureFamily(kind)) return "Ciclos e pontos";
  if (normalizeCalibrationKind(kind) === "density") {
    return "Pontos (um por produto)";
  }
  return "Pontos";
}

export function pointsSectionHint(kind: string) {
  if (isVolumetricKind(kind)) {
    return normalizeCalibrationKind(kind) === "volumetricInverted"
      ? "Mf = instrumento ÷ padrão (invertida)"
      : "Mf = padrão ÷ instrumento (mesma regra do app)";
  }
  if (isTelemetryKind(kind)) {
    return "Canais encontrado / deixado — padrão × instrumento, como no GS Campo.";
  }
  if (isTemperatureFamily(kind)) {
    return "Cada ciclo é uma passagem; cada ponto é uma temperatura diferente. Ciclos vazios não entram no certificado.";
  }
  if (normalizeCalibrationKind(kind) === "density") {
    return "Um ponto por produto; leituras são repetições do mesmo produto.";
  }
  return "Preencha só o que medir. Ciclos vazios não entram no certificado.";
}
