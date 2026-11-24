"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { signDocumentoAction } from "@/app/(app)/documentos/actions";

export function SignDocButton({
  id,
  disabled,
}: {
  id: string;
  disabled?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  if (disabled) return null;

  return (
    <span className="inline-flex flex-col gap-1">
      <button
        type="button"
        disabled={pending}
        onClick={() => {
          if (!window.confirm("Marcar este documento como assinado?")) return;
          setError(null);
          startTransition(async () => {
            const result = await signDocumentoAction(id);
            if (!result.ok) {
              setError(result.error || "Falha ao assinar.");
              return;
            }
            router.refresh();
          });
        }}
        className="rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
      >
        {pending ? "Assinando…" : "Assinar"}
      </button>
      {error ? <span className="text-xs text-red-700">{error}</span> : null}
    </span>
  );
}
