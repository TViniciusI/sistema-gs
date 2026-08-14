import { cookies } from "next/headers";
import { DEMO_COOKIE } from "./constants";
import { DEMO_PROFILE } from "./seed";

export async function isDemoAuthenticated() {
  const store = await cookies();
  return store.get(DEMO_COOKIE)?.value === "1";
}

export function getDemoProfile() {
  return DEMO_PROFILE;
}
