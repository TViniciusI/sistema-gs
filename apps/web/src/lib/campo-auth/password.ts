import { createHash } from "node:crypto";

/** Mesmo algoritmo do GS Campo (Flutter AccountApi.passwordHash). */
export function passwordHash(login: string, password: string): string {
  const id = login.trim().toLowerCase();
  return createHash("sha256")
    .update(`gs-campo|${id}|${password}`, "utf8")
    .digest("hex");
}

const PRINCIPAL_LOGINS = new Set([
  "gssolucoes",
  "gs",
  "administrativo",
  "gs soluções",
  "gs solucoes",
]);

const CLEBER_COMPACT = /^cleberguimar/;

function isPrincipalIdentity(login: string, email: string): boolean {
  const mail = email.trim().toLowerCase();
  const user = login.trim().toLowerCase();
  if (mail === "administrativo@gssolucoestec.com.br") return true;
  return PRINCIPAL_LOGINS.has(user);
}

function isCleberIdentity(login: string, email: string): boolean {
  const mail = email.trim().toLowerCase();
  const user = login.trim().toLowerCase();
  if (mail === "cleber@gssolucoestec.com.br") return true;
  if (user === "cleber") return true;
  const compact = user.replace(/[\s._-]+/g, "");
  if (compact === "cleber" || CLEBER_COMPACT.test(compact)) return true;
  if (
    user.startsWith("cleber ") ||
    user.startsWith("cleber_") ||
    user.startsWith("cleber-") ||
    user.startsWith("cleber.")
  ) {
    return true;
  }
  return mail.split("@")[0] === "cleber";
}

/** Gera candidatos de hash como o app (aliases Cleber / administrativo / etc.). */
export function passwordHashCandidates(input: {
  password: string;
  login: string;
  email?: string;
}): string[] {
  const login = input.login.trim().toLowerCase();
  const email = (input.email ?? "").trim().toLowerCase();
  const ids = new Set<string>([login, email]);
  if (email.includes("@")) {
    ids.add(email.split("@")[0] ?? "");
  }
  if (isPrincipalIdentity(login, email)) {
    for (const id of ["gssolucoes", "gs", "administrativo"]) ids.add(id);
  }
  if (isCleberIdentity(login, email)) {
    for (const id of [
      "cleber",
      "cleber guimarães",
      "cleber guimaraes",
      "cleberguimaraes",
    ]) {
      ids.add(id);
    }
  }
  if (login === "vinicius" || email === "viniciusmagalhaes2y@gmail.com") {
    ids.add("vinicius");
  }
  ids.delete("");
  return [...ids].map((id) => passwordHash(id, input.password));
}
