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
  if (value === "ilha") return "Ilha";
  if (value === "skid") return "Skid";
  return kind || "Conjunto";
}
