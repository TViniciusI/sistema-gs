const DEFAULT_GATE_URL =
  "https://script.google.com/macros/s/AKfycbzo6F1Ety_rS3asCvynmFsqSNXzuywc8zpKxqXpi2iOT16ddEGD_GSva1nEfoI82KVTRQ/exec";

const DEFAULT_GATE_TOKEN = "gs-dev-gate-v1";

export function loginGateUrl(): string {
  return (
    process.env.LOGIN_GATE_URL?.trim() ||
    process.env.NEXT_PUBLIC_LOGIN_GATE_URL?.trim() ||
    DEFAULT_GATE_URL
  );
}

export function loginGateToken(): string {
  return (
    process.env.LOGIN_GATE_TOKEN?.trim() ||
    process.env.NEXT_PUBLIC_LOGIN_GATE_TOKEN?.trim() ||
    DEFAULT_GATE_TOKEN
  );
}

export function sessionSecret(): string {
  return (
    process.env.CAMPO_SESSION_SECRET?.trim() ||
    process.env.LOGIN_GATE_TOKEN?.trim() ||
    DEFAULT_GATE_TOKEN
  );
}

/** Build enviado ao script (só informativo no login). */
export function appBuild(): string {
  return process.env.CAMPO_APP_BUILD?.trim() || "289";
}
