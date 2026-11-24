/** Labels de tipo de calibração — seguro para Client Components. */

export function kindLabel(kind: string) {
  const k = kind.trim().toLowerCase();
  if (k === "volumetric" || k.includes("vazao") || k.includes("vazão")) {
    return "Volumétrica / vazão";
  }
  if (k === "volumetricinverted") return "Volumétrica invertida";
  if (
    k === "temperature" ||
    (k.includes("temperatura") && !k.includes("malha") && !k.includes("mesh"))
  ) {
    return "Temperatura";
  }
  if (k === "temperaturemesh" || k.includes("malha") || k.includes("mesh")) {
    return "Malha de temperatura";
  }
  if (k === "density" || k.includes("dens")) return "Densidade";
  if (k === "pressure" || k.includes("press")) return "Pressão";
  if (k === "conductivity" || k.includes("condut")) return "Condutividade";
  if (k === "telemetry" || k.includes("telemetr")) return "Telemetria";
  return kind || "Calibração";
}
