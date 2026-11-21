import type { Role } from "@gs/shared";

/** Usuário público devolvido pelo login_gate.gs (action=login). */
export type CampoGateUser = {
  email: string;
  name: string;
  login: string;
  phone: string;
  role: string;
  status: string;
  active: boolean;
  funcao?: string;
  cargo?: string;
  calibracao?: string;
  permissoes?: string;
  jornada?: string;
};

export type CampoSessionUser = {
  email: string;
  login: string;
  name: string;
  phone: string;
  /** Papel bruto da planilha: admin | tecnico | ambos | dev */
  campoRole: string;
  /** Papel mapeado para o shell do escritório */
  role: Role;
  permissions: string;
  cargo: string;
  funcao: string;
  status: string;
  active: boolean;
};

export type CampoLoginResult =
  | { ok: true; user: CampoGateUser }
  | {
      ok: false;
      error: string;
      pending?: boolean;
      wrongPassword?: boolean;
      unreachable?: boolean;
    };
