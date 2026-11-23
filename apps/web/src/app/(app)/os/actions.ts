"use server";

import { redirect } from "next/navigation";
import { getProfile } from "@/lib/auth";
import { saveCampoOrder } from "@/lib/campo-data";

const SERVICE_PRESETS: Record<string, string> = {
  manutencao: "Manutenção",
  calibracao: "Calibração",
  configuracao: "Configuração",
  visita: "Visita técnica",
};

function clip(value: string, max = 240) {
  const trimmed = value.trim();
  return trimmed.length > max ? trimmed.slice(0, max) : trimmed;
}

export type CreateOsState = {
  error?: string;
};

export async function createCampoOs(
  _prev: CreateOsState,
  formData: FormData,
): Promise<CreateOsState> {
  const profile = await getProfile();
  if (!profile) {
    return { error: "Sessão expirada. Entre de novo." };
  }

  const intent = String(formData.get("intent") || "draft");
  const number = String(formData.get("number") || "").trim();
  const cnpj = String(formData.get("cnpj") || "").trim();
  const client = String(formData.get("client") || "").trim();
  const site = String(formData.get("site") || "").trim();
  const systemType = String(formData.get("systemType") || "").trim();
  const serviceKind = String(formData.get("serviceKind") || "").trim();
  const serviceOther = String(formData.get("serviceOther") || "").trim();
  const service =
    serviceKind === "outro"
      ? serviceOther
      : SERVICE_PRESETS[serviceKind] || serviceOther || serviceKind;
  const startsAtRaw = String(formData.get("startsAt") || "").trim();
  const baseName = String(formData.get("baseName") || "").trim();
  const baseCargo = String(formData.get("baseCargo") || "").trim();
  const baseEmail = String(formData.get("baseEmail") || "").trim();
  const basePhone = String(formData.get("basePhone") || "").trim();
  const technicianCargo = String(
    formData.get("technicianCargo") || "Técnico em Instrumentação Industrial",
  ).trim();

  const techEmails = formData
    .getAll("techEmail")
    .map(String)
    .map((v) => v.trim().toLowerCase())
    .filter(Boolean);
  const techNames = formData
    .getAll("techName")
    .map(String)
    .map((v) => v.trim())
    .filter(Boolean);

  if (!number) return { error: "Informe o número da OS." };
  if (!cnpj) return { error: "Informe o CNPJ do cliente." };
  if (!client) return { error: "Informe o contratante." };
  if (!service.trim()) {
    return { error: "Escolha o tipo de serviço ou descreva o serviço contratado." };
  }
  if (techEmails.length === 0) {
    return { error: "Escolha pelo menos um técnico." };
  }

  const now = new Date();
  const id = String(now.getTime());
  const startsAt = startsAtRaw
    ? new Date(`${startsAtRaw}T12:00:00`).toISOString()
    : now.toISOString();
  const status = intent === "dispatch" ? "comTecnico" : "rascunho";
  const ownerEmail =
    profile.email ||
    (profile.login ? `${profile.login}@gssolucoestec.com.br` : "");

  const funcoes: Record<string, string> = {};
  const cargos: Record<string, string> = {};
  for (const email of techEmails) {
    const funcao = String(formData.get(`funcao_${email}`) || "").trim();
    const cargo = String(formData.get(`cargo_${email}`) || "").trim();
    if (funcao) funcoes[email] = funcao;
    if (cargo) cargos[email] = cargo;
  }

  const result = await saveCampoOrder({
    id,
    number,
    status,
    updatedAt: now.toISOString(),
    ownerEmail,
    createdAt: now.toISOString(),
    startsAt,
    technicianEmail: techEmails[0] || "",
    technicianName: techNames.join(", "),
    technicianEmails: techEmails.join(","),
    signerName: baseName,
    client: clip(client),
    site: clip(site),
    cnpj,
    systemType: clip(systemType),
    service: clip(service),
    technicianCargo,
    baseName: clip(baseName),
    baseCargo: clip(baseCargo),
    baseEmail,
    basePhone,
    technicianFuncoes: JSON.stringify(funcoes),
    technicianCargos: JSON.stringify(cargos),
    filesJson: "[]",
  });

  if (!result.ok) {
    return { error: result.error || "Não foi possível salvar a OS." };
  }

  redirect(`/os/${id}`);
}
