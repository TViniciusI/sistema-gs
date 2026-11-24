import { revalidateTag, unstable_cache, updateTag } from "next/cache";
import { cache } from "react";

/** Tags compartilhadas — mutate com `bumpCampoCache`. */
export const CAMPO_TAGS = {
  orders: "campo-orders",
  clients: "campo-clients",
  calibrations: "campo-calibrations",
  standards: "campo-standards",
  fluids: "campo-fluids",
  users: "campo-users",
  drive: "campo-drive",
  osDrive: "campo-os-drive",
  staffDocs: "campo-staff-docs",
} as const;

export type CampoCacheTag = (typeof CAMPO_TAGS)[keyof typeof CAMPO_TAGS];

/** TTL: navegar entre telas reaproveita; save invalida na hora. */
export const CAMPO_LIST_REVALIDATE_SECONDS = 90;

export function bumpCampoCache(...tags: CampoCacheTag[]) {
  for (const tag of tags) {
    try {
      // Preferido em Server Actions (read-your-own-writes).
      updateTag(tag);
    } catch {
      revalidateTag(tag, "max");
    }
  }
}

/**
 * Cache cross-request (Data Cache) + dedupe por request (React.cache).
 * `key` deve ser estável e único por função.
 */
export function cachedList<T>(
  key: string,
  tags: CampoCacheTag[],
  loader: () => Promise<T>,
  revalidateSeconds = CAMPO_LIST_REVALIDATE_SECONDS,
): () => Promise<T> {
  const cached = unstable_cache(loader, [key], {
    revalidate: revalidateSeconds,
    tags,
  });
  return cache(() => cached());
}
