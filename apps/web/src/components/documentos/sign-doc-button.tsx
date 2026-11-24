"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
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
  if (disabled) return null;

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        if (!window.confirm("Marcar este documento como assinado?")) return;
        startTransition(async () => {
          await signDocumentoAction(id);
          router.refresh();
        });
      }}
      className="rounded-lg border border-navy/15 px-2 py-1 text-[11px] font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
    >
      {pending ? "…" : "Assinar"}
    </button>
  );
}
