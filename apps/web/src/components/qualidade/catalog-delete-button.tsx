"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export function CatalogDeleteButton({
  id,
  label,
  onDelete,
}: {
  id: string;
  label: string;
  onDelete: (id: string) => Promise<{ ok: boolean; error?: string }>;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        if (!window.confirm(`Apagar ${label}?`)) return;
        startTransition(async () => {
          await onDelete(id);
          router.refresh();
        });
      }}
      className="text-xs font-medium text-red-700 hover:underline disabled:opacity-60"
    >
      Apagar
    </button>
  );
}
