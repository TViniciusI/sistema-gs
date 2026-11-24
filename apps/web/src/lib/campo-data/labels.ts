export function campoOsStatusLabel(status: string): string {
  const value = status.trim().toLowerCase();
  const map: Record<string, string> = {
    rascunho: "Rascunho",
    comtecnico: "Com o técnico",
    "com tecnico": "Com o técnico",
    emandamento: "Em andamento",
    "em andamento": "Em andamento",
    servicoencerrado: "Serviço encerrado",
    "servico encerrado": "Serviço encerrado",
    encerrada: "Encerrada",
  };
  return map[value.replace(/\s+/g, "")] || map[value] || status || "—";
}

export function campoOsStatusTone(
  status: string,
): "ok" | "warn" | "danger" | "neutral" {
  const value = status.trim().toLowerCase().replace(/\s+/g, "");
  if (value === "encerrada") return "ok";
  if (value === "servicoencerrado" || value === "emandamento") return "warn";
  if (value === "rascunho") return "neutral";
  return "neutral";
}

export function campoRoleLabel(role: string): string {
  const value = role.trim().toLowerCase();
  if (value === "admin" || value === "adm" || value === "administrativo") {
    return "Administrativo";
  }
  if (value === "ambos") return "Administrativo e técnico";
  if (value === "dev") return "Desenvolvedor";
  return "Técnico";
}

export function kindLabel(kind: string): string {
  const value = kind.trim().toLowerCase();
  if (value === "preset") return "Preset";
  if (value === "transmitter") return "Transmissor";
  if (value === "presetandtransmitter") return "Preset + transmissor";
  if (value === "pt100") return "PT100";
  if (value === "densimeter") return "Densímetro";
  if (value === "mesh") return "Malha";
  if (value === "ilha") return "Ilha";
  if (value === "skid") return "Skid";
  return kind || "Conjunto";
}

export const CLIENT_ASSEMBLY_KINDS = [
  { value: "preset", label: "Preset" },
  { value: "transmitter", label: "Transmissor" },
  { value: "presetAndTransmitter", label: "Preset + transmissor" },
  { value: "pt100", label: "PT100" },
  { value: "densimeter", label: "Densímetro" },
  { value: "mesh", label: "Malha" },
] as const;
