import type { Role } from "@gs/shared";
import type { CampoGateUser, CampoSessionUser } from "./types";

/** Converte papel da planilha GS Campo → Role do escritório. */
export function mapCampoRole(raw: string): Role {
  const value = raw.trim().toLowerCase();
  if (
    value === "admin" ||
    value === "adm" ||
    value === "administrativo" ||
    value === "ambos" ||
    value === "tecnico e administrativo" ||
    value === "dev" ||
    value === "desenvolvedor"
  ) {
    return "admin";
  }
  if (value === "office" || value === "escritorio" || value === "escritório") {
    return "office";
  }
  return "technician";
}

export function toSessionUser(user: CampoGateUser): CampoSessionUser {
  return {
    email: user.email.trim().toLowerCase(),
    login: user.login.trim().toLowerCase(),
    name: (user.name || user.login || user.email).trim(),
    phone: (user.phone || "").trim(),
    campoRole: (user.role || "tecnico").trim().toLowerCase(),
    role: mapCampoRole(user.role || "tecnico"),
    permissions: (user.permissoes || "geral").trim() || "geral",
    cargo: (user.cargo || "").trim(),
    funcao: (user.funcao || "").trim(),
    status: (user.status || "aprovado").trim().toLowerCase(),
    active: user.active !== false,
  };
}

export function campoRoleLabel(campoRole: string, mapped: Role): string {
  const value = campoRole.trim().toLowerCase();
  if (value === "ambos" || value === "tecnico e administrativo") {
    return "Administrativo e técnico";
  }
  if (value === "dev" || value === "desenvolvedor") return "Desenvolvedor";
  if (value === "admin" || value === "adm" || value === "administrativo") {
    return "Administrador";
  }
  if (mapped === "office") return "Escritório";
  if (mapped === "technician") return "Técnico";
  return "Acesso GS";
}
