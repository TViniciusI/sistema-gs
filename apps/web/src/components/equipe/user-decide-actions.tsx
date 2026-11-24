"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { decideEquipeUser } from "@/app/(app)/equipe/actions";

export function UserDecideActions({
  email,
  login,
  status,
}: {
  email: string;
  login: string;
  status: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const key = status.trim().toLowerCase();
  if (key !== "pendente") return null;

  function run(next: "aprovado" | "recusado") {
    setError(null);
    startTransition(async () => {
      const result = await decideEquipeUser({
        email,
        login,
        status: next,
        role: next === "aprovado" ? "tecnico" : undefined,
      });
      if (!result.ok) {
        setError(result.error || "Falha ao atualizar.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex flex-wrap justify-end gap-1.5">
        <button
          type="button"
          disabled={pending}
          onClick={() => run("aprovado")}
          className="rounded-lg bg-navy px-2.5 py-1.5 text-[11px] font-semibold text-paper hover:bg-navy-2 disabled:opacity-60"
        >
          Aprovar
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run("recusado")}
          className="rounded-lg border border-navy/15 bg-paper px-2.5 py-1.5 text-[11px] font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
        >
          Recusar
        </button>
      </div>
      {error ? <p className="text-[11px] text-red-700">{error}</p> : null}
    </div>
  );
}
