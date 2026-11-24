/** Chave estável na URL da ficha do funcionário. */

export function equipePersonKey(user: { email?: string; login?: string }) {
  const email = String(user.email || "")
    .trim()
    .toLowerCase();
  if (email) return email;
  return String(user.login || "")
    .trim()
    .toLowerCase();
}

export function encodeEquipePersonKey(key: string) {
  return encodeURIComponent(String(key || "").trim().toLowerCase());
}

export function decodeEquipePersonKey(raw: string) {
  try {
    return decodeURIComponent(String(raw || "").trim()).toLowerCase();
  } catch {
    return String(raw || "")
      .trim()
      .toLowerCase();
  }
}

export function matchesEquipePerson(
  user: { email?: string; login?: string },
  key: string,
) {
  const k = key.trim().toLowerCase();
  if (!k) return false;
  const email = String(user.email || "")
    .trim()
    .toLowerCase();
  const login = String(user.login || "")
    .trim()
    .toLowerCase();
  return email === k || login === k;
}
