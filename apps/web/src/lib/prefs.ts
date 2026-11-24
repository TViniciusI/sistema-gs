import { cookies } from "next/headers";

/** Preferência local do escritório — espelha “saudação com nome completo” do app. */
export const GREET_FULL_NAME_COOKIE = "gs_greet_full_name";

export async function getGreetWithFullName(): Promise<boolean> {
  const jar = await cookies();
  const raw = jar.get(GREET_FULL_NAME_COOKIE)?.value;
  if (raw === "1" || raw === "true") return true;
  if (raw === "0" || raw === "false") return false;
  return false;
}
