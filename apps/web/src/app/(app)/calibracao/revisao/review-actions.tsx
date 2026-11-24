"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { decideCatalogSlot } from "./actions";

export function CatalogReviewActions({
  osId,
  slotId,
}: {
  osId: string;
  slotId: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function run(status: "approved" | "rejected") {
    setError(null);
    startTransition(async () => {
      const result = await decideCatalogSlot({ osId, slotId, status });
      if (!result.ok) {
        setError(result.error || "Falha.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex gap-1.5">
        <button
          type="button"
          disabled={pending}
          onClick={() => run("approved")}
          className="rounded-lg bg-navy px-2 py-1 text-[11px] font-semibold text-paper disabled:opacity-60"
        >
          Aprovar
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run("rejected")}
          className="rounded-lg border border-navy/15 px-2 py-1 text-[11px] font-semibold text-navy disabled:opacity-60"
        >
          Recusar
        </button>
      </div>
      {error ? <p className="text-[11px] text-red-700">{error}</p> : null}
    </div>
  );
}
