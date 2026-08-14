import { digitsOnly } from "@gs/shared";

export type CnpjLookupResult = {
  cnpj: string;
  razaoSocial: string;
  nomeFantasia: string;
  endereco: string;
  cidade: string;
  estado: string;
  telefone: string;
  email: string;
  source: "local" | "brasilapi";
  clientId?: string;
};

export type LocalCnpjRecord = {
  cnpj: string;
  razaoSocial: string;
  nomeFantasia: string;
  endereco?: string;
  cidade?: string;
  estado?: string;
  telefone?: string;
  email?: string;
  clientId?: string;
};

type BrasilApiCnpjResponse = {
  cnpj: string;
  razao_social: string;
  nome_fantasia?: string | null;
  logradouro?: string | null;
  numero?: string | null;
  complemento?: string | null;
  bairro?: string | null;
  municipio?: string | null;
  uf?: string | null;
  cep?: string | null;
  ddd_telefone_1?: string | null;
  ddd_telefone_2?: string | null;
  email?: string | null;
};

function buildEndereco(data: BrasilApiCnpjResponse): string {
  const cep = data.cep?.replace(/\D/g, "") ?? "";
  const cepFmt =
    cep.length === 8 ? `CEP ${cep.slice(0, 5)}-${cep.slice(5)}` : null;
  return [
    data.logradouro,
    data.numero ? `nº ${data.numero}` : null,
    data.complemento,
    data.bairro,
    cepFmt,
  ]
    .filter(Boolean)
    .join(", ");
}

function formatApiPhone(phone?: string | null): string {
  if (!phone) return "";
  const digits = digitsOnly(phone);
  if (digits.length === 10) {
    return digits.replace(/(\d{2})(\d{4})(\d{4})/, "($1) $2-$3");
  }
  if (digits.length === 11) {
    return digits.replace(/(\d{2})(\d{5})(\d{4})/, "($1) $2-$3");
  }
  return phone;
}

async function fetchFromBrasilApi(cnpjDigits: string): Promise<CnpjLookupResult> {
  const response = await fetch(
    `https://brasilapi.com.br/api/cnpj/v1/${cnpjDigits}`,
  );

  if (response.status === 404) {
    throw new Error("CNPJ não encontrado na Receita Federal.");
  }

  if (!response.ok) {
    throw new Error(
      "Não foi possível consultar o CNPJ. Tente novamente em instantes.",
    );
  }

  const data: BrasilApiCnpjResponse = await response.json();

  return {
    cnpj: cnpjDigits,
    razaoSocial: data.razao_social ?? "",
    nomeFantasia: data.nome_fantasia || data.razao_social || "",
    endereco: buildEndereco(data),
    cidade: data.municipio ?? "",
    estado: data.uf ?? "",
    telefone:
      formatApiPhone(data.ddd_telefone_1) || formatApiPhone(data.ddd_telefone_2),
    email: data.email ?? "",
    source: "brasilapi",
  };
}

export async function lookupCnpj(
  cnpj: string,
  localRecords: LocalCnpjRecord[] = [],
): Promise<CnpjLookupResult> {
  const digits = digitsOnly(cnpj);
  if (digits.length !== 14) {
    throw new Error("Informe um CNPJ válido com 14 dígitos.");
  }

  const local = localRecords.find(
    (item) => digitsOnly(item.cnpj) === digits,
  );
  if (local) {
    return {
      cnpj: digits,
      razaoSocial: local.razaoSocial,
      nomeFantasia: local.nomeFantasia,
      endereco: local.endereco ?? "",
      cidade: local.cidade ?? "",
      estado: local.estado ?? "",
      telefone: local.telefone ?? "",
      email: local.email ?? "",
      source: "local",
      clientId: local.clientId,
    };
  }

  return fetchFromBrasilApi(digits);
}
