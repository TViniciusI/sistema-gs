"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { updateCampoOsStatus } from "@/app/(app)/os/actions";

type Props = {
  osId: string;
  osNumber: string;
  status: string;
  hasRdos: boolean;
  hasTechnicians: boolean;
  /** Toolbar sem card próprio — para embutir no resumo da OS. */
  compact?: boolean;
};

function normalizeStatus(status: string) {
  return status.trim().toLowerCase().replace(/\s+/g, "");
}

export function OsStatusActions({
  osId,
  osNumber,
  status,
  hasRdos,
  hasTechnicians,
  compact = false,
}: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const key = normalizeStatus(status);

  const canDispatch = key === "rascunho" && hasTechnicians;
  const canMarkServiceDone =
    (key === "comtecnico" || key === "emandamento") && hasRdos;
  const canClose =
    key === "servicoencerrado" ||
    key === "emandamento" ||
    key === "comtecnico";
  const canReopen = key === "encerrada" || key === "servicoencerrado";

  function run(
    intent: "dispatch" | "serviceDone" | "close" | "reopen",
    confirmMsg?: string,
  ) {
    if (confirmMsg && !window.confirm(confirmMsg)) return;
    setError(null);
    startTransition(async () => {
      const result = await updateCampoOsStatus({
        osId,
        intent,
      });
      if (!result.ok) {
        setError(result.error || "Falha ao atualizar a OS.");
        return;
      }
      router.refresh();
    });
  }

  if (!canDispatch && !canMarkServiceDone && !canClose && !canReopen) {
    return null;
  }

  const buttons = (
    <div className="flex flex-wrap gap-2">
      {canDispatch ? (
        <button
          type="button"
          disabled={pending}
          onClick={() => run("dispatch")}
          className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2 disabled:opacity-60"
        >
          Enviar ao técnico
        </button>
      ) : null}
      {canMarkServiceDone ? (
        <button
          type="button"
          disabled={pending}
          onClick={() =>
            run(
              "serviceDone",
              "Marcar serviço como encerrado? O técnico deixa de editar o campo.",
            )
          }
          className="rounded-xl border border-navy/15 bg-paper px-4 py-2.5 text-sm font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
        >
          Encerrar serviço
        </button>
      ) : null}
      {canClose ? (
        <button
          type="button"
          disabled={pending}
          onClick={() =>
            run(
              "close",
              `Encerrar de verdade a OS GS ${osNumber}? Ela sai da fila aberta.`,
            )
          }
          className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          Encerrar OS
        </button>
      ) : null}
      {canReopen ? (
        <button
          type="button"
          disabled={pending}
          onClick={() => run("reopen")}
          className="rounded-xl border border-navy/15 bg-paper px-4 py-2.5 text-sm font-semibold text-navy hover:border-brass/40 disabled:opacity-60"
        >
          Reativar OS
        </button>
      ) : null}
    </div>
  );

  if (compact) {
    return (
      <div className="space-y-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/40">
          Ciclo
        </p>
        {buttons}
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
        {pending ? (
          <p className="text-xs text-navy/45">Salvando na planilha…</p>
        ) : null}
      </div>
    );
  }

  return (
    <div className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
        Ciclo da OS
      </p>
      <h2 className="mt-1 font-serif text-xl text-navy">
        GS {osNumber} · escritório
      </h2>
      <p className="mt-2 text-sm leading-6 text-navy/60">
        Mesmas ações do hub do GS Campo: enviar ao técnico, encerrar serviço /
        OS ou reativar.
      </p>
      <div className="mt-4">{buttons}</div>
      {error ? <p className="mt-3 text-sm text-red-700">{error}</p> : null}
      {pending ? (
        <p className="mt-2 text-xs text-navy/45">Salvando na planilha…</p>
      ) : null}
    </div>
  );
}
